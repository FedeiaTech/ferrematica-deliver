import 'directions_client.dart' show LatLng;

/// A previously-fetched driving route, persisted locally so the navigation
/// map screen can keep showing a route even when a later Directions API
/// call fails (spec's `cadete-navigation` / "Offline route fallback": cache
/// the route at the `asignado` -> `en_camino` transition, render it
/// read-only if connectivity drops afterward — no live re-routing without
/// signal, but the last-known route stays visible).
final class CachedRoute {
  const CachedRoute({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.cachedAt,
  });

  final List<LatLng> polylinePoints;
  final int distanceMeters;
  final int durationSeconds;
  final DateTime cachedAt;
}

/// Port for reading/writing the last-known route per order (design decision
/// #11 — a separate cache, NOT fields on `Order`/`OrderModel`, so the synced
/// Order payload and its LWW `updatedAt` stay free of client-local
/// navigation state).
///
/// Implementations MUST NOT throw: a cache miss on [read] is `null`, and a
/// storage failure on [write] is swallowed — losing the offline fallback
/// for one order is preferable to crashing the navigation screen over a
/// local-storage error.
abstract interface class RouteCache {
  /// Returns the last route cached for [orderId], or `null` if none was
  /// ever cached (or the write failed silently).
  Future<CachedRoute?> read(String orderId);

  /// Persists [route] as the last-known route for [orderId], replacing any
  /// previous entry for the same order.
  Future<void> write(String orderId, CachedRoute route);
}
