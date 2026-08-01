import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/presentation/screens/order_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pump_app.dart';
import 'fake_orders_repository.dart';

/// [OrderFormScreen] reads `go_router`'s context extensions (`canPop`/`pop`)
/// on submit, so it needs a real [GoRouter] ancestor even in isolation.
Widget _withRouter() {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (context, state) => const OrderFormScreen())],
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
}
