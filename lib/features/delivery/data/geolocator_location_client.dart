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
      return DeviceLocation(latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      // Platform failure (timeout, unsupported device, plugin not
      // registered, etc.) — always degrade to "no location", never throw.
      return null;
    }
  }
}
