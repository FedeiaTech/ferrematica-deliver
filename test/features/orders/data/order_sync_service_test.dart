import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ferrematica_express/features/orders/data/order_sync_service.dart';
import 'package:ferrematica_express/features/orders/data/supabase_orders_remote.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/domain/orders_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/test_isar.dart';

class MockOrdersRepository extends Mock implements OrdersRepository {}

class MockOrdersRemote extends Mock implements OrdersRemote {}

Order _order({
  String id = 'order-1',
  DateTime? updatedAt,
  SyncStatus syncStatus = SyncStatus.pending,
}) {
  final at = updatedAt ?? DateTime(2026, 1, 1, 12);
  return Order(
    id: id,
    deliveryAddress: 'Calle Falsa 123',
    createdBy: 'owner-1',
    createdAt: at,
    updatedAt: at,
    syncStatus: syncStatus,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_order());
  });

  late Isar isar;
  late MockOrdersRepository repository;
  late MockOrdersRemote remote;
  late StreamController<List<ConnectivityResult>> connectivityController;
  late OrderSyncService service;

  setUp(() async {
    isar = await openTestIsar();
    repository = MockOrdersRepository();
    remote = MockOrdersRemote();
    connectivityController = StreamController<List<ConnectivityResult>>.broadcast();

    when(() => repository.pendingSync()).thenAnswer((_) async => <Order>[]);
    when(() => repository.markSynced(any())).thenAnswer((_) async {});
    when(() => repository.markFailed(any(), any())).thenAnswer((_) async {});
    when(() => repository.save(any())).thenAnswer((_) async {});
    when(() => repository.getById(any())).thenAnswer((_) async => null);
    when(() => remote.fetchSince(any())).thenAnswer((_) async => <Order>[]);

    service = OrderSyncService(
      repository: repository,
      remote: remote,
      isar: isar,
      connectivityStream: connectivityController.stream,
    );
  });

  tearDown(() async {
    service.dispose();
    await connectivityController.close();
    await closeTestIsar(isar);
  });

  group('push', () {
    test('marks synced when the server echoes back the same updatedAt', () async {
      final order = _order();
      when(() => repository.pendingSync()).thenAnswer((_) async => <Order>[order]);
      when(() => remote.upsert(order)).thenAnswer((_) async => order);

      await service.drain();

      verify(() => repository.markSynced('order-1')).called(1);
      verifyNever(() => repository.markFailed(any(), any()));
    });

    test('marks failed when the remote call throws', () async {
      final order = _order();
      when(() => repository.pendingSync()).thenAnswer((_) async => <Order>[order]);
      when(() => remote.upsert(order)).thenThrow(Exception('network down'));

      await service.drain();

      verify(
        () => repository.markFailed('order-1', any(that: contains('network down'))),
      ).called(1);
    });

    test('stale-rejected push where remote genuinely moved ahead overwrites local', () async {
      final attempted = _order(updatedAt: DateTime(2026, 1, 1, 12));
      final remoteRow = _order(updatedAt: DateTime(2026, 1, 1, 13));
      final currentLocal = _order(
        updatedAt: DateTime(2026, 1, 1, 12),
        syncStatus: SyncStatus.pending,
      );

      when(() => repository.pendingSync()).thenAnswer((_) async => <Order>[attempted]);
      when(() => remote.upsert(attempted)).thenAnswer((_) async => remoteRow);
      when(() => repository.getById('order-1')).thenAnswer((_) async => currentLocal);

      await service.drain();

      final captured = verify(() => repository.save(captureAny())).captured;
      final saved = captured.single as Order;
      expect(saved.syncStatus, SyncStatus.synced);
      expect(saved.updatedAt, remoteRow.updatedAt);
    });

    test('stale-rejected push where a newer local edit landed keeps it pending', () async {
      final attempted = _order(updatedAt: DateTime(2026, 1, 1, 12));
      final remoteRow = _order(updatedAt: DateTime(2026, 1, 1, 12, 30));
      final newerLocal = _order(
        updatedAt: DateTime(2026, 1, 1, 13),
        syncStatus: SyncStatus.pending,
      );

      when(() => repository.pendingSync()).thenAnswer((_) async => <Order>[attempted]);
      when(() => remote.upsert(attempted)).thenAnswer((_) async => remoteRow);
      when(() => repository.getById('order-1')).thenAnswer((_) async => newerLocal);

      await service.drain();

      verifyNever(() => repository.save(any()));
      verify(() => repository.markFailed('order-1', any())).called(1);
    });
  });

  group('pull', () {
    test('applies a remote row not present locally', () async {
      final remoteOrder = _order(syncStatus: SyncStatus.synced);
      when(() => remote.fetchSince(any())).thenAnswer((_) async => <Order>[remoteOrder]);
      when(() => repository.getById('order-1')).thenAnswer((_) async => null);

      await service.drain();

      final captured = verify(() => repository.save(captureAny())).captured;
      expect((captured.single as Order).syncStatus, SyncStatus.synced);
    });

    test('never overwrites a local order that is still pending', () async {
      final remoteOrder = _order(updatedAt: DateTime(2026, 1, 2));
      final localPending = _order(updatedAt: DateTime(2026, 1, 1), syncStatus: SyncStatus.pending);
      when(() => remote.fetchSince(any())).thenAnswer((_) async => <Order>[remoteOrder]);
      when(() => repository.getById('order-1')).thenAnswer((_) async => localPending);

      await service.drain();

      verifyNever(() => repository.save(any()));
    });

    test('skips a remote row older than the local copy', () async {
      final remoteOrder = _order(updatedAt: DateTime(2026, 1, 1));
      final localNewer = _order(updatedAt: DateTime(2026, 1, 2), syncStatus: SyncStatus.synced);
      when(() => remote.fetchSince(any())).thenAnswer((_) async => <Order>[remoteOrder]);
      when(() => repository.getById('order-1')).thenAnswer((_) async => localNewer);

      await service.drain();

      verifyNever(() => repository.save(any()));
    });
  });

  group('connectivity trigger', () {
    test('reconnect pushes each pending order exactly once, no duplication', () async {
      final order = _order();
      var pendingCallCount = 0;
      when(() => repository.pendingSync()).thenAnswer((_) async {
        pendingCallCount++;
        return pendingCallCount == 1 ? <Order>[order] : <Order>[];
      });
      when(() => remote.upsert(order)).thenAnswer((_) async => order);

      service.start();
      connectivityController.add(<ConnectivityResult>[ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() => remote.upsert(order)).called(1);
    });

    test('a "none" connectivity event does not trigger a drain', () async {
      service.start();
      connectivityController.add(<ConnectivityResult>[ConnectivityResult.none]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verifyNever(() => repository.pendingSync());
    });
  });
}
