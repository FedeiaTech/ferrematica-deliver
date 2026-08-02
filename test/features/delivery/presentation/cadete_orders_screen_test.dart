import 'package:ferrematica_express/features/auth/domain/app_session.dart';
import 'package:ferrematica_express/features/delivery/presentation/screens/cadete_orders_screen.dart';
import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/pump_app.dart';
import '../../orders/presentation/fake_orders_repository.dart';

Widget _withRouter(Widget home) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (context, state) => home)],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('shows only orders assigned to the signed-in cadete', (tester) async {
    final repository = FakeOrdersRepository(
      seed: [
        buildTestOrder(
          id: 'order-1',
          deliveryAddress: 'Mi pedido asignado',
          assignedCadeteId: 'cadete-1',
        ),
        buildTestOrder(
          id: 'order-2',
          deliveryAddress: 'Pedido de otro cadete',
          assignedCadeteId: 'cadete-2',
        ),
        buildTestOrder(
          id: 'order-3',
          deliveryAddress: 'Pedido sin asignar',
        ),
      ],
    );
    addTearDown(repository.dispose);
    final authRepository = FakeAuthRepository(
      initialSession: const AppSession(userId: 'cadete-1', rol: UserRole.cadete),
    );

    await pumpApp(
      tester,
      _withRouter(const CadeteOrdersScreen()),
      overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      authRepository: authRepository,
    );
    await tester.pumpAndSettle();

    expect(find.text('Mi pedido asignado'), findsOneWidget);
    expect(find.text('Pedido de otro cadete'), findsNothing);
    expect(find.text('Pedido sin asignar'), findsNothing);
  });

  testWidgets('shows an empty state when the cadete has no assigned orders', (tester) async {
    final repository = FakeOrdersRepository(
      seed: [buildTestOrder(id: 'order-1', assignedCadeteId: 'cadete-2')],
    );
    addTearDown(repository.dispose);
    final authRepository = FakeAuthRepository(
      initialSession: const AppSession(userId: 'cadete-1', rol: UserRole.cadete),
    );

    await pumpApp(
      tester,
      _withRouter(const CadeteOrdersScreen()),
      overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      authRepository: authRepository,
    );
    await tester.pumpAndSettle();

    expect(find.text('Todavía no tenés pedidos asignados.'), findsOneWidget);
  });
}
