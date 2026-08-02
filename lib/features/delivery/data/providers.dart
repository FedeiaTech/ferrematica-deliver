import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/providers.dart';
import '../domain/directions_client.dart';
import '../domain/geocoding_client.dart';
import '../domain/location_client.dart';
import '../domain/route_cache.dart';
import 'geolocator_location_client.dart';
import 'http_directions_client.dart';
import 'http_geocoding_client.dart';
import 'isar_route_cache.dart';

/// The app's [GeocodingClient], backed by a raw HTTPS call to OpenStreetMap's
/// Nominatim search API — no API key required. Overridden in tests with a
/// fake.
final Provider<GeocodingClient> geocodingClientProvider = Provider<GeocodingClient>(
  (ref) => HttpGeocodingClient(),
);

/// The app's [DirectionsClient], backed by a raw HTTPS call to OSRM's public
/// routing server — no API key required (design decision: same `http`
/// transport as [geocodingClientProvider]). Overridden in tests with a fake.
final Provider<DirectionsClient> directionsClientProvider = Provider<DirectionsClient>(
  (ref) => HttpDirectionsClient(),
);

/// The app's [LocationClient], backed by `package:geolocator` (design
/// decision #12). Overridden in tests with a fake so widget tests never hit
/// real platform location channels.
final Provider<LocationClient> locationClientProvider = Provider<LocationClient>(
  (ref) => const GeolocatorLocationClient(),
);

/// The app's [RouteCache], backed by the local Isar instance (design
/// decision #11 — a separate collection, not fields on `Order`). Overridden
/// in tests with a fake when a test wants to avoid touching Isar directly;
/// most widget tests exercise it against `pumpApp`'s real test-Isar
/// instance, same as `ordersRepositoryProvider`.
final Provider<RouteCache> routeCacheProvider = Provider<RouteCache>(
  (ref) => IsarRouteCache(ref.watch(isarProvider)),
);
