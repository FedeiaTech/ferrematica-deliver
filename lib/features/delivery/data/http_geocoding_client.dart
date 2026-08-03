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

  /// Recognized ways a dueño phrases a street corner instead of a house
  /// number ("no tengo el número, es en la esquina") — checked in order,
  /// case-insensitively, against the address portion only (before the
  /// first comma), so a city name never accidentally matches.
  static const List<String> _intersectionSeparators = [
    ' y ',
    ' esquina ',
    ' esq ',
    ' & ',
    ' / ',
  ];

  @override
  Future<GeocodeResult?> geocode(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;

    final direct = await _geocodeCandidates(trimmed, limit: 1);
    if (direct.isNotEmpty) return direct.first;

    return _geocodeIntersection(trimmed);
  }

  /// Nominatim's free-text search has no reliable concept of a street
  /// intersection, so a corner address without a house number (very common
  /// for this app per the dueño — "muchas veces no tengo el número")
  /// usually returns zero results directly. Falls back to geocoding each
  /// street separately (both keeping whatever suffix followed the first
  /// comma — the city/province/country hint).
  ///
  /// Each street is asked for up to [_intersectionCandidateLimit] matches
  /// (Nominatim returns different segments/points along a long street as
  /// separate results) rather than just one — the corner is then
  /// approximated as the midpoint of whichever (streetA candidate,
  /// streetB candidate) pair is physically closest to each other, not a
  /// midpoint of each street's single best-ranked (by "importance", not
  /// proximity) match. A street with only one candidate still works — it's
  /// just the only choice in that street's pool. Only attempted after
  /// [geocode]'s direct query already failed, so this never spends the
  /// extra requests on an address that resolves normally.
  Future<GeocodeResult?> _geocodeIntersection(String query) async {
    final commaIndex = query.indexOf(',');
    final streetPart = commaIndex == -1 ? query : query.substring(0, commaIndex);
    final suffix = commaIndex == -1 ? '' : query.substring(commaIndex);
    final lowerStreetPart = streetPart.toLowerCase();

    for (final separator in _intersectionSeparators) {
      final index = lowerStreetPart.indexOf(separator);
      if (index == -1) continue;

      final streetA = streetPart.substring(0, index).trim();
      final streetB = streetPart.substring(index + separator.length).trim();
      if (streetA.isEmpty || streetB.isEmpty) continue;

      final candidatesA = await _geocodeCandidates(
        '$streetA$suffix',
        limit: _intersectionCandidateLimit,
      );
      final candidatesB = await _geocodeCandidates(
        '$streetB$suffix',
        limit: _intersectionCandidateLimit,
      );
      if (candidatesA.isEmpty || candidatesB.isEmpty) continue;

      GeocodeResult? closestA;
      GeocodeResult? closestB;
      var closestDistanceSquared = double.infinity;
      for (final a in candidatesA) {
        for (final b in candidatesB) {
          final deltaLat = a.latitude - b.latitude;
          final deltaLon = a.longitude - b.longitude;
          final distanceSquared = deltaLat * deltaLat + deltaLon * deltaLon;
          if (distanceSquared < closestDistanceSquared) {
            closestDistanceSquared = distanceSquared;
            closestA = a;
            closestB = b;
          }
        }
      }
      if (closestA == null || closestB == null) continue;

      return GeocodeResult(
        latitude: (closestA.latitude + closestB.latitude) / 2,
        longitude: (closestA.longitude + closestB.longitude) / 2,
      );
    }
    return null;
  }

  static const int _intersectionCandidateLimit = 5;

  Future<List<GeocodeResult>> _geocodeCandidates(String query, {required int limit}) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: <String, String>{
          'q': query,
          'format': 'json',
          'limit': limit.toString(),
          // Restricts results to Argentina — without it, a street name that
          // also exists elsewhere in the world (or in another Argentine
          // city) can outrank the intended local match, since Nominatim
          // otherwise ranks by global "importance", not proximity. The
          // caller (OrdersController._geocodeAndSave) further disambiguates
          // same-country matches by appending the dueño-selected city to
          // the address before calling [geocode].
          'countrycodes': 'ar',
        },
      );
      final response = await _httpClient.get(uri, headers: const {'User-Agent': _userAgent});
      if (response.statusCode != 200) return const <GeocodeResult>[];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const <GeocodeResult>[];

      final results = <GeocodeResult>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        // Nominatim returns lat/lon as JSON strings, not numbers.
        final lat = item['lat'];
        final lon = item['lon'];
        if (lat is! String || lon is! String) continue;
        final latitude = double.tryParse(lat);
        final longitude = double.tryParse(lon);
        if (latitude == null || longitude == null) continue;
        results.add(GeocodeResult(latitude: latitude, longitude: longitude));
      }
      return results;
    } catch (_) {
      // Network failure, timeout, malformed JSON, etc. — all treated
      // identically as "no candidates".
      return const <GeocodeResult>[];
    }
  }

  static const String _reverseBaseUrl = 'https://nominatim.openstreetmap.org/reverse';

  @override
  Future<String?> reverseGeocodeCity(double latitude, double longitude) async {
    try {
      final uri = Uri.parse(_reverseBaseUrl).replace(
        queryParameters: <String, String>{
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'format': 'json',
          'zoom': '10', // city/town level, not street level
        },
      );
      final response = await _httpClient.get(uri, headers: const {'User-Agent': _userAgent});
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final address = decoded['address'];
      if (address is! Map<String, dynamic>) return null;

      // Nominatim's address breakdown has no single stable "city" key across
      // regions — a locality can land in any of these depending on how OSM
      // tagged it. Checked in descending specificity.
      for (final key in <String>[
        'city',
        'town',
        'village',
        'municipality',
        'city_district',
      ]) {
        final value = address[key];
        if (value is String && value.trim().isNotEmpty) return value;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
