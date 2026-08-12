import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/data/venta_disponible.dart';
import 'package:ferrematica_express/features/orders/data/ventas_remote.dart';
import 'package:ferrematica_express/features/orders/presentation/screens/order_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pump_app.dart';
import 'fake_orders_repository.dart';

/// In-memory [VentasRemote] double for the "desde venta" prefill flow
/// (spec domain `order-prefill-from-venta`), mirroring
/// [FakeOrdersRepository]'s role for the `orders` feature.
class _FakeVentasRemote implements VentasRemote {
  _FakeVentasRemote({this.disponibles = const <VentaDisponible>[], this.claimError});

  final List<VentaDisponible> disponibles;

  /// When set, [claimVenta] throws this instead of recording the claim —
  /// simulates losing the race against another device (D4).
  final Exception? claimError;

  final List<String> claimedVentaIds = <String>[];

  @override
  Future<List<VentaDisponible>> fetchDisponibles({int dias = 7}) async => disponibles;

  @override
  Future<void> claimVenta({
    required String ventaId,
    required String orderId,
    required String createdBy,
  }) async {
    if (claimError != null) throw claimError!;
    claimedVentaIds.add(ventaId);
  }

  @override
  Future<List<LinkedVenta>> fetchLinkedVentas(String orderId) async => const [];

  @override
  Future<List<VentaDetalleDisponible>> fetchDetalleVenta({
    required String installId,
    required int ventaLocalId,
  }) async => const [];
}

VentaDisponible _buildVenta({
  String id = 'venta-1',
  int ventaLocalId = 1,
  double total = 250.0,
  String descripcion = 'Cable 2x1,5',
}) => VentaDisponible(
  id: id,
  ventaLocalId: ventaLocalId,
  fecha: DateTime(2026, 8, 1, 10),
  total: total,
  estado: 'completada',
  detalles: [
    VentaDetalleDisponible(
      productoCodigo: 'P1',
      descripcion: descripcion,
      cantidad: 3,
      precioUnitario: total / 3,
      subtotal: total,
    ),
  ],
);

/// [OrderFormScreen] reads `go_router`'s context extensions (`canPop`/`pop`)
/// on submit, so it needs a real [GoRouter] ancestor even in isolation —
/// same helper as `order_form_screen_test.dart`.
Widget _withRouter() {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (context, state) => const OrderFormScreen())],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets(
    'selecting a venta prefills the form; confirming claims it and creates the order',
    (tester) async {
      final repository = FakeOrdersRepository();
      addTearDown(repository.dispose);
      final ventasRemote = _FakeVentasRemote(disponibles: [_buildVenta()]);

      await pumpApp(
        tester,
        _withRouter(),
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repository),
          ventasRemoteProvider.overrideWithValue(ventasRemote),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Calle Falsa 123');
      await tester.pump();

      await tester.tap(find.text('Usar venta del POS'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Venta #1'), findsOneWidget);
      await tester.tap(find.textContaining('Venta #1'));
      await tester.pumpAndSettle();

      // Prefilled from the venta — the "Productos" section shows the
      // mapped item and the venta's date/time (no quantity number: it's
      // locked, not a control). The amount field (inside the collapsed
      // "Datos opcionales" section) is asserted below via the saved order,
      // since it's off-screen until that section is expanded.
      expect(find.text('Cable 2x1,5'), findsOneWidget);
      expect(find.textContaining('01/08'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      // The claim happens on confirm, not on selection (D4) — proven here
      // by it having happened at all only after the "Guardar" tap above.
      expect(ventasRemote.claimedVentaIds, ['venta-1']);
      final createdOrder = (await repository.pendingSync()).single;
      expect(createdOrder.items.single.productName, 'Cable 2x1,5');
      expect(createdOrder.items.single.quantity, 3);
      expect(createdOrder.amountToCharge, 250.0);
      // Spec: no client/destinatario field is prefilled from the venta.
      expect(createdOrder.clientName, isNull);
    },
  );

  testWidgets(
    'a claim rejected by a race shows the conflict message and creates no order',
    (tester) async {
      final repository = FakeOrdersRepository();
      addTearDown(repository.dispose);
      final ventasRemote = _FakeVentasRemote(
        disponibles: [_buildVenta()],
        claimError: const VentaYaVinculadaException('venta-1'),
      );

      await pumpApp(
        tester,
        _withRouter(),
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repository),
          ventasRemoteProvider.overrideWithValue(ventasRemote),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Calle Falsa 123');
      await tester.pump();

      await tester.tap(find.text('Usar venta del POS'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Venta #1'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Esa venta ya fue usada en otro pedido'), findsOneWidget);
      expect(await repository.pendingSync(), isEmpty);
      expect(ventasRemote.claimedVentaIds, isEmpty);
    },
  );

  testWidgets(
    'picking a second venta appends its items instead of replacing the first, '
    'and claims both on confirm',
    (tester) async {
      final repository = FakeOrdersRepository();
      addTearDown(repository.dispose);
      final ventasRemote = _FakeVentasRemote(
        disponibles: [
          _buildVenta(id: 'venta-1', ventaLocalId: 1, total: 250.0, descripcion: 'Cable 2x1,5'),
          _buildVenta(id: 'venta-2', ventaLocalId: 2, total: 100.0, descripcion: 'Tornillos'),
        ],
      );

      await pumpApp(
        tester,
        _withRouter(),
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repository),
          ventasRemoteProvider.overrideWithValue(ventasRemote),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Calle Falsa 123');
      await tester.pump();

      await tester.tap(find.text('Usar venta del POS'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Venta #1'));
      await tester.pumpAndSettle();

      // First pick's item is still on screen — proves the second pick below
      // appends rather than wiping it out.
      expect(find.text('Cable 2x1,5'), findsOneWidget);

      await tester.tap(find.text('Usar venta del POS'));
      await tester.pumpAndSettle();

      // Venta #1 is no longer offered — already added to this pedido.
      expect(find.textContaining('Venta #1'), findsNothing);
      await tester.tap(find.textContaining('Venta #2'));
      await tester.pumpAndSettle();

      expect(find.text('Cable 2x1,5'), findsOneWidget);
      expect(find.text('Tornillos'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(ventasRemote.claimedVentaIds, ['venta-1', 'venta-2']);
      final createdOrder = (await repository.pendingSync()).single;
      expect(createdOrder.items, hasLength(2));
      expect(createdOrder.amountToCharge, 350.0);
    },
  );

  testWidgets(
    'trash icon on a locked row un-picks the whole venta, not just that line, '
    'and it becomes available again in the picker',
    (tester) async {
      final repository = FakeOrdersRepository();
      addTearDown(repository.dispose);
      final ventasRemote = _FakeVentasRemote(disponibles: [_buildVenta()]);

      await pumpApp(
        tester,
        _withRouter(),
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repository),
          ventasRemoteProvider.overrideWithValue(ventasRemote),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Calle Falsa 123');
      await tester.pump();

      await tester.tap(find.text('Usar venta del POS'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Venta #1'));
      await tester.pumpAndSettle();

      expect(find.text('Cable 2x1,5'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // The item is gone, and the venta is offered again since it's no
      // longer picked.
      expect(find.text('Cable 2x1,5'), findsNothing);
      await tester.tap(find.text('Usar venta del POS'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Venta #1'), findsOneWidget);
    },
  );
}
