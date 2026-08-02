/// Pure-Dart port for fetching a driving route between two points. No
/// `http` or vendor SDK imports here — the data layer implements this,
/// mirroring [GeocodingClient]'s port/impl split.
library;

/// A plain (latitude, longitude) pair — deliberately not
/// `google_maps_flutter`'s `LatLng` so this domain file has zero Flutter/
/// vendor imports. The presentation layer converts to/from the map
/// package's type at the UI boundary.
final class LatLng {
  const LatLng({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LatLng && other.latitude == latitude && other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

/// A resolved driving route: the polyline points to draw, plus basic
/// distance/ETA (spec's "basic distance and ETA MUST be shown").
final class RouteResult {
  const RouteResult({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> polylinePoints;
  final int distanceMeters;
  final int durationSeconds;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteResult &&
        other.distanceMeters == distanceMeters &&
        other.durationSeconds == durationSeconds &&
        _listEquals(other.polylinePoints, polylinePoints);
  }

  @override
  int get hashCode =>
      Object.hash(distanceMeters, durationSeconds, Object.hashAll(polylinePoints));

  @override
  String toString() =>
      'RouteResult(points: ${polylinePoints.length}, ${distanceMeters}m, ${durationSeconds}s)';
}

bool _listEquals(List<LatLng> a, List<LatLng> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Port over the Directions API (design decision #10 — one request per
/// `en_camino` transition, not per location tick; `google_maps_flutter`
/// ships no Directions API of its own).
///
/// Implementations MUST NOT throw: network errors, an invalid/placeholder
/// API key, or "no route found" are all reported as `null`, never
/// propagated — the navigation map screen must degrade to showing the
/// destination marker only, never crash, when a route can't be computed.
abstract interface class DirectionsClient {
  /// Attempts to resolve a driving route from [from] to [to]. Returns
  /// `null` on any failure (never throws).
  Future<RouteResult?> route({required LatLng from, required LatLng to});
}
