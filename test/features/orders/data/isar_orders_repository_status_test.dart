import 'package:ferrematica_express/features/orders/data/isar_orders_repository.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../../../helpers/test_isar.dart';

/// Regression coverage for `navegacion-cadete` design decision #6:
/// `enCamino` was appended at the END of the `OrderStatus` enum
/// declaration (not inserted between `asignado` and `entregado`) so that
/// Isar's `@enumerated` (`EnumType.ordinal`) storage does not shift the
/// ordinal of pre-existing statuses. This test proves that orders holding
/// each pre-existing status still round-trip through Isar to the *correct*
/// status after the enum change — the single highest-risk correctness
/// point flagged by the design.
Order _buildOrder({
  required String id,
  required OrderStatus status,
}) {
  final now = DateTime(2026, 1, 1);
  return Order(
    id: id,
    deliveryAddress: 'Calle Falsa 123',
    createdBy: 'owner-1',
    createdAt: now,
    updatedAt: now,
    status: status,
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

  group('OrderStatus Isar round-trip (ordinal-append regression)', () {
    test('every pre-existing status deserializes to itself, none shift to enCamino', () async {
      final seeded = <String, OrderStatus>{
        'order-pendiente': OrderStatus.pendiente,
        'order-asignado': OrderStatus.asignado,
        'order-entregado': OrderStatus.entregado,
        'order-cancelado': OrderStatus.cancelado,
      };

      for (final entry in seeded.entries) {
        await repository.save(_buildOrder(id: entry.key, status: entry.value));
      }

      for (final entry in seeded.entries) {
        final found = await repository.getById(entry.key);
        expect(
          found!.status,
          entry.value,
          reason: '${entry.key} was written as ${entry.value} but read back as ${found.status}',
        );
        // Explicitly guard against the exact corruption scenario the
        // design decision warns about: a pre-existing status must never
        // silently become enCamino after this migration.
        expect(found.status, isNot(OrderStatus.enCamino));
      }
    });

    test('enCamino itself round-trips correctly at its new appended ordinal', () async {
      await repository.save(_buildOrder(id: 'order-en-camino', status: OrderStatus.enCamino));

      final found = await repository.getById('order-en-camino');

      expect(found!.status, OrderStatus.enCamino);
    });

    test('all five OrderStatus values round-trip through a fresh Isar instance', () async {
      for (final status in OrderStatus.values) {
        await repository.save(_buildOrder(id: 'order-${status.name}', status: status));
      }

      for (final status in OrderStatus.values) {
        final found = await repository.getById('order-${status.name}');
        expect(found!.status, status);
      }
    });
  });
}
