import 'package:ferrematica_express/features/orders/data/isar_orders_repository.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../../../helpers/test_isar.dart';

Order _buildOrder({
  String id = 'order-1',
  String deliveryAddress = 'Calle Falsa 123',
  OrderStatus status = OrderStatus.pendiente,
  SyncStatus syncStatus = SyncStatus.pending,
  DateTime? updatedAt,
}) {
  final at = updatedAt ?? DateTime(2026, 1, 1);
  return Order(
    id: id,
    deliveryAddress: deliveryAddress,
    createdBy: 'owner-1',
    createdAt: at,
    updatedAt: at,
    status: status,
    syncStatus: syncStatus,
  );
}

void main() {
  late Isar isar;
  late IsarOrdersRepository repository;

  setUp(() async {
    isar = await openTestIsar();
    repository = IsarOrdersRepository(isar);
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  group('save + getById', () {
    test('persists and retrieves an order', () async {
      await repository.save(_buildOrder());

      final found = await repository.getById('order-1');

      expect(found, isNotNull);
      expect(found!.deliveryAddress, 'Calle Falsa 123');
    });

    test('returns null for an unknown id', () async {
      final found = await repository.getById('missing');

      expect(found, isNull);
    });

    test('re-put with the same id updates in place, not a duplicate', () async {
      await repository.save(_buildOrder());
      await repository.save(_buildOrder(deliveryAddress: 'Nueva Dirección 456'));

      final found = await repository.getById('order-1');
      expect(found!.deliveryAddress, 'Nueva Dirección 456');

      final pending = await repository.pendingSync();
      expect(pending.where((order) => order.id == 'order-1'), hasLength(1));
    });
  });

  group('softDelete', () {
    test('excludes the order from getById after soft-delete', () async {
      await repository.save(_buildOrder());

      await repository.softDelete('order-1');

      expect(await repository.getById('order-1'), isNull);
    });

    test('marks the order pending again so the deletion itself can sync', () async {
      await repository.save(_buildOrder(syncStatus: SyncStatus.synced));

      await repository.softDelete('order-1');

      final pending = await repository.pendingSync();
      expect(pending.map((order) => order.id), contains('order-1'));
    });
  });

  group('watchOrders', () {
    test('emits the current list immediately and again after a write', () async {
      final events = <List<Order>>[];
      final subscription = repository.watchOrders().listen(events.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);

      await repository.save(_buildOrder());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, isNotEmpty);
      expect(events.last.map((order) => order.id), contains('order-1'));
    });

    test('filters by status', () async {
      await repository.save(_buildOrder(id: 'a', status: OrderStatus.pendiente));
      await repository.save(_buildOrder(id: 'b', status: OrderStatus.entregado));

      final filtered = await repository.watchOrders(status: OrderStatus.entregado).first;

      expect(filtered.map((order) => order.id), equals(<String>['b']));
    });

    test('excludes soft-deleted orders', () async {
      await repository.save(_buildOrder());
      await repository.softDelete('order-1');

      final visible = await repository.watchOrders().first;

      expect(visible, isEmpty);
    });
  });

  group('pendingSync', () {
    test('returns only orders with syncStatus == pending', () async {
      await repository.save(_buildOrder(id: 'a', syncStatus: SyncStatus.pending));
      await repository.save(_buildOrder(id: 'b', syncStatus: SyncStatus.synced));

      final pending = await repository.pendingSync();

      expect(pending.map((order) => order.id), equals(<String>['a']));
    });
  });

  group('markSynced / markFailed', () {
    test('markSynced sets syncStatus to synced without bumping updatedAt', () async {
      final original = _buildOrder();
      await repository.save(original);

      await repository.markSynced('order-1');

      final found = await repository.getById('order-1');
      expect(found!.syncStatus, SyncStatus.synced);
      expect(found.updatedAt, original.updatedAt);
    });

    test('markFailed sets syncStatus to failed without bumping updatedAt', () async {
      final original = _buildOrder();
      await repository.save(original);

      await repository.markFailed('order-1', 'network error');

      final found = await repository.getById('order-1');
      expect(found!.syncStatus, SyncStatus.failed);
      expect(found.updatedAt, original.updatedAt);
    });
  });
}
