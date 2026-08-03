/// Pure-Dart port for reading the device's current GPS position. No
/// `geolocator` (or any platform-channel) imports here — the data layer
/// implements this, mirroring [GeocodingClient]'s port/impl split.
library;

/// A resolved (latitude, longitude) device fix.
final class DeviceLocation {
  const DeviceLocation({required this.latitude, required this.longitude, this.heading});

  final double latitude;
  final double longitude;

  /// Course over ground in degrees (0-360, 0 = north), as reported by the
  /// GPS hardware itself — not a magnetic compass reading. `null` when the
  /// platform can't provide one (common when stationary, since course over
  /// ground needs movement to be meaningful) or the fix came from
  /// [LocationClient.getCurrentLocation] rather than [LocationClient
  /// .watchPosition] (a single fix is less likely to carry a reliable
  /// heading than a live stream). Used to rotate the navigation map to
  /// "direction of travel" instead of a fixed compass.
  final double? heading;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceLocation &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.heading == heading;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude, heading);

  @override
  String toString() => 'DeviceLocation($latitude, $longitude, heading: $heading)';
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

  /// Whether the device's location service (GPS) is currently on. Screens
  /// use this to proactively prompt the user to enable it — a disabled
  /// service is silently indistinguishable from a denied permission inside
  /// [getCurrentLocation]'s `null` result, so this is checked separately.
  Future<bool> isServiceEnabled();

  /// Opens the platform's location-settings screen so the user can turn
  /// the location service on. Never throws.
  Future<void> openLocationSettings();

  /// Live stream of position updates while the navigation map is open —
  /// used for the "current location" marker and heading-up map rotation,
  /// as opposed to [getCurrentLocation]'s one-shot fix (which the Directions
  /// route request is keyed on, per design decision #10's "one request per
  /// screen open", not a live re-route on every tick). Never emits an
  /// error event: a denied/disabled service simply produces no further
  /// events, matching [getCurrentLocation]'s "degrade, don't throw"
  /// contract.
  Stream<DeviceLocation> watchPosition();
}
