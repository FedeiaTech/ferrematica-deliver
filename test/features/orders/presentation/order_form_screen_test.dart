import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/presentation/screens/order_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pump_app.dart';
import 'fake_orders_repository.dart';

/// [OrderFormScreen] reads `go_router`'s context extensions (`canPop`/`pop`)
/// on submit, so it needs a real [GoRouter] ancestor even in isolation.
Widget _withRouter({Order? existingOrder}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => OrderFormScreen(existingOrder: existingOrder),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('submit with only the address succeeds', (tester) async {
    final repository = FakeOrdersRepository();
    addTearDown(repository.dispose);

    await pumpApp(
      tester,
      _withRouter(),
      overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Calle Falsa 123');
    await tester.pump();

    final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveButton.onPressed, isNotNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final saved = await repository.getById(
      (await repository.pendingSync()).single.id,
    );
    expect(saved, isNotNull);
    expect(saved!.deliveryAddress, 'Calle Falsa 123');
  });

  testWidgets('empty address keeps save disabled and blocks submission', (tester) async {
    final repository = FakeOrdersRepository();
    addTearDown(repository.dispose);

    await pumpApp(
      tester,
      _withRouter(),
      overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveButton.onPressed, isNull);

    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(await repository.pendingSync(), isEmpty);
  });

  testWidgets('optional section renders and its values persist on save', (tester) async {
    final repository = FakeOrdersRepository();
    addTearDown(repository.dispose);

    await pumpApp(
      tester,
      _withRouter(),
      overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Calle Falsa 123');
    await tester.pump();

    // The optional section starts collapsed for a new order — expand it.
    await tester.tap(find.text('Datos opcionales'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre del cliente'), 'Juan');
    await tester.pumpAndSettle();

    // The expanded optional section pushes "Guardar" out of the small test
    // viewport, and Sliver lazy-building means an offscreen item beyond the
    // cache extent has no Element yet — `ensureVisible` can't target
    // something that doesn't exist. Scroll it into view manually first.
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final saved = (await repository.pendingSync()).single;
    expect(saved.clientName, 'Juan');
  });

  group('DA4 — editing amountToCharge below a recorded pendingBalance', () {
    testWidgets(
      'is rejected with a clear validation error, not silently saved',
      (tester) async {
        final existing = buildTestOrder(
          id: 'order-1',
          status: OrderStatus.entregado,
          paymentStatus: PaymentStatus.cobrado,
          amountToCharge: 100,
          pendingBalance: 60,
        );
        final repository = FakeOrdersRepository(seed: [existing]);
        addTearDown(repository.dispose);

        await pumpApp(
          tester,
          _withRouter(existingOrder: existing),
          overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
        );
        await tester.pumpAndSettle();

        // The optional section (where "Monto a cobrar" lives) starts
        // expanded while editing (`initiallyExpanded: isEditing`).
        final amountField = find.widgetWithText(TextFormField, 'Monto a cobrar');
        await tester.ensureVisible(amountField);
        await tester.enterText(amountField, '60');
        await tester.pump();

        await tester.ensureVisible(find.byType(FilledButton));
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        // Rejected — the order in the repository must be untouched.
        final saved = await repository.getById('order-1');
        expect(saved!.amountToCharge, 100);
        expect(saved.pendingBalance, 60);
        expect(
          find.textContaining('saldo pendiente'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a valid edit (amount still >= pendingBalance) succeeds normally',
      (tester) async {
        final existing = buildTestOrder(
          id: 'order-1',
          status: OrderStatus.entregado,
          paymentStatus: PaymentStatus.cobrado,
          amountToCharge: 100,
          pendingBalance: 60,
        );
        final repository = FakeOrdersRepository(seed: [existing]);
        addTearDown(repository.dispose);

        await pumpApp(
          tester,
          _withRouter(existingOrder: existing),
          overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
        );
        await tester.pumpAndSettle();

        final amountField = find.widgetWithText(TextFormField, 'Monto a cobrar');
        await tester.ensureVisible(amountField);
        await tester.enterText(amountField, '150');
        await tester.pump();

        await tester.ensureVisible(find.byType(FilledButton));
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        final saved = await repository.getById('order-1');
        expect(saved!.amountToCharge, 150);
      },
    );

    testWidgets(
      'an order with no pendingBalance can have its amount edited freely',
      (tester) async {
        final existing = buildTestOrder(id: 'order-1', amountToCharge: 100);
        final repository = FakeOrdersRepository(seed: [existing]);
        addTearDown(repository.dispose);

        await pumpApp(
          tester,
          _withRouter(existingOrder: existing),
          overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
        );
        await tester.pumpAndSettle();

        final amountField = find.widgetWithText(TextFormField, 'Monto a cobrar');
        await tester.ensureVisible(amountField);
        await tester.enterText(amountField, '10');
        await tester.pump();

        await tester.ensureVisible(find.byType(FilledButton));
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        final saved = await repository.getById('order-1');
        expect(saved!.amountToCharge, 10);
      },
    );
  });
}
