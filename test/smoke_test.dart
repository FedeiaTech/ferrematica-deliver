import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/orders/presentation/fake_orders_repository.dart';
import 'helpers/pump_app.dart';

void main() {
  testWidgets('app boots and redirects to the orders list without crashing', (
    tester,
  ) async {
    // Overrides the repository with an in-memory fake so this boot-smoke
    // test never depends on Isar's native watch-stream callback, which
    // (like Isar's open/close calls — see pump_app.dart) doesn't resolve
    // inside pumpAndSettle's fake-async test zone and would otherwise hang
    // the indeterminate loading spinner's animation forever.
    final repository = FakeOrdersRepository();
    addTearDown(repository.dispose);

    await pumpApp(
      tester,
      const FerrematicaApp(),
      overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Todavía no hay pedidos.'), findsOneWidget);
  });
}
