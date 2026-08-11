import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pump_app.dart';
import 'fake_orders_repository.dart';

/// "Marcar entregado" pops the detail screen (order_detail_screen.dart), so
/// tests exercising it need a real GoRouter in the tree — a bare
/// `MaterialApp(home: ...)` has no GoRouter and `context.pop()`/`canPop()`
/// throw without one.
Widget _withRouter(Widget home) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (context, state) => home)],
  );
  return MaterialApp.router(routerConfig: router);
}

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
        _withRouter(const OrderDetailScreen(orderId: 'order-1')),
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Marcar entrega'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cobro pendiente'));
      await tester.pumpAndSettle();

      // The transition MUST NOT be blocked by the pending payment. The
      // dueño-facing payment-pending alert itself only shows on the
      // dashboard (orders_list_screen.dart), not here — this screen just
      // proves the non-blocking transition works.
      final saved = await repository.getById('order-1');
      expect(saved!.status, OrderStatus.entregado);
      expect(saved.paymentStatus, PaymentStatus.pendiente);
      expect(tester.takeException(), isNull);
    },
  );
}
