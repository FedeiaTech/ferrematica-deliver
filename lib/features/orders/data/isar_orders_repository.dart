import 'package:isar_community/isar.dart';

import '../domain/order.dart';
import '../domain/orders_repository.dart';
import 'order_model.dart';

/// [OrdersRepository] backed by the local Isar instance — the single source
/// of truth the UI reads (see design decision "Isar is the source of truth;
/// Supabase is a replication target"). Every write commits locally first;
/// nothing here talks to the network.
class IsarOrdersRepository implements OrdersRepository {
  IsarOrdersRepository(this._isar, {this.onWrite});

  final Isar _isar;

  /// Called after [save] or [softDelete] commits, so a sync service can
  /// fire a post-write drain attempt (design's "post-write" trigger).
  /// Intentionally NOT called from [markSynced]/[markFailed] — those are
  /// internal sync bookkeeping, not user mutations, and calling it there
  /// would recursively re-trigger a drain that is already in flight.
  void Function()? onWrite;

  @override
  Stream<List<Order>> watchOrders({OrderStatus? status}) {
    final query = status == null
        ? _isar.orderModels.filter().deletedAtIsNull().sortByUpdatedAtDesc()
        : _isar.orderModels
            .filter()
            .deletedAtIsNull()
            .and()
            .statusEqualTo(status)
            .sortByUpdatedAtDesc();

    return query
        .watch(fireImmediately: true)
        .map((models) => models.map(orderModelToDomain).toList(growable: false));
  }

  @override
  Future<Order?> getById(String id) async {
    final model = await _isar.orderModels
        .filter()
        .idEqualTo(id)
        .deletedAtIsNull()
        .findFirst();
    return model == null ? null : orderModelToDomain(model);
  }

  @override
  Future<void> save(Order order) async {
    await _isar.writeTxn(() async {
      await _isar.orderModels.put(orderToModel(order));
    });
    onWrite?.call();
  }

  @override
  Future<void> softDelete(String id) async {
    await _isar.writeTxn(() async {
      final model = await _isar.orderModels.filter().idEqualTo(id).findFirst();
      if (model == null) return;
      final deleted = orderModelToDomain(model).copyWith(
        deletedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      );
      await _isar.orderModels.put(orderToModel(deleted));
    });
    onWrite?.call();
  }

  @override
  Future<List<Order>> pendingSync() async {
    final models = await _isar.orderModels
        .filter()
        .syncStatusEqualTo(SyncStatus.pending)
        .findAll();
    return models.map(orderModelToDomain).toList(growable: false);
  }

  @override
  Future<void> markSynced(String id) async {
    await _setSyncStatus(id, SyncStatus.synced);
  }

  @override
  Future<void> markFailed(String id, String error) async {
    await _setSyncStatus(id, SyncStatus.failed);
  }

  /// Updates only `syncStatus`, preserving the row's `updatedAt` — this is
  /// sync bookkeeping, not a domain mutation, and must not perturb the
  /// timestamp LWW comparisons rely on.
  Future<void> _setSyncStatus(String id, SyncStatus syncStatus) async {
    await _isar.writeTxn(() async {
      final model = await _isar.orderModels.filter().idEqualTo(id).findFirst();
      if (model == null) return;
      final domain = orderModelToDomain(model);
      final updated = domain.copyWith(
        syncStatus: syncStatus,
        updatedAt: domain.updatedAt,
      );
      await _isar.orderModels.put(orderToModel(updated));
    });
  }
}
