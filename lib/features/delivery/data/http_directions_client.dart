import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/directions_client.dart';

/// [DirectionsClient] backed by a raw HTTPS call to
/// [OSRM](http://project-osrm.org/)'s public demo routing server — no API
/// key, no billing card required (design decision: replaces the Google
/// Directions API to remove the hard Google Cloud billing-card blocker).
///
/// The public demo server (`router.project-osrm.org`) is dev-only — its
/// terms of use do not license it for production-scale traffic; scaling
/// this app in production would require self-hosting an OSRM instance.
///
/// Never throws: a network error, non-200 response, non-`Ok` API code, an
/// empty route list, or a malformed body are all swallowed and reported as
/// `null` — the navigation map screen degrades to a destination-marker-only
/// view rather than crashing when a route can't be computed.
class HttpDirectionsClient implements DirectionsClient {
  HttpDirectionsClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  static const String _baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  final http.Client _httpClient;

  @override
  Future<RouteResult?> route({required LatLng from, required LatLng to}) async {
    try {
      // OSRM's URL path wants `lon,lat` order (opposite of this app's own
      // LatLng(latitude, longitude) field order) — do not swap these.
      final coordinates =
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
      final uri = Uri.parse('$_baseUrl/$coordinates').replace(
        queryParameters: const <String, String>{'overview': 'full', 'geometries': 'polyline'},
      );
      final response = await _httpClient.get(uri);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['code'] != 'Ok') return null;

      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final firstRoute = routes.first;
      if (firstRoute is! Map<String, dynamic>) return null;

      final encodedPoints = firstRoute['geometry'];
      if (encodedPoints is! String || encodedPoints.isEmpty) return null;

      // Unlike Google's Directions API, OSRM's distance/duration are
      // top-level numeric fields on the route, not nested under `.value`.
      final distanceMeters = firstRoute['distance'];
      final durationSeconds = firstRoute['duration'];
      if (distanceMeters is! num || durationSeconds is! num) return null;

      final points = _decodePolyline(encodedPoints);
      if (points.isEmpty) return null;

      return RouteResult(
        polylinePoints: points,
        distanceMeters: distanceMeters.round(),
        durationSeconds: durationSeconds.round(),
      );
    } catch (_) {
      // Network failure, timeout, malformed JSON, etc. — all treated
      // identically as "could not compute route".
      return null;
    }
  }

  /// Decodes the [encoded polyline algorithm](https://developers.google.com/maps/documentation/utilities/polylinealgorithm)
  /// (precision 5) into a list of [LatLng] points. OSRM's default
  /// `geometries=polyline` output uses this same encoding, so this decoder
  /// (originally written for Google's Directions API) is reused as-is.
  /// Returns an empty list for malformed input instead of throwing,
  /// matching this client's "never throws" contract.
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;
    final length = encoded.length;

    try {
      while (index < length) {
        var shift = 0;
        var result = 0;
        int b;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
        lat += deltaLat;

        shift = 0;
        result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
        lng += deltaLng;

        points.add(LatLng(latitude: lat / 1e5, longitude: lng / 1e5));
      }
    } catch (_) {
      return <LatLng>[];
    }

    return points;
  }
}
