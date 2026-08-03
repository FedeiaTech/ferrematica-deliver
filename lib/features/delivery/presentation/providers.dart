import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/providers.dart' show ordersStreamProvider;
import '../data/providers.dart'
    show directionsClientProvider, locationClientProvider, routeCacheProvider;
import '../domain/directions_client.dart' as directions;
import '../domain/location_client.dart';
import '../domain/route_cache.dart';

/// [ordersStreamProvider] filtered client-side to only the orders assigned
/// to the currently signed-in cadete (spec's `cadete-orders` domain:
/// "MUST show a cadete only orders where `assigned_cadete_id` equals their
/// own user id, enforced both client-side and via RLS"). The `cadete_select`
/// RLS policy already scopes what the Supabase query returns server-side —
/// this filter is the client-side half of that same requirement, and also
/// protects against a stale/cached row for a since-reassigned order
/// lingering in the shared [ordersStreamProvider] cache.
///
/// Returns an empty list (never an error) while the session is still
/// resolving or if there is no session, matching [OrdersController
/// .createOrder]'s treatment of "no session" as a state the router guard
/// should make unreachable in practice rather than a screen-level error.
final Provider<AsyncValue<List<Order>>> cadeteOrdersProvider =
    Provider<AsyncValue<List<Order>>>((ref) {
      final session = ref.watch(sessionProvider).value;
      final ordersAsync = ref.watch(ordersStreamProvider);
      if (session == null) {
        return const AsyncValue<List<Order>>.data(<Order>[]);
      }
      return ordersAsync.whenData(
        (orders) => orders
            .where((order) => order.assignedCadeteId == session.userId)
            .toList(growable: false),
      );
    });

/// The device's current position, fetched once and shared by every
/// [OrderCard] in the dashboard list so each row can show its distance
/// from here — a single `getCurrentLocation()` call per list render
/// instead of one per card. `null` while unresolved (no permission, GPS
/// off, or still loading); cards that need it simply don't show a
/// distance in that case, same "degrade, don't block" pattern as the rest
/// of this feature.
final FutureProvider<DeviceLocation?> currentDeviceLocationProvider =
    FutureProvider<DeviceLocation?>((ref) {
      return ref.watch(locationClientProvider).getCurrentLocation();
    });

/// Live stream of the device's position while [NavigationMapScreen] is
/// open — drives the "current location" marker and heading-up map
/// rotation in real time, as opposed to [navigationRouteProvider]'s
/// one-shot fix (which the Directions route request is keyed on, per
/// design decision #10 — one request per screen open, not a live re-route
/// on every tick).
final StreamProvider<DeviceLocation> livePositionProvider = StreamProvider<DeviceLocation>((
  ref,
) {
  return ref.watch(locationClientProvider).watchPosition();
});

/// Whether the device's location service (GPS) is currently on —
/// [NavigationMapScreen] shows a banner prompting the user to enable it
/// when this resolves `false`, instead of only silently degrading to a
/// destination-marker-only view.
final FutureProvider<bool> locationServiceEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(locationClientProvider).isServiceEnabled();
});

/// The destination coordinates a [navigationRouteProvider] request is keyed
/// on. Value-equal so re-watching with the same order/coordinates never
/// re-fires the Directions/location request (e.g. on an unrelated provider
/// rebuild).
final class NavigationTarget {
  const NavigationTarget({
    required this.orderId,
    required this.latitude,
    required this.longitude,
  });

  final String orderId;
  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NavigationTarget &&
        other.orderId == orderId &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(orderId, latitude, longitude);
}

/// Result of resolving the cadete's live location and the driving route to
/// [NavigationTarget]'s destination. Either half MAY be `null` — the screen
/// renders a degraded state (destination-marker-only, "no se pudo calcular
/// la ruta") rather than treating a missing location or route as an error,
/// per spec's "Map with destination and route" requirement and design's
/// "permission denial degrades to destination-marker-only" (decision #12).
///
/// [isFromCache] is `true` when [route] came from the offline [RouteCache]
/// fallback rather than a fresh Directions call (spec's "Offline route
/// fallback": read-only, no live re-routing without signal) — the screen
/// uses it to show a "sin conexión" banner.
final class NavigationRouteData {
  const NavigationRouteData({
    required this.currentLocation,
    required this.route,
    this.isFromCache = false,
  });

  final DeviceLocation? currentLocation;
  final directions.RouteResult? route;
  final bool isFromCache;
}

/// Fetches the cadete's current location, then (if available) the driving
/// route to [target]'s destination — one Directions API request per screen
/// open, matching design decision #10 ("one request per `en_camino`
/// transition, not per location tick").
///
/// Offline fallback (spec's "Offline route fallback", design decision #11):
/// every successful Directions fetch is written to [routeCacheProvider],
/// keyed by `target.orderId`, so the first successful fetch after the
/// `asignado` -> `en_camino` transition (when the cadete starts navigation)
/// seeds the cache. If a later fetch fails — no current location, or the
/// Directions call itself fails, which is how [DirectionsClient] also
/// reports "no connectivity" — the last-cached route for this order (if
/// any) is returned instead, read-only, with [NavigationRouteData
/// .isFromCache] set so the UI can flag it; no re-routing is attempted from
/// the cached data.
final navigationRouteProvider =
    FutureProvider.family<NavigationRouteData, NavigationTarget>((ref, target) async {
      final locationClient = ref.watch(locationClientProvider);
      final currentLocation = await locationClient.getCurrentLocation();

      final directionsClient = ref.watch(directionsClientProvider);
      final routeCache = ref.watch(routeCacheProvider);

      directions.RouteResult? route;
      if (currentLocation != null) {
        route = await directionsClient.route(
          from: directions.LatLng(
            latitude: currentLocation.latitude,
            longitude: currentLocation.longitude,
          ),
          to: directions.LatLng(latitude: target.latitude, longitude: target.longitude),
        );
      }

      if (route != null) {
        await routeCache.write(
          target.orderId,
          CachedRoute(
            polylinePoints: route.polylinePoints,
            distanceMeters: route.distanceMeters,
            durationSeconds: route.durationSeconds,
            cachedAt: DateTime.now(),
          ),
        );
        return NavigationRouteData(currentLocation: currentLocation, route: route);
      }

      final cached = await routeCache.read(target.orderId);
      if (cached != null) {
        return NavigationRouteData(
          currentLocation: currentLocation,
          route: directions.RouteResult(
            polylinePoints: cached.polylinePoints,
            distanceMeters: cached.distanceMeters,
            durationSeconds: cached.durationSeconds,
          ),
          isFromCache: true,
        );
      }

      return NavigationRouteData(currentLocation: currentLocation, route: null);
    });
