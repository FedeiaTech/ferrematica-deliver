import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as latlong;

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
///
/// Map rendering uses `flutter_map` with raster tiles from
/// `tile.openstreetmap.org` (no API key, no billing card — see
/// `HttpGeocodingClient`/`HttpDirectionsClient` for the same rationale on
/// the geocoding/directions side).
class NavigationMapScreen extends ConsumerWidget {
  const NavigationMapScreen({required this.orderId, this.mapBuilder, super.key});

  final String orderId;

  /// Test seam (design's testing strategy — mirrors the previous
  /// `GoogleMap` platform-view seam, but `flutter_map`'s `FlutterMap` is a
  /// plain widget, not a platform view; the seam is kept anyway so widget
  /// tests never issue real tile-network requests). `null` (the production
  /// default) builds the real [FlutterMap]; widget tests substitute a plain
  /// placeholder so they never touch real tiles, and instead assert on the
  /// surrounding loading/error/data state.
  @visibleForTesting
  final Widget Function({
    required latlong.LatLng initialCenter,
    required List<Marker> markers,
    required List<Polyline> polylines,
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
    required latlong.LatLng initialCenter,
    required List<Marker> markers,
    required List<Polyline> polylines,
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

    final destination = latlong.LatLng(order.latitude!, order.longitude!);
    final destinationMarker = Marker(
      point: destination,
      width: 40,
      height: 40,
      alignment: Alignment.topCenter,
      child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
    );

    return routeAsync.when(
      data: (data) {
        final markers = <Marker>[destinationMarker];
        final polylines = <Polyline>[];
        if (data.currentLocation != null) {
          markers.add(
            Marker(
              point: latlong.LatLng(
                data.currentLocation!.latitude,
                data.currentLocation!.longitude,
              ),
              width: 30,
              height: 30,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          );
        }
        if (data.route != null) {
          polylines.add(
            Polyline(
              points: data.route!.polylinePoints
                  .map((point) => latlong.LatLng(point.latitude, point.longitude))
                  .toList(growable: false),
              strokeWidth: 4,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        return Stack(
          children: [
            (mapBuilder ?? _buildFlutterMap)(
              initialCenter: data.currentLocation != null
                  ? latlong.LatLng(
                      data.currentLocation!.latitude,
                      data.currentLocation!.longitude,
                    )
                  : destination,
              markers: markers,
              polylines: polylines,
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data.isFromCache) ...[
                    const _OfflineRouteBanner(),
                    const SizedBox(height: 8),
                  ],
                  _RouteInfoCard(route: data.route),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => Stack(
        children: [
          (mapBuilder ?? _buildFlutterMap)(
            initialCenter: destination,
            markers: [destinationMarker],
            polylines: const <Polyline>[],
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
          (mapBuilder ?? _buildFlutterMap)(
            initialCenter: destination,
            markers: [destinationMarker],
            polylines: const <Polyline>[],
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

  Widget _buildFlutterMap({
    required latlong.LatLng initialCenter,
    required List<Marker> markers,
    required List<Polyline> polylines,
  }) {
    return FlutterMap(
      options: MapOptions(initialCenter: initialCenter, initialZoom: 14),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ferrematica.express',
        ),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
        // Required by OpenStreetMap's tile usage policy — see
        // https://operations.osmfoundation.org/policies/tiles/.
        RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
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

/// Shown above [_RouteInfoCard] when [NavigationRouteData.isFromCache] is
/// `true` (spec's "Offline route fallback"): the route being displayed is
/// the last-known one, not a freshly re-fetched route — read-only, no live
/// re-routing is attempted while this banner is visible.
class _OfflineRouteBanner extends StatelessWidget {
  const _OfflineRouteBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sin conexión, mostrando última ruta conocida',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
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
