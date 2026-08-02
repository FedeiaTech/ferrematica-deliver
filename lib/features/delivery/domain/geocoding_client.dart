/// Pure-Dart port for turning a free-text address into coordinates. No
/// `http` or vendor SDK imports here — the data layer implements this.
library;

/// A resolved (latitude, longitude) pair from a successful geocode.
final class GeocodeResult {
  const GeocodeResult({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeocodeResult &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeocodeResult($latitude, $longitude)';
}

/// Port over an external geocoding provider (design decision #9 — a raw
/// HTTPS call to the Geocoding API, not a device-geocoder package).
///
/// Implementations MUST NOT throw: network errors, an invalid/placeholder
/// API key, or "no results" are all reported as `null`, never propagated —
/// spec's "Geocoding does not block creation" requires order create/edit to
/// succeed regardless of geocoding outcome, so callers treat this as
/// best-effort and never need a try/catch of their own.
abstract interface class GeocodingClient {
  /// Attempts to resolve [address] to coordinates. Returns `null` on any
  /// failure (never throws).
  Future<GeocodeResult?> geocode(String address);
}
