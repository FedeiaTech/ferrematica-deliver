import 'package:ferrematica_express/features/orders/data/isar_orders_repository.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../../../helpers/test_isar.dart';

/// Mirrors `order_model_pending_balance_test.dart`: `valorEnvio` is a purely
/// additive nullable Isar property (same shape as `pendingBalance`), so
/// round-tripping it requires no schema-version bump.
Order _buildOrder({String id = 'order-1', double? valorEnvio}) {
  final now = DateTime(2026, 1, 1);
  return Order(
    id: id,
    deliveryAddress: 'Calle Falsa 123',
    createdBy: 'owner-1',
    createdAt: now,
    updatedAt: now,
    valorEnvio: valorEnvio,
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

  group('OrderModel.valorEnvio Isar round-trip', () {
    test('a non-null valorEnvio survives save + getById', () async {
      await repository.save(_buildOrder(valorEnvio: 500));

      final found = await repository.getById('order-1');

      expect(found!.valorEnvio, 500);
    });

    test('null valorEnvio survives save + getById', () async {
      await repository.save(_buildOrder());

      final found = await repository.getById('order-1');

      expect(found!.valorEnvio, isNull);
    });

    test('clearing valorEnvio via update persists as null', () async {
      await repository.save(_buildOrder(valorEnvio: 500));
      final saved = await repository.getById('order-1');

      await repository.save(saved!.copyWith(clearValorEnvio: true));
      final found = await repository.getById('order-1');

      expect(found!.valorEnvio, isNull);
    });
  });
}
