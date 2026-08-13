import 'package:geolocator/geolocator.dart';

import '../domain/location_client.dart';

/// [LocationClient] backed by `package:geolocator`.
///
/// Never throws: handles every permission/service-availability branch
/// explicitly and reports `null` for all of them, matching
/// [LocationClient]'s contract — the navigation map screen falls back to a
/// destination-marker-only view (design decision #12: "permission denial
/// degrades to destination-marker-only, no route band").
class GeolocatorLocationClient implements LocationClient {
  const GeolocatorLocationClient();

  @override
  Future<DeviceLocation?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // `getCurrentPosition` has no built-in timeout — on a real device
      // (unlike an emulator's instant mock location) a cold GPS fix can
      // take minutes or never resolve at all (indoors, poor signal), which
      // would otherwise leave `navigationRouteProvider` stuck loading
      // forever — a genuine hang, not the graceful degradation this class
      // promises. The explicit `.timeout` guarantees this always resolves
      // within a bounded time; a timeout is caught below like any other
      // platform failure and degrades to `null`, same as a denied
      // permission.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 12));
      if (!_isValidCoordinate(position.latitude, position.longitude)) return null;
      return DeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
      );
    } catch (_) {
      // Platform failure (timeout, unsupported device, plugin not
      // registered, etc.) — always degrade to "no location", never throw.
      return null;
    }
  }

  @override
  Stream<DeviceLocation> watchPosition() async* {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
    } catch (_) {
      // Same permission/service failures as getCurrentLocation — no
      // stream to watch if we can't even start.
      return;
    }

    yield* Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5, // meters — avoid rebuilding the map on GPS jitter
          ),
        )
        // A malformed fix (NaN/out-of-range lat-lng — a known real-device
        // GPS-firmware quirk, not just a theoretical edge case) must never
        // reach a consumer: `navigation_map_screen.dart` feeds this
        // straight into `flutter_map`'s `CameraFit.coordinates`, whose
        // internal `LatLngBounds` throws an uncaught assertion on NaN from
        // *inside* the animation's frame callback — outside any
        // synchronous try/catch the caller might wrap around it, so it
        // crashes the whole render pipeline instead of being swallowed.
        // Dropping the tick here (not emitting) is the safe equivalent of
        // this stream's usual "mid-stream failure produces no event"
        // contract, same as `handleError` below.
        .where((position) => _isValidCoordinate(position.latitude, position.longitude))
        .map(
          (position) => DeviceLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            heading: position.heading,
          ),
        )
        // A mid-stream failure (permission revoked, service turned off,
        // etc.) just stops producing updates — never an error event, per
        // this port's "degrade, don't throw" contract.
        .handleError((Object _) {});
  }

  /// True iff [latitude]/[longitude] are finite numbers within valid
  /// geographic range — rejects the NaN/Infinity readings some devices'
  /// GPS stacks occasionally emit (see [watchPosition]'s doc comment on
  /// why this must be caught here, at the source, rather than downstream).
  static bool _isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  @override
  Future<bool> isServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {
      // Best-effort — some platforms/emulators don't expose this screen.
    }
  }
}
