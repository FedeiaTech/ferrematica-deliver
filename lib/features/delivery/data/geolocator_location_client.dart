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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
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
