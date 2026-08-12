import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/presentation/screens/delivery_stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import 'fake_orders_repository.dart';

/// DA5 (design): a `cobrado` order with a non-null `pendingBalance` (a
/// partial collection) must NOT be reported as fully collected — the
/// screen must credit only `amountToCharge - pendingBalance` to
/// "Cobrado" and separately surface the still-owed amount under
/// "Pendientes de cobrar"/"Monto adeudado", same as an order that hasn't
/// been collected at all.
void main() {
  testWidgets(
    'a partially-paid delivered order credits only the collected portion to "Cobrado", '
    'not the full amountToCharge',
    (tester) async {
      final deliveredAt = DateTime.now();
      final repository = FakeOrdersRepository(
        seed: [
          buildTestOrder(
            id: 'order-1',
            status: OrderStatus.entregado,
            paymentStatus: PaymentStatus.cobrado,
            amountToCharge: 100,
            pendingBalance: 60,
            assignedCadeteId: 'fake-owner',
          ).copyWith(deliveredAt: deliveredAt, updatedAt: deliveredAt),
        ],
      );
      addTearDown(repository.dispose);

      await pumpApp(
        tester,
        const MaterialApp(home: DeliveryStatsScreen()),
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      // Correct behavior: only the collected $40 (100 - 60) is credited as
      // "Cobrado". The pre-fix code credited the full $100.
      expect(find.text('\$40.00'), findsOneWidget);
      expect(find.text('\$100.00'), findsNothing);

      // The still-owed $60 must surface under "Pendientes de cobrar" /
      // "Monto adeudado", same as a delivery collected $0 would.
      expect(find.text('Pendientes de cobrar'), findsOneWidget);
      expect(find.text('Monto adeudado'), findsOneWidget);
      expect(find.text('\$60.00'), findsOneWidget); // pendingPaymentAmount
    },
  );
}
