import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pump_app.dart';
import 'fake_orders_repository.dart';

/// Mirrors order_detail_screen_partial_payment_test.dart's router wrapper.
Widget _withRouter(Widget home) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (context, state) => home)],
  );
  return MaterialApp.router(routerConfig: router);
}

/// `reportDeliveryProblem` sets `status: OrderStatus.cancelado` — a real,
/// hard-to-undo consequence. Picking a reason must not report it
/// immediately; a confirmation dialog spelling out that consequence has to
/// come first, and "Cancelar" there must leave the order untouched.
void main() {
  group('reporting a delivery problem asks for confirmation first', () {
    testWidgets(
      'picking a reason opens a confirmation dialog naming the reason and the '
      'cancellation consequence, before anything is reported',
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

        await tester.tap(find.text('Indicar problema'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cliente ausente o no atendió'));
        await tester.pumpAndSettle();

        expect(find.text('Reportar problema'), findsOneWidget);
        expect(find.textContaining('Cliente ausente o no atendió'), findsOneWidget);
        expect(find.textContaining('CANCELAR'), findsOneWidget);
        // Not reported yet — the order is still whatever it was before.
        expect((await repository.getById('order-1'))!.status, OrderStatus.enCamino);
        expect((await repository.getById('order-1'))!.deliveryProblem, isNull);
      },
    );

    testWidgets('"Cancelar" on the confirmation dialog reports nothing', (tester) async {
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

      await tester.tap(find.text('Indicar problema'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cliente ausente o no atendió'));
      await tester.pumpAndSettle();

      // Two "Cancelar" buttons could plausibly exist across the flow — this
      // one belongs to the AlertDialog raised by tapping the reason above.
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancelar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reportar problema'), findsNothing);
      expect((await repository.getById('order-1'))!.status, OrderStatus.enCamino);
      expect((await repository.getById('order-1'))!.deliveryProblem, isNull);
    });

    testWidgets(
      '"Confirmar" on the confirmation dialog reports the problem and cancels the order',
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

        await tester.tap(find.text('Indicar problema'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cliente ausente o no atendió'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(of: find.byType(AlertDialog), matching: find.text('Confirmar')),
        );
        await tester.pumpAndSettle();

        expect((await repository.getById('order-1'))!.status, OrderStatus.cancelado);
        expect((await repository.getById('order-1'))!.deliveryProblem, 'Cliente ausente o no atendió');
      },
    );
  });
}
