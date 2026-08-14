import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:latlong2/latlong.dart' as latlong;

import '../../../orders/domain/order.dart';
import '../../../orders/presentation/providers.dart' show kMotivoVentaAnulada, orderByIdProvider;
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
          if (!order.hasValidCoordinates) {
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
          // The order's ONE linked venta was voided in the POS while this
          // screen was open (`order_detail_screen.dart`'s polling check —
          // `OrdersController.cancelDueToVentaAnulada`) — "cerrar la
          // navegación" per the dueño's own words: no more live route/
          // destination, no way back into a real map from here, and this
          // check re-runs on every rebuild of this screen (order comes
          // from `orderByIdProvider`, itself backed by the same reactive
          // Isar watch the rest of the app uses), so it takes effect while
          // the cadete is mid-trip, not just next time they open the app.
          if (order.status == OrderStatus.cancelado &&
              order.deliveryProblem == kMotivoVentaAnulada) {
            return _NavigationLockedByVentaAnulada();
          }
          return _NavigationMapBody(order: order, mapBuilder: mapBuilder);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error al cargar el pedido: $error')),
      ),
    );
  }
}

/// Replaces the live map entirely once [NavigationMapScreen] detects the
/// order was auto-cancelled because its one linked venta got voided in the
/// POS — gray, no route, no destination, no way to reopen a real map from
/// here (this screen is only ever reached via "Iniciar navegación"/"Ver
/// ruta" on the detail screen, and those buttons are already gone for a
/// cancelado order — see `order_detail_screen.dart`).
class _NavigationLockedByVentaAnulada extends StatelessWidget {
  const _NavigationLockedByVentaAnulada();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade400,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 48, color: Colors.grey.shade700),
            const SizedBox(height: 16),
            Text(
              kMotivoVentaAnulada,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Volver'),
            ),
          ],
        ),
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

class _NavigationMapBodyState extends ConsumerState<_NavigationMapBody>
    with TickerProviderStateMixin {
  /// Wraps a plain [MapController] so every programmatic camera change
  /// (recenter, rotation) glides instead of snapping — flutter_map itself
  /// has no animation of its own. Default duration/curve cover the
  /// deliberate recenter action; continuous live-tracking calls
  /// ([_onLivePosition]) pass their own shorter duration so they don't
  /// lag behind a cadete actually moving. `cancelPreviousAnimations: true`
  /// so a fresh GPS ping interrupts (rather than queues behind) whatever
  /// animation the previous ping started.
  late final AnimatedMapController _animatedMapController = AnimatedMapController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeInOutCubic,
    cancelPreviousAnimations: true,
  );

  MapController get _mapController => _animatedMapController.mapController;

  /// Duration for camera changes driven by a fresh live GPS position —
  /// shorter than the default so continuous tracking feels like gliding
  /// alongside the cadete, not chasing them.
  static const Duration _liveTrackingDuration = Duration(milliseconds: 400);

  /// Zoom [_applyCameraPose] snaps heading-up back to — "roughly a 5-block
  /// radius", per the dueño's own feedback on `_buildFlutterMap`'s matching
  /// `initialZoom`. North-up doesn't use this: it fits the whole route
  /// instead of zooming to a fixed radius.
  static const double _fiveBlockZoom = 17;

  /// Fires 10s after the camera stops following the live position (the
  /// cadete panned/pinched away) and snaps back — "útil para cuando se
  /// maneja y se perdió el centramiento": driving means no free hand to
  /// tap the manual recenter button. Reset on every further pan so an
  /// actively-exploring cadete gets a full 10s of undisturbed looking
  /// before it snaps back, not a countdown from the first touch.
  Timer? _autoRecenterTimer;

  /// North-up mode has no per-GPS-tick camera follow (see [_onLivePosition])
  /// — continuously recentering on just the live position there would fight
  /// the point of that mode, which is a stable overview of the whole route.
  /// Instead this periodically re-applies the fit-to-bounds pose so the
  /// frame stays current as the cadete moves. Runs only while `!_headingUp`
  /// — started/stopped by [_syncNorthUpAutoFitTimer].
  Timer? _northUpAutoFitTimer;

  /// `true` once the first camera pose (position + zoom + rotation for the
  /// default heading-up mode) has been applied after the map first gets a
  /// known location — so the screen opens already framed correctly instead
  /// of waiting for the first recenter trigger.
  bool _initialPoseApplied = false;

  /// Best known position, regardless of source (the route fetch's one-shot
  /// fix, or the live GPS stream) — kept so [_applyCameraPose]'s callers
  /// (button, timers, initial pose) always have somewhere to point the
  /// camera, even before the live stream has emitted anything yet.
  DeviceLocation? _lastKnownLocation;

  /// Last route polyline seen, kept for the same reason as
  /// [_lastKnownLocation]: north-up recenter needs to fit the whole route
  /// in frame, and the button/timer that triggers it fire outside
  /// `build`'s `routeAsync.data` scope. Updated on every build that has
  /// route data; keeps its previous value while loading/erroring so a
  /// recenter mid-retry still frames the last route we actually had.
  List<latlong.LatLng> _lastKnownRoutePoints = const [];

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
    _autoRecenterTimer?.cancel();
    _northUpAutoFitTimer?.cancel();
    _animatedMapController.dispose();
    super.dispose();
  }

  void _scheduleAutoRecenter() {
    _autoRecenterTimer?.cancel();
    _autoRecenterTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || _followMe) return;
      _recenter(_lastKnownLocation);
    });
  }

  /// Starts/stops [_northUpAutoFitTimer] to match the current mode — call
  /// after every `_headingUp` change (just [_toggleHeadingUp] today).
  void _syncNorthUpAutoFitTimer() {
    _northUpAutoFitTimer?.cancel();
    _northUpAutoFitTimer = null;
    if (_headingUp) return;
    _northUpAutoFitTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      _applyCameraPose(_lastKnownLocation);
    });
  }

  double _bearingToDestination(DeviceLocation location) {
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
    return (rawBearing + 360) % 360;
  }

  /// The single place that decides what the camera should look like for the
  /// current mode, and animates it there in one fluid motion — shared by
  /// the initial pose (once a location is first known), the view-mode
  /// toggle button, the 10s "lost centering" auto-recenter, the manual
  /// recenter button, and the north-up 20s ambient re-fit. Every trigger
  /// funnels through here so none of them can drift out of sync with the
  /// others (e.g. one applying the 5-block zoom and another forgetting it).
  ///
  /// Heading-up ("camino a norte"): centers on [location], rotates so the
  /// destination points up, and zooms to [_fiveBlockZoom] — like a
  /// turn-by-turn navigator's locked view.
  ///
  /// North-up: rotates to true north (0°) and fits the camera to frame the
  /// live position, the destination, and the whole route polyline — an
  /// overview of the trip, not a fixed zoom around one point.
  void _applyCameraPose(DeviceLocation? location) {
    if (location == null) return;
    final currentPoint = latlong.LatLng(location.latitude, location.longitude);
    try {
      if (_headingUp) {
        _animatedMapController.animateTo(
          dest: currentPoint,
          zoom: _fiveBlockZoom,
          rotation: -_bearingToDestination(location),
        );
      } else {
        final destination = latlong.LatLng(
          widget.order.latitude!,
          widget.order.longitude!,
        );
        final framePoints = <latlong.LatLng>{
          currentPoint,
          destination,
          ..._lastKnownRoutePoints,
        }.toList(growable: false);
        if (framePoints.length < 2) {
          _animatedMapController.animateTo(dest: currentPoint, rotation: 0);
        } else {
          _animatedMapController.animatedFitCamera(
            // `CameraFit.coordinates` defaults `maxZoom` to
            // `double.infinity` — if `framePoints` ever project to a
            // degenerate (zero-width or zero-height) bounding box (e.g.
            // the live position and destination coincide almost exactly,
            // a real case right before arrival), its internal zoom
            // calculation divides by that zero size and produces
            // `Infinity`, which then crashes `TileLayer` on the next
            // build (`Infinity.floor()`, `Unsupported operation`) — not
            // caught by this method's own try/catch, since that failure
            // happens on a LATER frame, not synchronously here. Capping
            // `maxZoom` here (matching `_fiveBlockZoom`'s intent) makes
            // that impossible regardless of how degenerate the points are.
            cameraFit: CameraFit.coordinates(
              coordinates: framePoints,
              padding: const EdgeInsets.all(48),
              maxZoom: _fiveBlockZoom,
            ),
            rotation: 0,
          );
        }
      }
    } catch (_) {
      // FlutterMap not attached yet (or the test seam swapped it out for
      // a plain placeholder) — nothing to move.
    }
  }

  void _toggleHeadingUp() {
    _autoRecenterTimer?.cancel();
    setState(() {
      _headingUp = !_headingUp;
      _followMe = true;
    });
    _applyCameraPose(_lastKnownLocation);
    _syncNorthUpAutoFitTimer();
  }

  /// Snaps the camera back onto [location] — the 10s auto-recenter and the
  /// manual button both share this.
  void _recenter(DeviceLocation? location) {
    if (location == null) return;
    _autoRecenterTimer?.cancel();
    _applyCameraPose(location);
    setState(() => _followMe = true);
  }

  void _onLivePosition(DeviceLocation location) {
    _lastKnownLocation = location;
    // Continuous per-tick tracking only applies to heading-up mode, and
    // only while actually following — "como un navegador" means the camera
    // stays locked on the cadete the whole time they're being followed, not
    // just re-centering after the fact. North-up is an overview instead:
    // [_northUpAutoFitTimer] refreshes its frame every 20s rather than
    // chasing every GPS tick, which would fight seeing the whole route.
    if (_headingUp && _followMe) {
      try {
        _animatedMapController.animateTo(
          dest: latlong.LatLng(location.latitude, location.longitude),
          rotation: -_bearingToDestination(location),
          duration: _liveTrackingDuration,
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
            _lastKnownLocation = currentLocation ?? _lastKnownLocation;
            if (!_initialPoseApplied && _lastKnownLocation != null) {
              // Opens already framed per the current mode (heading-up by
              // default: centered, zoomed to the 5-block radius, rotated
              // toward the destination) instead of waiting for the first
              // recenter trigger. Deferred a frame so the map is attached.
              _initialPoseApplied = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _applyCameraPose(_lastKnownLocation);
              });
            }
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
              final routePoints = data.route!.polylinePoints
                  .map((point) => latlong.LatLng(point.latitude, point.longitude))
                  .toList(growable: false);
              // Cached for _recenter's north-up fit-to-bounds — see field doc.
              _lastKnownRoutePoints = routePoints;
              polylines.add(
                Polyline(
                  points: routePoints,
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
            onPressed: _toggleHeadingUp,
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
              onPressed: () => _recenter(_lastKnownLocation),
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
        // Belt-and-suspenders against any camera update — `animateTo`,
        // `animatedFitCamera`, the live-position ticks, ANY of them —
        // ever landing on an out-of-range zoom. `_applyCameraPose`'s own
        // `CameraFit.coordinates(maxZoom: ...)` only guards its own
        // north-up branch; the default heading-up branch calls
        // `animateTo` directly with no clamp of its own. flutter_map
        // enforces `MapOptions.maxZoom`/`minZoom` at the `MapCamera`
        // level for every camera-changing call, regardless of which one
        // produced an out-of-range value — this is the one place that
        // protects all of them at once instead of each call site
        // individually.
        maxZoom: 19,
        minZoom: 3,
        onPositionChanged: (camera, hasGesture) {
          if (!hasGesture) return;
          if (_followMe) setState(() => _followMe = false);
          _scheduleAutoRecenter();
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
