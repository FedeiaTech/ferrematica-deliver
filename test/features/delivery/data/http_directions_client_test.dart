import 'dart:convert';

import 'package:ferrematica_express/features/delivery/data/http_directions_client.dart';
import 'package:ferrematica_express/features/delivery/domain/directions_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Covers [HttpDirectionsClient] against a fake `http.Client` (via
/// `package:http/testing.dart`'s `MockClient`) — never a real network call,
/// per the design's "external APIs sit behind Dart ports so tests never hit
/// the network" testing strategy.
void main() {
  const from = LatLng(latitude: -34.6037, longitude: -58.3816);
  const to = LatLng(latitude: -34.6118, longitude: -58.3960);

  group('HttpDirectionsClient.route', () {
    test('returns a route for a successful Ok response', () async {
      final client = HttpDirectionsClient(
        httpClient: MockClient((request) async {
          // OSRM wants lon,lat order in the URL path — opposite of this
          // app's own LatLng(latitude, longitude) field order.
          expect(
            request.url.path,
            endsWith('/route/v1/driving/-58.3816,-34.6037;-58.396,-34.6118'),
          );
          expect(request.url.queryParameters['overview'], 'full');
          expect(request.url.queryParameters['geometries'], 'polyline');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 'Ok',
              'routes': [
                {
                  // Encodes a short 2-point polyline via the standard
                  // (precision-5) polyline algorithm, same as OSRM's default.
                  'geometry': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
                  'distance': 1500,
                  'duration': 300,
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await client.route(from: from, to: to);

      expect(result, isNotNull);
      expect(result!.distanceMeters, 1500);
      expect(result.durationSeconds, 300);
      expect(result.polylinePoints, isNotEmpty);
    });

    test('returns null when the API code is not Ok', () async {
      final client = HttpDirectionsClient(
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(<String, dynamic>{'code': 'NoRoute', 'routes': []}),
            200,
          ),
        ),
      );

      final result = await client.route(from: from, to: to);

      expect(result, isNull);
    });

    test('returns null when there are no routes', () async {
      final client = HttpDirectionsClient(
        httpClient: MockClient(
          (request) async =>
              http.Response(jsonEncode(<String, dynamic>{'code': 'Ok', 'routes': []}), 200),
        ),
      );

      final result = await client.route(from: from, to: to);

      expect(result, isNull);
    });

    test('returns null on a non-200 HTTP response', () async {
      final client = HttpDirectionsClient(
        httpClient: MockClient((request) async => http.Response('Server error', 500)),
      );

      final result = await client.route(from: from, to: to);

      expect(result, isNull);
    });

    test('returns null instead of throwing when the request throws', () async {
      final client = HttpDirectionsClient(
        httpClient: MockClient((request) async {
          throw const SocketExceptionStub();
        }),
      );

      final result = await client.route(from: from, to: to);

      expect(result, isNull);
    });

    test('returns null instead of throwing on malformed JSON', () async {
      final client = HttpDirectionsClient(
        httpClient: MockClient((request) async => http.Response('not json at all', 200)),
      );

      final result = await client.route(from: from, to: to);

      expect(result, isNull);
    });

    test('returns null instead of throwing on a malformed encoded polyline', () async {
      final client = HttpDirectionsClient(
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(<String, dynamic>{
              'code': 'Ok',
              'routes': [
                // Truncated/invalid polyline chunk: decoder must not throw.
                {'geometry': '_p', 'distance': 100, 'duration': 30},
              ],
            }),
            200,
          ),
        ),
      );

      final result = await client.route(from: from, to: to);

      expect(result, isNull);
    });
  });
}

/// Minimal stand-in for a thrown network error (avoids depending on
/// `dart:io`'s `SocketException` directly in a widget-test target).
final class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
