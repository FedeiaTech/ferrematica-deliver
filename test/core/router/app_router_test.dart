import 'package:ferrematica_express/features/auth/domain/app_session.dart';
import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/main.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/orders/presentation/fake_orders_repository.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_app.dart';

/// Redirect matrix for `goRouterProvider`'s auth guard (design decision
/// #3): unauthenticated → `/login`, dueño → `/orders`, cadete →
/// `/delivery` (a placeholder screen — real cadete views land in PR4).
void main() {
  Future<void> boot(WidgetTester tester, FakeAuthRepository authRepository) async {
    final ordersRepository = FakeOrdersRepository();
    addTearDown(ordersRepository.dispose);

    await pumpApp(
      tester,
      const FerrematicaApp(),
      authRepository: authRepository,
      overrides: [ordersRepositoryProvider.overrideWithValue(ordersRepository)],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('unauthenticated user is redirected to /login', (tester) async {
    final authRepository = FakeAuthRepository();
    addTearDown(authRepository.dispose);

    await boot(tester, authRepository);

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('authenticated dueño is redirected to /orders', (tester) async {
    final authRepository = FakeAuthRepository(
      initialSession: const AppSession(userId: 'owner-1', rol: UserRole.dueno),
    );
    addTearDown(authRepository.dispose);

    await boot(tester, authRepository);

    expect(find.text('Pedidos'), findsOneWidget);
  });

  testWidgets('authenticated cadete is redirected to /delivery', (tester) async {
    final authRepository = FakeAuthRepository(
      initialSession: const AppSession(userId: 'cadete-1', rol: UserRole.cadete),
    );
    addTearDown(authRepository.dispose);

    await boot(tester, authRepository);

    expect(find.text('Cadete'), findsOneWidget);
  });

  testWidgets('signing out from /delivery redirects back to /login', (tester) async {
    final authRepository = FakeAuthRepository(
      initialSession: const AppSession(userId: 'cadete-1', rol: UserRole.cadete),
    );
    addTearDown(authRepository.dispose);

    await boot(tester, authRepository);
    expect(find.text('Cadete'), findsOneWidget);

    authRepository.setSession(null);
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
