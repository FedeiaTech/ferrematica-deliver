import 'package:ferrematica_express/features/orders/data/isar_orders_repository.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../../../helpers/test_isar.dart';

/// Covers `cobro-parcial-pedidos` design decision DA1: `pendingBalance` is a
/// purely additive nullable Isar property (mirrors `amountToCharge`, not
/// `@enumerated`), so round-tripping it requires no schema-version bump.
Order _buildOrder({
  String id = 'order-1',
  double? amountToCharge,
  PaymentStatus paymentStatus = PaymentStatus.pendiente,
  double? pendingBalance,
}) {
  final now = DateTime(2026, 1, 1);
  return Order(
    id: id,
    deliveryAddress: 'Calle Falsa 123',
    createdBy: 'owner-1',
    createdAt: now,
    updatedAt: now,
    amountToCharge: amountToCharge,
    paymentStatus: paymentStatus,
    pendingBalance: pendingBalance,
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

  group('OrderModel.pendingBalance Isar round-trip', () {
    test('a non-null partial balance survives save + getById', () async {
      await repository.save(
        _buildOrder(
          amountToCharge: 100,
          paymentStatus: PaymentStatus.cobrado,
          pendingBalance: 60,
        ),
      );

      final found = await repository.getById('order-1');

      expect(found!.pendingBalance, 60);
    });

    test('null pendingBalance survives save + getById', () async {
      await repository.save(_buildOrder());

      final found = await repository.getById('order-1');

      expect(found!.pendingBalance, isNull);
    });

    test('clearing pendingBalance via update persists as null', () async {
      await repository.save(
        _buildOrder(
          amountToCharge: 100,
          paymentStatus: PaymentStatus.cobrado,
          pendingBalance: 60,
        ),
      );
      final saved = await repository.getById('order-1');

      await repository.save(saved!.copyWith(clearPendingBalance: true));
      final found = await repository.getById('order-1');

      expect(found!.pendingBalance, isNull);
    });
  });
}
