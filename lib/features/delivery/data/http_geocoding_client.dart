import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/geocoding_client.dart';

/// [GeocodingClient] backed by a raw HTTPS call to Google's Geocoding API
/// (design decision #9 — one `http` dependency serves both this and the
/// future `DirectionsClient`; rejected the `geocoding` device-geocoder
/// package for inconsistent OEM behavior).
///
/// Never throws: a network error, non-200 response, non-`OK` API status, an
/// empty result set, or a malformed body are all swallowed and reported as
/// `null` — geocoding is best-effort per spec's "Geocoding does not block
/// creation".
class HttpGeocodingClient implements GeocodingClient {
  HttpGeocodingClient({required String apiKey, http.Client? httpClient})
    : _apiKey = apiKey,
      _httpClient = httpClient ?? http.Client();

  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';

  final String _apiKey;
  final http.Client _httpClient;

  @override
  Future<GeocodeResult?> geocode(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty || _apiKey.isEmpty) return null;

    try {
      final uri = Uri.parse(
        _baseUrl,
      ).replace(queryParameters: <String, String>{'address': trimmed, 'key': _apiKey});
      final response = await _httpClient.get(uri);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['status'] != 'OK') return null;

      final results = decoded['results'];
      if (results is! List || results.isEmpty) return null;

      final first = results.first;
      if (first is! Map<String, dynamic>) return null;
      final geometry = first['geometry'];
      if (geometry is! Map<String, dynamic>) return null;
      final location = geometry['location'];
      if (location is! Map<String, dynamic>) return null;

      final lat = location['lat'];
      final lng = location['lng'];
      if (lat is! num || lng is! num) return null;

      return GeocodeResult(latitude: lat.toDouble(), longitude: lng.toDouble());
    } catch (_) {
      // Network failure, timeout, malformed JSON, placeholder/invalid API
      // key, etc. — all treated identically as "could not geocode".
      return null;
    }
  }
}
