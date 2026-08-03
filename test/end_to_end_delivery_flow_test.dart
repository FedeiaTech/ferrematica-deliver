import 'package:ferrematica_express/features/auth/data/providers.dart';
import 'package:ferrematica_express/features/auth/domain/app_session.dart';
import 'package:ferrematica_express/features/auth/domain/cadete_directory.dart';
import 'package:ferrematica_express/features/delivery/data/providers.dart';
import 'package:ferrematica_express/features/delivery/domain/directions_client.dart';
import 'package:ferrematica_express/features/delivery/domain/geocoding_client.dart';
import 'package:ferrematica_express/features/delivery/domain/location_client.dart';
import 'package:ferrematica_express/features/delivery/domain/route_cache.dart';
import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/orders/presentation/fake_orders_repository.dart';
import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_cadete_directory.dart';
import 'helpers/pump_app.dart';

class _FakeGeocodingClient implements GeocodingClient {
  @override
  Future<GeocodeResult?> geocode(String address) async => null;

  @override
  Future<String?> reverseGeocodeCity(double latitude, double longitude) async => null;
}

class _FakeLocationClient implements LocationClient {
  const _FakeLocationClient();

  @override
  Future<DeviceLocation?> getCurrentLocation() async =>
      const DeviceLocation(latitude: -34.61, longitude: -58.38);

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<void> openLocationSettings() async {}

  @override
  Stream<DeviceLocation> watchPosition() =>
      Stream.value(const DeviceLocation(latitude: -34.61, longitude: -58.38));
}

class _FakeDirectionsClient implements DirectionsClient {
  const _FakeDirectionsClient();

  @override
  Future<RouteResult?> route({required LatLng from, required LatLng to}) async =>
      const RouteResult(
        polylinePoints: [LatLng(latitude: -34.61, longitude: -58.38)],
        distanceMeters: 1500,
        durationSeconds: 300,
      );
}

class _FakeRouteCache implements RouteCache {
  final Map<String, CachedRoute> _routes = {};

  @override
  Future<CachedRoute?> read(String orderId) async => _routes[orderId];

  @override
  Future<void> write(String orderId, CachedRoute route) async {
    _routes[orderId] = route;
  }
}

/// End-to-end widget-test smoke coverage for the full `navegacion-cadete`
/// change (PR8): exercises the entire dueño-\>cadete happy path through one
/// shared [FakeOrdersRepository] and a single [FakeAuthRepository] whose
/// session is swapped mid-test (dueño -\> cadete), using the **real**
/// `FerrematicaApp`/`goRouterProvider` so the router's role-gating (PR4) is
/// exercised too, not just each screen in isolation.
///
/// This does not replace the narrower unit/widget tests from PR1-PR7 — it
/// only proves the pieces still connect end to end once assembled: dueño
/// creates an order, assigns a cadete, the cadete sees it, starts
/// navigation (asignado -\> en_camino), and marks it delivered
/// (en_camino -\> entregado).
void main() {
  testWidgets(
    'dueño creates an order, assigns a cadete, cadete navigates and delivers it',
    (tester) async {
      final repository = FakeOrdersRepository();
      addTearDown(repository.dispose);
      final cadeteDirectory = FakeCadeteDirectory(
        cadetes: const [CadeteProfile(id: 'cadete-1', fullName: 'Juan Pérez')],
      );
      const ownerId = 'owner-1';
      final authRepository = FakeAuthRepository(
        initialSession: const AppSession(userId: ownerId, rol: UserRole.dueno),
      );
      addTearDown(authRepository.dispose);

      await pumpApp(
        tester,
        const FerrematicaApp(),
        authRepository: authRepository,
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repository),
          cadeteDirectoryProvider.overrideWithValue(cadeteDirectory),
          geocodingClientProvider.overrideWithValue(_FakeGeocodingClient()),
          locationClientProvider.overrideWithValue(const _FakeLocationClient()),
          directionsClientProvider.overrideWithValue(const _FakeDirectionsClient()),
          routeCacheProvider.overrideWithValue(_FakeRouteCache()),
        ],
      );
      await tester.pumpAndSettle();

      // --- Dueño: create the order -------------------------------------
      expect(find.text('Todos'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Calle Falsa 123');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      final createdOrder = (await repository.pendingSync()).single;
      // New orders auto-assign to the dueño themselves ("Base") — no
      // cadete accounts exist by default — landing on `asignado`, not
      // `en_camino`, so the dueño can still hand it off to a real cadete
      // before heading out.
      expect(createdOrder.status, OrderStatus.asignado);
      expect(createdOrder.assignedCadeteId, ownerId);

      // --- Dueño: reassign to a real cadete ------------------------------
      await tester.tap(find.text(createdOrder.deliveryAddress));
      await tester.pumpAndSettle();

      expect(find.text('Reasignar cadete'), findsOneWidget);
      await tester.tap(find.text('Reasignar cadete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juan Pérez'));
      await tester.pumpAndSettle();

      final assignedOrder = await repository.getById(createdOrder.id);
      expect(assignedOrder!.status, OrderStatus.asignado);
      expect(assignedOrder.assignedCadeteId, 'cadete-1');

      // --- Switch session to the assigned cadete -------------------------
      authRepository.setSession(
        const AppSession(userId: 'cadete-1', rol: UserRole.cadete),
      );
      await tester.pumpAndSettle();

      expect(find.text(createdOrder.deliveryAddress), findsOneWidget);

      // --- Cadete: open the order, start navigation -----------------------
      await tester.tap(find.text(createdOrder.deliveryAddress));
      await tester.pumpAndSettle();

      // Cadete mode never shows dueño-only actions, even on the exact same
      // reused OrderDetailScreen widget (PR4).
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Asignar cadete'), findsNothing);

      expect(find.text('Iniciar navegación'), findsOneWidget);
      await tester.tap(find.text('Iniciar navegación'));
      await tester.pumpAndSettle();

      final enCaminoOrder = await repository.getById(createdOrder.id);
      expect(enCaminoOrder!.status, OrderStatus.enCamino);
      // Lands on the navigation map screen (destination has no coordinates
      // here since geocoding was faked to null — the degraded
      // "sin coordenadas" state is itself proof the null-coordinate path
      // from a not-yet-geocoded order never crashes the map screen).
      expect(find.text('Navegación'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // --- Cadete: back to the detail screen, mark delivered --------------
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Ver ruta'), findsOneWidget);
      expect(find.text('Marcar entrega'), findsOneWidget);
      await tester.tap(find.text('Marcar entrega'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cobrado'));
      await tester.pumpAndSettle();

      final deliveredOrder = await repository.getById(createdOrder.id);
      expect(deliveredOrder!.status, OrderStatus.entregado);
      expect(tester.takeException(), isNull);
    },
  );
}
