import 'package:ferrematica_express/features/auth/data/providers.dart';
import 'package:ferrematica_express/features/auth/domain/cadete_directory.dart';
import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_cadete_directory.dart';
import '../../../helpers/pump_app.dart';
import 'fake_orders_repository.dart';

void main() {
  testWidgets(
    'dueño assigns a cadete to a pendiente order from the detail screen',
    (tester) async {
      final repository = FakeOrdersRepository(
        seed: [buildTestOrder(id: 'order-1', status: OrderStatus.pendiente)],
      );
      addTearDown(repository.dispose);
      final cadeteDirectory = FakeCadeteDirectory(
        cadetes: const [
          CadeteProfile(id: 'cadete-1', fullName: 'Juan Pérez'),
          CadeteProfile(id: 'cadete-2', fullName: 'María Gómez'),
        ],
      );

      await pumpApp(
        tester,
        const MaterialApp(home: OrderDetailScreen(orderId: 'order-1')),
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repository),
          cadeteDirectoryProvider.overrideWithValue(cadeteDirectory),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Asignar cadete'), findsOneWidget);

      await tester.tap(find.text('Asignar cadete'));
      await tester.pumpAndSettle();

      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('María Gómez'), findsOneWidget);

      await tester.tap(find.text('Juan Pérez'));
      await tester.pumpAndSettle();

      final saved = await repository.getById('order-1');
      expect(saved!.assignedCadeteId, 'cadete-1');
      expect(saved.status, OrderStatus.asignado);

      // The detail screen shows the resolved name in the "Cadete asignado"
      // row; the status chip stays the plain "Asignado" word — and the
      // action label switches to "Reasignar cadete" per pre-en_camino spec.
      expect(find.text('Cadete asignado'), findsOneWidget);
      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('Reasignar cadete'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'assign action is hidden once the order is en_camino (no reassignment)',
    (tester) async {
      final repository = FakeOrdersRepository(
        seed: [buildTestOrder(id: 'order-1', status: OrderStatus.enCamino)],
      );
      addTearDown(repository.dispose);
      final cadeteDirectory = FakeCadeteDirectory(
        cadetes: const [CadeteProfile(id: 'cadete-1', fullName: 'Juan Pérez')],
      );

      await pumpApp(
        tester,
        const MaterialApp(home: OrderDetailScreen(orderId: 'order-1')),
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repository),
          cadeteDirectoryProvider.overrideWithValue(cadeteDirectory),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Asignar cadete'), findsNothing);
      expect(find.text('Reasignar cadete'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
