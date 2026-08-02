import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/directions_client.dart';

/// [DirectionsClient] backed by a raw HTTPS call to Google's Directions API
/// (design decision #10 — same `http` transport as [HttpGeocodingClient];
/// `google_maps_flutter` ships no Directions API of its own).
///
/// Never throws: a network error, non-200 response, non-`OK` API status, an
/// empty route list, or a malformed body are all swallowed and reported as
/// `null` — the navigation map screen degrades to a destination-marker-only
/// view rather than crashing when a route can't be computed.
class HttpDirectionsClient implements DirectionsClient {
  HttpDirectionsClient({required String apiKey, http.Client? httpClient})
    : _apiKey = apiKey,
      _httpClient = httpClient ?? http.Client();

  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  final String _apiKey;
  final http.Client _httpClient;

  @override
  Future<RouteResult?> route({required LatLng from, required LatLng to}) async {
    if (_apiKey.isEmpty) return null;

    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: <String, String>{
          'origin': '${from.latitude},${from.longitude}',
          'destination': '${to.latitude},${to.longitude}',
          'mode': 'driving',
          'key': _apiKey,
        },
      );
      final response = await _httpClient.get(uri);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['status'] != 'OK') return null;

      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final firstRoute = routes.first;
      if (firstRoute is! Map<String, dynamic>) return null;

      final overviewPolyline = firstRoute['overview_polyline'];
      if (overviewPolyline is! Map<String, dynamic>) return null;
      final encodedPoints = overviewPolyline['points'];
      if (encodedPoints is! String || encodedPoints.isEmpty) return null;

      final legs = firstRoute['legs'];
      if (legs is! List || legs.isEmpty) return null;
      final firstLeg = legs.first;
      if (firstLeg is! Map<String, dynamic>) return null;

      final distance = firstLeg['distance'];
      final duration = firstLeg['duration'];
      if (distance is! Map<String, dynamic> || duration is! Map<String, dynamic>) {
        return null;
      }
      final distanceMeters = distance['value'];
      final durationSeconds = duration['value'];
      if (distanceMeters is! num || durationSeconds is! num) return null;

      final points = _decodePolyline(encodedPoints);
      if (points.isEmpty) return null;

      return RouteResult(
        polylinePoints: points,
        distanceMeters: distanceMeters.toInt(),
        durationSeconds: durationSeconds.toInt(),
      );
    } catch (_) {
      // Network failure, timeout, malformed JSON, placeholder/invalid API
      // key, etc. — all treated identically as "could not compute route".
      return null;
    }
  }

  /// Decodes Google's [encoded polyline algorithm](https://developers.google.com/maps/documentation/utilities/polylinealgorithm)
  /// into a list of [LatLng] points. Returns an empty list for malformed
  /// input instead of throwing, matching this client's "never throws"
  /// contract.
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
