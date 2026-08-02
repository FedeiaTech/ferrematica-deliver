import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/geocoding_client.dart';

/// [GeocodingClient] backed by a raw HTTPS call to OpenStreetMap's
/// [Nominatim search API](https://nominatim.org/release-docs/latest/api/Search/)
/// — no API key, no billing card required (design decision: replaces the
/// Google Geocoding API to remove the hard Google Cloud billing-card
/// blocker). Nominatim's usage policy requires a descriptive `User-Agent`
/// header identifying the app and caps usage at ~1 request/second, both of
/// which this app satisfies (one geocode per order create/edit, not bulk).
///
/// Never throws: a network error, non-200 response, empty result set, or a
/// malformed body are all swallowed and reported as `null` — geocoding is
/// best-effort per spec's "Geocoding does not block creation".
class HttpGeocodingClient implements GeocodingClient {
  HttpGeocodingClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  /// Nominatim's usage policy requires a descriptive User-Agent identifying
  /// the application (not a generic/browser one) — see
  /// https://operations.osmfoundation.org/policies/nominatim/.
  static const String _userAgent = 'Ferrematica/1.0 (delivery order geocoding)';

  final http.Client _httpClient;

  @override
  Future<GeocodeResult?> geocode(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;

    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: <String, String>{'q': trimmed, 'format': 'json', 'limit': '1'},
      );
      final response = await _httpClient.get(uri, headers: const {'User-Agent': _userAgent});
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) return null;

      final first = decoded.first;
      if (first is! Map<String, dynamic>) return null;

      // Nominatim returns lat/lon as JSON strings, not numbers.
      final lat = first['lat'];
      final lon = first['lon'];
      if (lat is! String || lon is! String) return null;

      final latitude = double.tryParse(lat);
      final longitude = double.tryParse(lon);
      if (latitude == null || longitude == null) return null;

      return GeocodeResult(latitude: latitude, longitude: longitude);
    } catch (_) {
      // Network failure, timeout, malformed JSON, etc. — all treated
      // identically as "could not geocode".
      return null;
    }
  }
}
