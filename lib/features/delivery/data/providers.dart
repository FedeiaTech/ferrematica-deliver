import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/database/providers.dart';
import '../domain/directions_client.dart';
import '../domain/geocoding_client.dart';
import '../domain/location_client.dart';
import '../domain/route_cache.dart';
import 'geolocator_location_client.dart';
import 'http_directions_client.dart';
import 'http_geocoding_client.dart';
import 'isar_route_cache.dart';

/// The app's [GeocodingClient], backed by a raw HTTPS call to Google's
/// Geocoding API using [AppConfig.mapsApiKey]. If the key is empty (or a
/// placeholder), [HttpGeocodingClient.geocode] simply returns `null` for
/// every address — see its doc comment; this is a normal "could not
/// geocode" outcome, not a crash. Overridden in tests with a fake.
final Provider<GeocodingClient> geocodingClientProvider = Provider<GeocodingClient>(
  (ref) => HttpGeocodingClient(apiKey: ref.watch(appConfigProvider).mapsApiKey),
);

/// The app's [DirectionsClient], backed by a raw HTTPS call to Google's
/// Directions API using [AppConfig.mapsApiKey] (design decision #10 — same
/// `http` transport as [geocodingClientProvider]). Overridden in tests with
/// a fake.
final Provider<DirectionsClient> directionsClientProvider = Provider<DirectionsClient>(
  (ref) => HttpDirectionsClient(apiKey: ref.watch(appConfigProvider).mapsApiKey),
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
