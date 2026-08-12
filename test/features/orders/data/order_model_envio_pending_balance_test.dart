import 'package:ferrematica_express/features/orders/data/isar_orders_repository.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../../../helpers/test_isar.dart';

/// Mirrors `order_model_pending_balance_test.dart`/
/// `order_model_valor_envio_test.dart`: `envioPendingBalance` is a purely
/// additive nullable Isar property (same shape as `pendingBalance`/
/// `valorEnvio`), so round-tripping it requires no schema-version bump.
Order _buildOrder({String id = 'order-1', double? valorEnvio, double? envioPendingBalance}) {
  final now = DateTime(2026, 1, 1);
  return Order(
    id: id,
    deliveryAddress: 'Calle Falsa 123',
    createdBy: 'owner-1',
    createdAt: now,
    updatedAt: now,
    valorEnvio: valorEnvio,
    envioPendingBalance: envioPendingBalance,
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

  group('OrderModel.envioPendingBalance Isar round-trip', () {
    test('a non-null envioPendingBalance survives save + getById', () async {
      await repository.save(_buildOrder(valorEnvio: 500, envioPendingBalance: 200));

      final found = await repository.getById('order-1');

      expect(found!.envioPendingBalance, 200);
    });

    test('null envioPendingBalance survives save + getById', () async {
      await repository.save(_buildOrder(valorEnvio: 500));

      final found = await repository.getById('order-1');

      expect(found!.envioPendingBalance, isNull);
    });

    test('clearing envioPendingBalance via update persists as null', () async {
      await repository.save(_buildOrder(valorEnvio: 500, envioPendingBalance: 200));
      final saved = await repository.getById('order-1');

      await repository.save(saved!.copyWith(clearEnvioPendingBalance: true));
      final found = await repository.getById('order-1');

      expect(found!.envioPendingBalance, isNull);
    });
  });
}
