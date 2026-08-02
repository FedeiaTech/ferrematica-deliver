import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import '../../../orders/domain/order.dart';
import '../../../orders/presentation/providers.dart' show orderByIdProvider;
import '../../domain/directions_client.dart' show RouteResult;
import '../providers.dart';

/// Cadete-facing navigation screen (spec's `cadete-navigation` domain):
/// shows a map with a destination pin at the order's `latitude`/
/// `longitude`, a route polyline from the cadete's current location
/// (fetched from the Directions API via [navigationRouteProvider]), and
/// basic distance/ETA text.
///
/// Reachable two ways from [OrderDetailScreen]'s `readOnlyForCadete` mode:
/// "Iniciar navegación" (order is `asignado` — triggers
/// `OrdersController.startDelivery` first, then navigates here) and "Ver
/// ruta" (order is already `en_camino` — navigates here directly, no status
/// transition). Either way this screen itself never triggers a status
/// change; it only reads the order and renders the route.
///
/// Never crashes on a missing/unresolvable route (testing strategy: "a map
/// that can't fetch a route should show a clear degraded state ... not
/// crash") — a `null` destination coordinate, a denied location permission,
/// and a failed Directions request are all rendered as an explicit message
/// instead of an exception.
class NavigationMapScreen extends ConsumerWidget {
  const NavigationMapScreen({required this.orderId, this.mapBuilder, super.key});

  final String orderId;

  /// Test seam (design's testing strategy: "`GoogleMap` is a platform view
  /// and is untestable in the widget harness ... assert around it"). `null`
  /// (the production default) builds the real [gmaps.GoogleMap]; widget
  /// tests substitute a plain placeholder so they never touch a platform
  /// view, and instead assert on the surrounding loading/error/data state.
  @visibleForTesting
  final Widget Function({
    required gmaps.CameraPosition initialCameraPosition,
    required Set<gmaps.Marker> markers,
    required Set<gmaps.Polyline> polylines,
  })?
  mapBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Navegación')),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Pedido no encontrado.'));
          }
          if (order.latitude == null || order.longitude == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Sin coordenadas, geocodificación pendiente.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _NavigationMapBody(order: order, mapBuilder: mapBuilder);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error al cargar el pedido: $error')),
      ),
    );
  }
}

class _NavigationMapBody extends ConsumerWidget {
  const _NavigationMapBody({required this.order, required this.mapBuilder});

  final Order order;
  final Widget Function({
    required gmaps.CameraPosition initialCameraPosition,
    required Set<gmaps.Marker> markers,
    required Set<gmaps.Polyline> polylines,
  })?
  mapBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = NavigationTarget(
      orderId: order.id,
      latitude: order.latitude!,
      longitude: order.longitude!,
    );
    final routeAsync = ref.watch(navigationRouteProvider(target));

    final destination = gmaps.LatLng(order.latitude!, order.longitude!);
    final destinationMarker = gmaps.Marker(
      markerId: const gmaps.MarkerId('destination'),
      position: destination,
      infoWindow: const gmaps.InfoWindow(title: 'Destino'),
    );

    return routeAsync.when(
      data: (data) {
        final markers = <gmaps.Marker>{destinationMarker};
        final polylines = <gmaps.Polyline>{};
        if (data.currentLocation != null) {
          markers.add(
            gmaps.Marker(
              markerId: const gmaps.MarkerId('current-location'),
              position: gmaps.LatLng(
                data.currentLocation!.latitude,
                data.currentLocation!.longitude,
              ),
              icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                gmaps.BitmapDescriptor.hueAzure,
              ),
              infoWindow: const gmaps.InfoWindow(title: 'Tu ubicación'),
            ),
          );
        }
        if (data.route != null) {
          polylines.add(
            gmaps.Polyline(
              polylineId: const gmaps.PolylineId('route'),
              points: data.route!.polylinePoints
                  .map((point) => gmaps.LatLng(point.latitude, point.longitude))
                  .toList(growable: false),
              width: 4,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        return Stack(
          children: [
            (mapBuilder ?? _buildGoogleMap)(
              initialCameraPosition: gmaps.CameraPosition(
                target: data.currentLocation != null
                    ? gmaps.LatLng(
                        data.currentLocation!.latitude,
                        data.currentLocation!.longitude,
                      )
                    : destination,
                zoom: 14,
              ),
              markers: markers,
              polylines: polylines,
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _RouteInfoCard(route: data.route),
            ),
          ],
        );
      },
      loading: () => Stack(
        children: [
          (mapBuilder ?? _buildGoogleMap)(
            initialCameraPosition: gmaps.CameraPosition(target: destination, zoom: 14),
            markers: {destinationMarker},
            polylines: const <gmaps.Polyline>{},
          ),
          const Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Text('Calculando ruta…')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      error: (error, _) => Stack(
        children: [
          (mapBuilder ?? _buildGoogleMap)(
            initialCameraPosition: gmaps.CameraPosition(target: destination, zoom: 14),
            markers: {destinationMarker},
            polylines: const <gmaps.Polyline>{},
          ),
          const Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _RouteErrorCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleMap({
    required gmaps.CameraPosition initialCameraPosition,
    required Set<gmaps.Marker> markers,
    required Set<gmaps.Polyline> polylines,
  }) {
    return gmaps.GoogleMap(
      initialCameraPosition: initialCameraPosition,
      markers: markers,
      polylines: polylines,
      myLocationButtonEnabled: false,
    );
  }
}

class _RouteInfoCard extends StatelessWidget {
  const _RouteInfoCard({required this.route});

  final RouteResult? route;

  @override
  Widget build(BuildContext context) {
    final route = this.route;
    if (route == null) {
      return const _RouteErrorCard();
    }
    final distanceKm = route.distanceMeters / 1000;
    final durationMinutes = (route.durationSeconds / 60).ceil();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${distanceKm.toStringAsFixed(1)} km'),
            Text('$durationMinutes min'),
          ],
        ),
      ),
    );
  }
}

class _RouteErrorCard extends StatelessWidget {
  const _RouteErrorCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No se pudo calcular la ruta.',
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
