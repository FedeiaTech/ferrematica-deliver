import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../domain/geocoding_client.dart';
import 'http_geocoding_client.dart';

/// The app's [GeocodingClient], backed by a raw HTTPS call to Google's
/// Geocoding API using [AppConfig.mapsApiKey]. If the key is empty (or a
/// placeholder), [HttpGeocodingClient.geocode] simply returns `null` for
/// every address — see its doc comment; this is a normal "could not
/// geocode" outcome, not a crash. Overridden in tests with a fake.
final Provider<GeocodingClient> geocodingClientProvider = Provider<GeocodingClient>(
  (ref) => HttpGeocodingClient(apiKey: ref.watch(appConfigProvider).mapsApiKey),
);
