import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/presentation/screens/orders_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pump_app.dart';
import 'fake_orders_repository.dart';

Widget _withRouter(Widget home) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (context, state) => home)],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('shows the incomplete badge for an order missing amountToCharge', (tester) async {
    final repository = FakeOrdersRepository(
      seed: [buildTestOrder(id: 'order-1', amountToCharge: null)],
    );
    addTearDown(repository.dispose);

    await pumpApp(
      tester,
      _withRouter(const OrdersListScreen()),
      overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin monto cargado'), findsOneWidget);
  });

  testWidgets('shows the payment-pending banner when an order needs follow-up', (tester) async {
    final repository = FakeOrdersRepository(
      seed: [
        buildTestOrder(
          id: 'order-1',
          status: OrderStatus.entregado,
          paymentStatus: PaymentStatus.pendiente,
        ),
      ],
    );
    addTearDown(repository.dispose);

    await pumpApp(
      tester,
      _withRouter(const OrdersListScreen()),
      overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.text('1 pedido entregado con cobro pendiente'), findsOneWidget);
  });

  testWidgets('does not show the banner when no order needs follow-up', (tester) async {
    final repository = FakeOrdersRepository(
      seed: [
        buildTestOrder(
          id: 'order-1',
          status: OrderStatus.entregado,
          paymentStatus: PaymentStatus.cobrado,
        ),
      ],
    );
    addTearDown(repository.dispose);

    await pumpApp(
      tester,
      _withRouter(const OrdersListScreen()),
      overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('cobro pendiente'), findsNothing);
  });
}
