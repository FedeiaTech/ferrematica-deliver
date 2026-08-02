import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/providers.dart' show ordersStreamProvider;
import '../data/providers.dart' show directionsClientProvider, locationClientProvider;
import '../domain/directions_client.dart' as directions;
import '../domain/location_client.dart';

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
final class NavigationRouteData {
  const NavigationRouteData({required this.currentLocation, required this.route});

  final DeviceLocation? currentLocation;
  final directions.RouteResult? route;
}

/// Fetches the cadete's current location, then (if available) the driving
/// route to [target]'s destination — one Directions API request per screen
/// open, matching design decision #10 ("one request per `en_camino`
/// transition, not per location tick"; PR7 will add the offline cache that
/// avoids re-fetching on a later screen open for the same in-progress
/// delivery).
final navigationRouteProvider =
    FutureProvider.family<NavigationRouteData, NavigationTarget>((ref, target) async {
      final locationClient = ref.watch(locationClientProvider);
      final currentLocation = await locationClient.getCurrentLocation();
      if (currentLocation == null) {
        return const NavigationRouteData(currentLocation: null, route: null);
      }

      final directionsClient = ref.watch(directionsClientProvider);
      final route = await directionsClient.route(
        from: directions.LatLng(
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
        ),
        to: directions.LatLng(latitude: target.latitude, longitude: target.longitude),
      );
      return NavigationRouteData(currentLocation: currentLocation, route: route);
    });
