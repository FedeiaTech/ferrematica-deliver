import 'package:ferrematica_express/features/delivery/data/providers.dart';
import 'package:ferrematica_express/features/delivery/domain/directions_client.dart';
import 'package:ferrematica_express/features/delivery/domain/location_client.dart';
import 'package:ferrematica_express/features/delivery/presentation/screens/navigation_map_screen.dart';
import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pump_app.dart';
import '../../orders/presentation/fake_orders_repository.dart';

/// Widget-level smoke coverage for [NavigationMapScreen], per design's
/// testing strategy: "Do not mock Google Maps rendering — GoogleMap is a
/// platform view and is untestable in the widget harness. Assert around
/// it: inject a fake DirectionsClient + ... and verify the surrounding
/// widgets." [NavigationMapScreen.mapBuilder] is the test seam that
/// replaces the real `GoogleMap` platform view with a plain placeholder, so
/// these tests only assert on the loading/error/data states around it, not
/// on any map rendering.
void main() {
  Widget withRouter(Widget home) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (context, state) => home)],
    );
    return MaterialApp.router(routerConfig: router);
  }

  Order orderWithCoordinates({
    String id = 'order-1',
    OrderStatus status = OrderStatus.enCamino,
  }) {
    final now = DateTime(2026, 1, 1);
    return Order(
      id: id,
      deliveryAddress: 'Av. Siempre Viva 742',
      createdBy: 'owner-1',
      createdAt: now,
      updatedAt: now,
      status: status,
      assignedCadeteId: 'cadete-1',
      latitude: -34.6037,
      longitude: -58.3816,
    );
  }

  testWidgets('shows a pending-geocoding message when the order has no coordinates', (
    tester,
  ) async {
    final repository = FakeOrdersRepository(seed: [buildTestOrder(id: 'order-1')]);
    addTearDown(repository.dispose);

    await pumpApp(
      tester,
      withRouter(
        NavigationMapScreen(
          orderId: 'order-1',
          mapBuilder: ({required initialCameraPosition, required markers, required polylines}) =>
              const SizedBox.shrink(),
        ),
      ),
      overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin coordenadas, geocodificación pendiente.'), findsOneWidget);
  });

  testWidgets('shows distance and ETA when the route resolves', (tester) async {
    final repository = FakeOrdersRepository(seed: [orderWithCoordinates()]);
    addTearDown(repository.dispose);

    var mapBuilderCalls = 0;
    await pumpApp(
      tester,
      withRouter(
        NavigationMapScreen(
          orderId: 'order-1',
          mapBuilder: ({required initialCameraPosition, required markers, required polylines}) {
            mapBuilderCalls++;
            return SizedBox(key: Key('fake-map-${markers.length}-${polylines.length}'));
          },
        ),
      ),
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repository),
        locationClientProvider.overrideWithValue(
          const _FakeLocationClient(
            DeviceLocation(latitude: -34.61, longitude: -58.38),
          ),
        ),
        directionsClientProvider.overrideWithValue(
          _FakeDirectionsClient(
            const RouteResult(
              polylinePoints: [LatLng(latitude: -34.61, longitude: -58.38)],
              distanceMeters: 2500,
              durationSeconds: 420,
            ),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('2.5 km'), findsOneWidget);
    expect(find.text('7 min'), findsOneWidget);
    expect(mapBuilderCalls, greaterThan(0));
    // Destination + current-location markers, no polyline missing.
    expect(find.byKey(const Key('fake-map-2-1')), findsOneWidget);
  });

  testWidgets(
    'shows a degraded "no se pudo calcular la ruta" state when the Directions API fails',
    (tester) async {
      final repository = FakeOrdersRepository(seed: [orderWithCoordinates()]);
      addTearDown(repository.dispose);

      await pumpApp(
        tester,
        withRouter(
          NavigationMapScreen(
            orderId: 'order-1',
            mapBuilder:
                ({required initialCameraPosition, required markers, required polylines}) =>
                    const SizedBox.shrink(),
          ),
        ),
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repository),
          locationClientProvider.overrideWithValue(
            const _FakeLocationClient(
              DeviceLocation(latitude: -34.61, longitude: -58.38),
            ),
          ),
          directionsClientProvider.overrideWithValue(const _FakeDirectionsClient(null)),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('No se pudo calcular la ruta.'), findsOneWidget);
    },
  );

  testWidgets(
    'shows a degraded state (destination marker only) when location permission is denied',
    (tester) async {
      final repository = FakeOrdersRepository(seed: [orderWithCoordinates()]);
      addTearDown(repository.dispose);

      await pumpApp(
        tester,
        withRouter(
          NavigationMapScreen(
            orderId: 'order-1',
            mapBuilder:
                ({required initialCameraPosition, required markers, required polylines}) =>
                    SizedBox(key: Key('fake-map-${markers.length}')),
          ),
        ),
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repository),
          locationClientProvider.overrideWithValue(const _FakeLocationClient(null)),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('No se pudo calcular la ruta.'), findsOneWidget);
      // Only the destination marker — no current-location marker without a
      // resolved device position.
      expect(find.byKey(const Key('fake-map-1')), findsOneWidget);
    },
  );

  testWidgets('shows a loading indicator while the route is being calculated', (tester) async {
    final repository = FakeOrdersRepository(seed: [orderWithCoordinates()]);
    addTearDown(repository.dispose);

    await pumpApp(
      tester,
      withRouter(
        NavigationMapScreen(
          orderId: 'order-1',
          mapBuilder: ({required initialCameraPosition, required markers, required polylines}) =>
              const SizedBox.shrink(),
        ),
      ),
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repository),
        locationClientProvider.overrideWithValue(
          const _FakeLocationClient(
            DeviceLocation(latitude: -34.61, longitude: -58.38),
            delay: Duration(milliseconds: 200),
          ),
        ),
      ],
    );
    // Single pump: the order is already loaded, but navigationRouteProvider
    // hasn't resolved yet — the "Calculando ruta…" state should be visible.
    await tester.pump();

    expect(find.text('Calculando ruta…'), findsOneWidget);

    // Flush the fake location client's delayed future so no timer is left
    // pending when the widget tree is torn down.
    await tester.pump(const Duration(milliseconds: 200));
  });
}

class _FakeLocationClient implements LocationClient {
  const _FakeLocationClient(this.location, {this.delay = Duration.zero});

  final DeviceLocation? location;
  final Duration delay;

  @override
  Future<DeviceLocation?> getCurrentLocation() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return location;
  }
}

class _FakeDirectionsClient implements DirectionsClient {
  const _FakeDirectionsClient(this.result);

  final RouteResult? result;

  @override
  Future<RouteResult?> route({required LatLng from, required LatLng to}) async => result;
}
