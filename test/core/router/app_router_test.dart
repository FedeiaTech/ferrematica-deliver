import 'package:ferrematica_express/features/auth/domain/app_session.dart';
import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../features/orders/presentation/fake_orders_repository.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_app.dart';

/// Redirect matrix for `goRouterProvider`'s auth guard (design decision
/// #3): unauthenticated → `/login`, dueño → `/orders`, cadete →
/// `/delivery` (cadete-scoped order list, PR4). Also covers PR4's
/// defense-in-depth role gating: a cadete can never land on `/orders/*`
/// and a dueño can never land on `/delivery/*`, even via a direct
/// `context.go(...)` call.
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

    expect(find.text('Todos'), findsOneWidget);
  });

  testWidgets('authenticated cadete is redirected to /delivery', (tester) async {
    final authRepository = FakeAuthRepository(
      initialSession: const AppSession(userId: 'cadete-1', rol: UserRole.cadete),
    );
    addTearDown(authRepository.dispose);

    await boot(tester, authRepository);

    expect(find.text('Todavía no tenés pedidos asignados.'), findsOneWidget);
  });

  testWidgets('signing out from /delivery redirects back to /login', (tester) async {
    final authRepository = FakeAuthRepository(
      initialSession: const AppSession(userId: 'cadete-1', rol: UserRole.cadete),
    );
    addTearDown(authRepository.dispose);

    await boot(tester, authRepository);
    expect(find.text('Todavía no tenés pedidos asignados.'), findsOneWidget);

    authRepository.setSession(null);
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets(
    'a cadete navigating directly to /orders is redirected back to /delivery',
    (tester) async {
      final authRepository = FakeAuthRepository(
        initialSession: const AppSession(userId: 'cadete-1', rol: UserRole.cadete),
      );
      addTearDown(authRepository.dispose);

      await boot(tester, authRepository);
      expect(find.text('Todavía no tenés pedidos asignados.'), findsOneWidget);

      final context = tester.element(find.byType(Scaffold).first);
      GoRouter.of(context).go('/orders');
      await tester.pumpAndSettle();

      // Defense-in-depth (PR4): the router guard blocks a cadete from
      // `/orders/*` entirely, not just from the dueño-only action buttons.
      expect(find.text('Todavía no tenés pedidos asignados.'), findsOneWidget);
      expect(find.text('Todos'), findsNothing);
    },
  );

  testWidgets(
    'a dueño navigating directly to /delivery is redirected back to /orders',
    (tester) async {
      final authRepository = FakeAuthRepository(
        initialSession: const AppSession(userId: 'owner-1', rol: UserRole.dueno),
      );
      addTearDown(authRepository.dispose);

      await boot(tester, authRepository);
      expect(find.text('Todos'), findsOneWidget);

      final context = tester.element(find.byType(Scaffold).first);
      GoRouter.of(context).go('/delivery');
      await tester.pumpAndSettle();

      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Todavía no tenés pedidos asignados.'), findsNothing);
    },
  );
}
