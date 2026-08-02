/// Pure-Dart port for reading the device's current GPS position. No
/// `geolocator` (or any platform-channel) imports here — the data layer
/// implements this, mirroring [GeocodingClient]'s port/impl split.
library;

/// A resolved (latitude, longitude) device fix.
final class DeviceLocation {
  const DeviceLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceLocation &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'DeviceLocation($latitude, $longitude)';
}

/// Port over the device's location APIs (design decision #12 — `geolocator`
/// package).
///
/// Implementations MUST NOT throw: a denied/permanently-denied permission, a
/// disabled location service, a timeout, or any other platform failure are
/// all reported as `null`, never propagated — the navigation map screen
/// degrades to a destination-marker-only view rather than crashing when the
/// cadete's live location is unavailable.
abstract interface class LocationClient {
  /// Attempts to resolve the device's current position, requesting
  /// permission first if needed. Returns `null` on any failure or denial
  /// (never throws).
  Future<DeviceLocation?> getCurrentLocation();
}
