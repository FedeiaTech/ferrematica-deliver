import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pump_app.dart';
import 'fake_orders_repository.dart';

/// "Marcar entregado" pops the detail screen, so tests need a real
/// [GoRouter] in the tree (mirrors order_detail_screen_test.dart).
Widget _withRouter(Widget home) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (context, state) => home)],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  group('_openMarkDeliveredSheet — Cobro parcial (design DA6)', () {
    testWidgets(
      '"Cobro parcial" tile is offered when amountToCharge is set',
      (tester) async {
        final repository = FakeOrdersRepository(
          seed: [
            buildTestOrder(
              id: 'order-1',
              status: OrderStatus.enCamino,
              amountToCharge: 100,
            ),
          ],
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

        expect(find.text('Cobro parcial'), findsOneWidget);
      },
    );

    testWidgets(
      '"Cobro parcial" tile is omitted when the order has no amountToCharge',
      (tester) async {
        final repository = FakeOrdersRepository(
          seed: [
            buildTestOrder(id: 'order-1', status: OrderStatus.enCamino),
          ],
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

        expect(find.text('Cobro parcial'), findsNothing);
      },
    );

    testWidgets(
      'step 2 refuses an amount >= the total, blocking confirmation',
      (tester) async {
        final repository = FakeOrdersRepository(
          seed: [
            buildTestOrder(
              id: 'order-1',
              status: OrderStatus.enCamino,
              amountToCharge: 100,
            ),
          ],
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
        await tester.tap(find.text('Cobro parcial'));
        await tester.pumpAndSettle();

        await tester.enterText(find.widgetWithText(TextField, 'Monto cobrado'), '100');
        await tester.pump();

        final confirmButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Confirmar'),
        );
        expect(confirmButton.onPressed, isNull);
      },
    );

    testWidgets(
      'step 2 refuses a zero/negative amount, blocking confirmation',
      (tester) async {
        final repository = FakeOrdersRepository(
          seed: [
            buildTestOrder(
              id: 'order-1',
              status: OrderStatus.enCamino,
              amountToCharge: 100,
            ),
          ],
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
        await tester.tap(find.text('Cobro parcial'));
        await tester.pumpAndSettle();

        await tester.enterText(find.widgetWithText(TextField, 'Monto cobrado'), '0');
        await tester.pump();

        final confirmButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Confirmar'),
        );
        expect(confirmButton.onPressed, isNull);
      },
    );

    testWidgets(
      '"Volver" returns to step 1 without dismissing the sheet',
      (tester) async {
        final repository = FakeOrdersRepository(
          seed: [
            buildTestOrder(
              id: 'order-1',
              status: OrderStatus.enCamino,
              amountToCharge: 100,
            ),
          ],
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
        await tester.tap(find.text('Cobro parcial'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Volver'));
        await tester.pumpAndSettle();

        expect(find.text('¿Cómo queda el cobro?'), findsOneWidget);
      },
    );

    testWidgets(
      'a valid partial amount confirms, saves the correct pendingBalance, '
      'and the 3-branch Pago row reflects it',
      (tester) async {
        final repository = FakeOrdersRepository(
          seed: [
            buildTestOrder(
              id: 'order-1',
              status: OrderStatus.enCamino,
              amountToCharge: 100,
            ),
          ],
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
        await tester.tap(find.text('Cobro parcial'));
        await tester.pumpAndSettle();

        await tester.enterText(find.widgetWithText(TextField, 'Monto cobrado'), '40');
        await tester.pump();

        final confirmButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Confirmar'),
        );
        expect(confirmButton.onPressed, isNotNull);

        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
        await tester.pumpAndSettle();

        final saved = await repository.getById('order-1');
        expect(saved!.status, OrderStatus.entregado);
        expect(saved.paymentStatus, PaymentStatus.cobrado);
        expect(saved.pendingBalance, 60);
      },
    );
  });

  group('_openMarkDeliveredSheet — cadetería follow-up (valorEnvio set)', () {
    testWidgets(
      '"Cadetería cobrada completa" leaves envioPendingBalance null',
      (tester) async {
        final repository = FakeOrdersRepository(
          seed: [
            buildTestOrder(
              id: 'order-1',
              status: OrderStatus.enCamino,
              valorEnvio: 200,
            ),
          ],
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
        await tester.tap(find.text('Pago total'));
        await tester.pumpAndSettle();

        expect(find.text('¿Cómo queda el cobro de la cadetería?'), findsOneWidget);

        await tester.tap(find.text('Cadetería cobrada completa'));
        await tester.pumpAndSettle();

        final saved = await repository.getById('order-1');
        expect(saved!.status, OrderStatus.entregado);
        expect(saved.envioPendingBalance, isNull);
      },
    );

    testWidgets(
      '"Cadetería cobro parcial" saves the correct remaining amount',
      (tester) async {
        final repository = FakeOrdersRepository(
          seed: [
            buildTestOrder(
              id: 'order-1',
              status: OrderStatus.enCamino,
              valorEnvio: 200,
            ),
          ],
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
        await tester.tap(find.text('Pago total'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cadetería cobro parcial'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Monto cobrado de cadetería'),
          '80',
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
        await tester.pumpAndSettle();

        final saved = await repository.getById('order-1');
        expect(saved!.status, OrderStatus.entregado);
        expect(saved.envioPendingBalance, 120);
      },
    );

    testWidgets(
      '"Cadetería no cobrada" saves envioPendingBalance == valorEnvio',
      (tester) async {
        final repository = FakeOrdersRepository(
          seed: [
            buildTestOrder(
              id: 'order-1',
              status: OrderStatus.enCamino,
              valorEnvio: 200,
            ),
          ],
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
        await tester.tap(find.text('Pago total'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cadetería no cobrada'));
        await tester.pumpAndSettle();

        final saved = await repository.getById('order-1');
        expect(saved!.status, OrderStatus.entregado);
        expect(saved.envioPendingBalance, 200);
      },
    );

    testWidgets(
      'cadetería follow-up is skipped entirely when valorEnvio is null',
      (tester) async {
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
        await tester.tap(find.text('Pago total'));
        await tester.pumpAndSettle();

        final saved = await repository.getById('order-1');
        expect(saved!.status, OrderStatus.entregado);
        expect(saved.envioPendingBalance, isNull);
      },
    );
  });
}
