import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:latlong2/latlong.dart' as latlong;

import '../../../orders/domain/order.dart';
import '../../../orders/presentation/providers.dart' show orderByIdProvider;
import '../../data/providers.dart' show locationClientProvider;
import '../../domain/directions_client.dart' show RouteResult;
import '../../domain/location_client.dart' show DeviceLocation;
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

class _NavigationMapBody extends ConsumerStatefulWidget {
  const _NavigationMapBody({required this.order, required this.mapBuilder});

  final Order order;
  final Widget Function({
    required latlong.LatLng initialCenter,
    required List<Marker> markers,
    required List<Polyline> polylines,
  })?
  mapBuilder;

  @override
  ConsumerState<_NavigationMapBody> createState() => _NavigationMapBodyState();
}

class _NavigationMapBodyState extends ConsumerState<_NavigationMapBody> {
  final MapController _mapController = MapController();

  /// `true` (default) = the map rotates live so the destination always
  /// points up — "which way to go" is the direction of travel, so this
  /// stays correct without needing a device compass or a reliable GPS
  /// course-over-ground reading (both of which are noisy at walking
  /// speed). `false` = north always up, static.
  bool _headingUp = true;

  /// `true` (default, Uber-style) = the map keeps re-centering on the
  /// live position as it updates. Set to `false` the moment the cadete
  /// drags/pinches the map themselves (`onPositionChanged`'s `hasGesture`
  /// flag — distinguishes a real touch gesture from our own programmatic
  /// `_mapController.move` calls, which also fire this callback but with
  /// `hasGesture: false`), so exploring the map doesn't fight the camera.
  bool _followMe = true;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _toggleHeadingUp(DeviceLocation? currentLocation) {
    setState(() => _headingUp = !_headingUp);
    if (!_headingUp) {
      // Snap back to north-up immediately.
      try {
        _mapController.rotate(0);
      } catch (_) {
        // Map not attached yet.
      }
      return;
    }
    // Apply the destination-up rotation right away using the last known
    // position, rather than waiting for the next live GPS update — the
    // stream only emits on ~5m of movement (`distanceFilter`), so toggling
    // this back on while stationary previously did nothing until the
    // cadete moved.
    if (currentLocation != null) _rotateToDestination(currentLocation);
  }

  void _rotateToDestination(DeviceLocation location) {
    // Bearing from the live position straight to the destination — always
    // meaningful (unlike a movement- or compass-derived heading, which is
    // noisy or simply unavailable at walking speed) and it's exactly what
    // "which way do I go" means for a delivery: up = toward the order.
    final rawBearing = Geolocator.bearingBetween(
      location.latitude,
      location.longitude,
      widget.order.latitude!,
      widget.order.longitude!,
    );
    final heading = (rawBearing + 360) % 360;
    try {
      _mapController.rotate(-heading);
    } catch (_) {
      // Map not attached yet.
    }
  }

  void _recenter(DeviceLocation? location) {
    if (location == null) return;
    try {
      _mapController.move(
        latlong.LatLng(location.latitude, location.longitude),
        _mapController.camera.zoom,
      );
    } catch (_) {
      // FlutterMap not attached yet (or the test seam swapped it out for
      // a plain placeholder) — nothing to move.
    }
    setState(() => _followMe = true);
  }

  void _onLivePosition(DeviceLocation location) {
    if (_headingUp) _rotateToDestination(location);
    if (_followMe) {
      try {
        _mapController.move(
          latlong.LatLng(location.latitude, location.longitude),
          _mapController.camera.zoom,
        );
      } catch (_) {
        // FlutterMap not attached yet (or the test seam swapped it out for
        // a plain placeholder) — the next live position after the map
        // actually renders will catch up.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final mapBuilder = widget.mapBuilder;
    final target = NavigationTarget(
      orderId: order.id,
      latitude: order.latitude!,
      longitude: order.longitude!,
    );
    final routeAsync = ref.watch(navigationRouteProvider(target));
    final serviceEnabledAsync = ref.watch(locationServiceEnabledProvider);
    final gpsDisabled = serviceEnabledAsync.value == false;

    // Live position takes over from navigationRouteProvider's one-shot fix
    // as soon as the stream produces its first update — that one-shot fix
    // only exists to key the single Directions request, not to track
    // movement.
    final liveLocation = ref.watch(livePositionProvider).value;

    // Drives rotation + follow-camera on every new live position.
    // `ref.listen` (not a direct call in `build`) is the safe way to
    // trigger this imperative side effect from a provider change — it
    // runs after the frame, never mid-build.
    ref.listen<AsyncValue<DeviceLocation>>(livePositionProvider, (previous, next) {
      final location = next.value;
      if (location == null) return;
      _onLivePosition(location);
    });

    final destination = latlong.LatLng(order.latitude!, order.longitude!);
    final destinationMarker = Marker(
      point: destination,
      width: 40,
      height: 40,
      alignment: Alignment.topCenter,
      rotate: true, // stays upright regardless of map rotation
      child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
    );

    return Stack(
      children: [
        routeAsync.when(
          data: (data) {
            final currentLocation = liveLocation ?? data.currentLocation;
            final markers = <Marker>[destinationMarker];
            if (currentLocation != null) {
              markers.add(
                Marker(
                  point: latlong.LatLng(currentLocation.latitude, currentLocation.longitude),
                  width: 30,
                  height: 30,
                  rotate: true,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
              );
            }
            final polylines = <Polyline>[];
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
                  initialCenter: currentLocation != null
                      ? latlong.LatLng(currentLocation.latitude, currentLocation.longitude)
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
              const Positioned(left: 12, right: 12, bottom: 12, child: _RouteErrorCard()),
            ],
          ),
        ),
        if (order.notes != null || gpsDisabled)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (order.notes != null) ...[
                  _NotesBanner(notes: order.notes!),
                  if (gpsDisabled) const SizedBox(height: 8),
                ],
                if (gpsDisabled)
                  _GpsDisabledBanner(
                    onEnable: () async {
                      await ref.read(locationClientProvider).openLocationSettings();
                      ref.invalidate(locationServiceEnabledProvider);
                      ref.invalidate(navigationRouteProvider(target));
                    },
                  ),
              ],
            ),
          ),
        // View-mode toggle: north-up (static) vs. heading-up (rotates
        // live with direction of travel, default). Independent of the
        // recenter button below — you can explore the map in either
        // rotation mode. Only meaningful once the map is actually
        // rendered, so this sits outside the routeAsync branches rather
        // than duplicated into loading/error/data.
        Positioned(
          top: 12,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'nav-view-toggle',
            onPressed: () => _toggleHeadingUp(liveLocation),
            tooltip: _headingUp
                ? 'Cambiar a vista norte arriba'
                : 'Cambiar a vista destino arriba',
            child: Icon(_headingUp ? Icons.explore : Icons.navigation),
          ),
        ),
        // Recenter (Uber-style): only appears once the cadete has panned
        // the map away from the live position, via onPositionChanged's
        // `hasGesture` flag in _buildFlutterMap. Tapping it snaps back and
        // resumes auto-following.
        if (!_followMe)
          Positioned(
            top: 68,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'nav-recenter',
              onPressed: () => _recenter(liveLocation),
              tooltip: 'Centrar en mi ubicación',
              child: const Icon(Icons.my_location),
            ),
          ),
      ],
    );
  }

  Widget _buildFlutterMap({
    required latlong.LatLng initialCenter,
    required List<Marker> markers,
    required List<Polyline> polylines,
  }) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        // Close enough to read street names clearly (roughly a 5-block
        // radius), per the dueño's feedback that the previous default
        // (14→16) was too zoomed out for that.
        initialZoom: 17,
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture && _followMe) setState(() => _followMe = false);
        },
      ),
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

/// Shown at the top of the map when the order has [Order.notes] — delivery
/// instructions like "rejas negras" (black gate) need to stay visible to
/// the cadete while they're actively navigating, not buried one tap away
/// in the order detail screen they already left behind.
class _NotesBanner extends StatelessWidget {
  const _NotesBanner({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.sticky_note_2_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                notes,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown at the top of the map when [locationServiceEnabledProvider]
/// resolves `false` — the device's GPS is off, so [LocationClient
/// .getCurrentLocation] will keep returning `null` no matter how many
/// times the route is retried. Rather than only degrading silently to a
/// destination-only view, this proactively offers to open the platform's
/// location-settings screen (`onEnable`), and the caller re-checks both
/// the service status and the route once the user returns.
class _GpsDisabledBanner extends StatelessWidget {
  const _GpsDisabledBanner({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'La ubicación (GPS) está apagada',
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onEnable, child: const Text('Activar')),
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
