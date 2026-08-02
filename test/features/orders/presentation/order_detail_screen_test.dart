import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import 'fake_orders_repository.dart';

void main() {
  testWidgets(
    'marking delivered with pending payment completes without blocking and shows the alert',
    (tester) async {
      // Seeded at enCamino, not asignado: per navegacion-cadete's tightened
      // lifecycle (PR2), entregado is now only reachable from enCamino —
      // asignado -> entregado directly would skip a step and be rejected.
      final repository = FakeOrdersRepository(
        seed: [buildTestOrder(id: 'order-1', status: OrderStatus.enCamino)],
      );
      addTearDown(repository.dispose);

      await pumpApp(
        tester,
        const MaterialApp(home: OrderDetailScreen(orderId: 'order-1')),
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Marcar entregado'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cobro pendiente'));
      await tester.pumpAndSettle();

      // The transition MUST NOT be blocked by the pending payment.
      final saved = await repository.getById('order-1');
      expect(saved!.status, OrderStatus.entregado);
      expect(saved.paymentStatus, PaymentStatus.pendiente);

      // The dueño-facing alert MUST be surfaced, non-blocking.
      expect(find.text('1 pedido entregado con cobro pendiente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
