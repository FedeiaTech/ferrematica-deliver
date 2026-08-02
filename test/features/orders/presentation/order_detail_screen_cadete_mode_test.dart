import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pump_app.dart';
import 'fake_orders_repository.dart';

Widget _withRouter(Widget home) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => home),
      GoRoute(
        path: '/delivery/:id/navigate',
        builder: (context, state) => const Scaffold(body: Text('Navegación (stub)')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

/// Covers design decision #8: [OrderDetailScreen] is reused for the
/// cadete-facing detail view via `readOnlyForCadete: true`, instead of a
/// forked screen. A cadete must never be able to reach the dueño-only
/// actions ("Editar", "Asignar cadete"/"Reasignar cadete", "Cancelar
/// pedido", "Eliminar") even when opening the very same widget the dueño
/// uses.
void main() {
  testWidgets(
    'readOnlyForCadete hides every dueño-only action on an assignable order',
    (tester) async {
      final repository = FakeOrdersRepository(
        seed: [
          buildTestOrder(
            id: 'order-1',
            status: OrderStatus.asignado,
            assignedCadeteId: 'cadete-1',
          ),
        ],
      );
      addTearDown(repository.dispose);

      await pumpApp(
        tester,
        const MaterialApp(
          home: OrderDetailScreen(orderId: 'order-1', readOnlyForCadete: true),
        ),
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsNothing);
      expect(find.text('Asignar cadete'), findsNothing);
      expect(find.text('Reasignar cadete'), findsNothing);
      expect(find.text('Cancelar pedido'), findsNothing);
      expect(find.text('Eliminar'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'readOnlyForCadete still shows "Marcar entregado" once en_camino',
    (tester) async {
      final repository = FakeOrdersRepository(
        seed: [
          buildTestOrder(
            id: 'order-1',
            status: OrderStatus.enCamino,
            assignedCadeteId: 'cadete-1',
          ),
        ],
      );
      addTearDown(repository.dispose);

      await pumpApp(
        tester,
        const MaterialApp(
          home: OrderDetailScreen(orderId: 'order-1', readOnlyForCadete: true),
        ),
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      // Per spec's order-management domain, the assigned cadete is the one
      // who closes en_camino -> entregado through this same flow.
      expect(find.text('Marcar entregado'), findsOneWidget);

      await tester.tap(find.text('Marcar entregado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cobrado'));
      await tester.pumpAndSettle();

      final saved = await repository.getById('order-1');
      expect(saved!.status, OrderStatus.entregado);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dueño mode (default) still shows every dueño-only action',
    (tester) async {
      final repository = FakeOrdersRepository(
        seed: [buildTestOrder(id: 'order-1', status: OrderStatus.pendiente)],
      );
      addTearDown(repository.dispose);

      await pumpApp(
        tester,
        const MaterialApp(home: OrderDetailScreen(orderId: 'order-1')),
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Asignar cadete'), findsOneWidget);
      expect(find.text('Cancelar pedido'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
    },
  );

  testWidgets(
    'readOnlyForCadete shows "Iniciar navegación" only while asignado',
    (tester) async {
      final repository = FakeOrdersRepository(
        seed: [
          buildTestOrder(
            id: 'order-1',
            status: OrderStatus.asignado,
            assignedCadeteId: 'cadete-1',
          ),
        ],
      );
      addTearDown(repository.dispose);

      await pumpApp(
        tester,
        _withRouter(
          const OrderDetailScreen(orderId: 'order-1', readOnlyForCadete: true),
        ),
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      expect(find.text('Iniciar navegación'), findsOneWidget);
      expect(find.text('Ver ruta'), findsNothing);
    },
  );

  testWidgets(
    'tapping "Iniciar navegación" transitions asignado -> en_camino and opens the map',
    (tester) async {
      final repository = FakeOrdersRepository(
        seed: [
          buildTestOrder(
            id: 'order-1',
            status: OrderStatus.asignado,
            assignedCadeteId: 'cadete-1',
          ),
        ],
      );
      addTearDown(repository.dispose);

      await pumpApp(
        tester,
        _withRouter(
          const OrderDetailScreen(orderId: 'order-1', readOnlyForCadete: true),
        ),
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Iniciar navegación'));
      await tester.pumpAndSettle();

      final saved = await repository.getById('order-1');
      expect(saved!.status, OrderStatus.enCamino);
      expect(find.text('Navegación (stub)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'readOnlyForCadete shows "Ver ruta" (no transition) once en_camino',
    (tester) async {
      final repository = FakeOrdersRepository(
        seed: [
          buildTestOrder(
            id: 'order-1',
            status: OrderStatus.enCamino,
            assignedCadeteId: 'cadete-1',
          ),
        ],
      );
      addTearDown(repository.dispose);

      await pumpApp(
        tester,
        _withRouter(
          const OrderDetailScreen(orderId: 'order-1', readOnlyForCadete: true),
        ),
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      expect(find.text('Iniciar navegación'), findsNothing);
      expect(find.text('Ver ruta'), findsOneWidget);

      await tester.tap(find.text('Ver ruta'));
      await tester.pumpAndSettle();

      final saved = await repository.getById('order-1');
      expect(saved!.status, OrderStatus.enCamino);
      expect(find.text('Navegación (stub)'), findsOneWidget);
    },
  );
}
