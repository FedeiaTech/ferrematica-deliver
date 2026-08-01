import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:isar_community/isar.dart';

import '../domain/order.dart';
import '../domain/orders_repository.dart';
import 'supabase_orders_remote.dart';
import 'sync_cursor.dart';

/// Drives the push/pull sync loop between the local [OrdersRepository]
/// (Isar) and [OrdersRemote] (Supabase), per design's "connectivity-
/// triggered + lifecycle-triggered drain, no background worker" decision.
///
/// - **Push**: every order with `syncStatus == pending` is upserted. The
///   server-side `orders_reject_stale_update` trigger enforces last-write-
///   wins — if our write was rejected as stale, [_reconcileStalePush]
///   refetches the freshest local copy and either accepts the remote row
///   (it genuinely moved ahead) or leaves ours pending for retry (a newer
///   local edit landed mid-drain).
/// - **Pull**: fetches remote rows updated since the last successful pull
///   (persisted in [SyncCursorModel]) and merges them into Isar, never
///   overwriting a local row that is itself still `pending`.
/// - **Triggers**: connectivity regained, app resumed, and immediately
///   after a local write (via [OrdersRepository]'s optional `onWrite`
///   hook) — all fire-and-forget; the UI never awaits sync.
/// - **Backoff**: a failed push is retried on the next drain only after an
///   in-memory exponential backoff (1s, 2s, 4s, ... capped at 60s) per
///   order id, so a persistently failing row doesn't spam every drain
///   trigger.
class OrderSyncService with WidgetsBindingObserver {
  OrderSyncService({
    required OrdersRepository repository,
    required OrdersRemote remote,
    required Isar isar,
    required Stream<List<ConnectivityResult>> connectivityStream,
  }) : _repository = repository,
       _remote = remote,
       _isar = isar,
       _connectivityStream = connectivityStream;

  static const Duration _maxBackoff = Duration(seconds: 60);

  final OrdersRepository _repository;
  final OrdersRemote _remote;
  final Isar _isar;
  final Stream<List<ConnectivityResult>> _connectivityStream;

  final Map<String, int> _failureCounts = <String, int>{};
  final Map<String, DateTime> _nextRetryAt = <String, DateTime>{};

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _draining = false;
  bool _drainQueued = false;

  /// Starts listening for connectivity-regained and app-resume events.
  /// Call once when the service is created (see `providers.dart`).
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = _connectivityStream.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(drain());
      }
    });
  }

  /// Stops all listeners. Call from a provider's `ref.onDispose`.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connectivitySubscription?.cancel());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(drain());
    }
  }

  /// Triggers a push+pull cycle. Safe to call repeatedly — a call that
  /// arrives while a drain is already in flight is coalesced into a single
  /// follow-up run instead of racing Isar writes.
  Future<void> drain() async {
    if (_draining) {
      _drainQueued = true;
      return;
    }
    _draining = true;
    try {
      await _push();
      await _pull();
    } finally {
      _draining = false;
      if (_drainQueued) {
        _drainQueued = false;
        unawaited(drain());
      }
    }
  }

  Future<void> _push() async {
    final pending = await _repository.pendingSync();
    final now = DateTime.now();

    for (final order in pending) {
      final retryAt = _nextRetryAt[order.id];
      if (retryAt != null && now.isBefore(retryAt)) {
        continue; // still backing off from a previous failure
      }

      try {
        final remoteRow = await _remote.upsert(order);
        if (remoteRow.updatedAt.isAtSameMomentAs(order.updatedAt)) {
          await _repository.markSynced(order.id);
          _failureCounts.remove(order.id);
          _nextRetryAt.remove(order.id);
        } else {
          await _reconcileStalePush(order, remoteRow);
        }
      } catch (error) {
        await _repository.markFailed(order.id, error.toString());
        final attempts = (_failureCounts[order.id] ?? 0) + 1;
        _failureCounts[order.id] = attempts;
        _nextRetryAt[order.id] = now.add(_backoffFor(attempts));
      }
    }
  }

  /// Called when the server's stale-update trigger rejected our push (the
  /// echoed row's `updatedAt` doesn't match what we sent).
  Future<void> _reconcileStalePush(Order attempted, Order remoteRow) async {
    final current = await _repository.getById(attempted.id);
    if (current == null) return;

    if (remoteRow.updatedAt.isAfter(current.updatedAt)) {
      // Remote genuinely moved ahead of us (a concurrent edit landed
      // elsewhere) — remote wins, overwrite local and mark synced.
      await _repository.save(
        remoteRow.copyWith(syncStatus: SyncStatus.synced, updatedAt: remoteRow.updatedAt),
      );
    } else {
      // Our local copy changed again since we read `attempted` (a newer
      // edit landed mid-drain) — leave it pending; the next drain retries
      // with the fresher `updatedAt`, which the trigger will accept.
      await _repository.markFailed(
        attempted.id,
        'stale-update rejected by server; retrying with newer local edit',
      );
    }
  }

  Future<void> _pull() async {
    final cursor = await _isar.syncCursorModels.get(1);
    final since = cursor?.lastPulledAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final remoteOrders = await _remote.fetchSince(since);
    if (remoteOrders.isEmpty) return;

    var latest = since;
    for (final remoteOrder in remoteOrders) {
      final local = await _repository.getById(remoteOrder.id);
      final localIsPending = local?.syncStatus == SyncStatus.pending;

      if (!localIsPending && (local == null || remoteOrder.updatedAt.isAfter(local.updatedAt))) {
        await _repository.save(
          remoteOrder.copyWith(syncStatus: SyncStatus.synced, updatedAt: remoteOrder.updatedAt),
        );
      }

      if (remoteOrder.updatedAt.isAfter(latest)) {
        latest = remoteOrder.updatedAt;
      }
    }

    await _isar.writeTxn(() async {
      await _isar.syncCursorModels.put(SyncCursorModel()..lastPulledAt = latest);
    });
  }

  Duration _backoffFor(int attempts) {
    final seconds = 1 << (attempts.clamp(1, 6) - 1); // 1, 2, 4, 8, 16, 32
    final delay = Duration(seconds: seconds);
    return delay > _maxBackoff ? _maxBackoff : delay;
  }
}
