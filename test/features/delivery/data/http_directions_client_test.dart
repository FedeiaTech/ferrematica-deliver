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
    test('returns a route for a successful OK response', () async {
      final client = HttpDirectionsClient(
        apiKey: 'fake-key',
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['origin'], '-34.6037,-58.3816');
          expect(request.url.queryParameters['destination'], '-34.6118,-58.396');
          expect(request.url.queryParameters['key'], 'fake-key');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'status': 'OK',
              'routes': [
                {
                  // Encodes a short 2-point polyline via Google's algorithm.
                  'overview_polyline': {'points': '_p~iF~ps|U_ulLnnqC_mqNvxq`@'},
                  'legs': [
                    {
                      'distance': {'value': 1500},
                      'duration': {'value': 300},
                    },
                  ],
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

    test('returns null when the API status is not OK', () async {
      final client = HttpDirectionsClient(
        apiKey: 'placeholder-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(<String, dynamic>{'status': 'REQUEST_DENIED', 'routes': []}),
            200,
          ),
        ),
      );

      final result = await client.route(from: from, to: to);

      expect(result, isNull);
    });

    test('returns null when there are no routes (ZERO_RESULTS)', () async {
      final client = HttpDirectionsClient(
        apiKey: 'fake-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(<String, dynamic>{'status': 'ZERO_RESULTS', 'routes': []}),
            200,
          ),
        ),
      );

      final result = await client.route(from: from, to: to);

      expect(result, isNull);
    });

    test('returns null on a non-200 HTTP response', () async {
      final client = HttpDirectionsClient(
        apiKey: 'fake-key',
        httpClient: MockClient((request) async => http.Response('Server error', 500)),
      );

      final result = await client.route(from: from, to: to);

      expect(result, isNull);
    });

    test('returns null instead of throwing when the request throws', () async {
      final client = HttpDirectionsClient(
        apiKey: 'fake-key',
        httpClient: MockClient((request) async {
          throw const SocketExceptionStub();
        }),
      );

      final result = await client.route(from: from, to: to);

      expect(result, isNull);
    });

    test('returns null instead of throwing on malformed JSON', () async {
      final client = HttpDirectionsClient(
        apiKey: 'fake-key',
        httpClient: MockClient((request) async => http.Response('not json at all', 200)),
      );

      final result = await client.route(from: from, to: to);

      expect(result, isNull);
    });

    test('returns null instead of throwing on a malformed encoded polyline', () async {
      final client = HttpDirectionsClient(
        apiKey: 'fake-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(<String, dynamic>{
              'status': 'OK',
              'routes': [
                {
                  // Truncated/invalid polyline chunk: decoder must not throw.
                  'overview_polyline': {'points': '_p'},
                  'legs': [
                    {
                      'distance': {'value': 100},
                      'duration': {'value': 30},
                    },
                  ],
                },
              ],
            }),
            200,
          ),
        ),
      );

      final result = await client.route(from: from, to: to);

      expect(result, isNull);
    });

    test('returns null when the API key is empty (placeholder/unprovisioned)', () async {
      var requested = false;
      final client = HttpDirectionsClient(
        apiKey: '',
        httpClient: MockClient((request) async {
          requested = true;
          return http.Response('', 200);
        }),
      );

      final result = await client.route(from: from, to: to);

      expect(result, isNull);
      expect(requested, isFalse);
    });
  });
}

/// Minimal stand-in for a thrown network error (avoids depending on
/// `dart:io`'s `SocketException` directly in a widget-test target).
final class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
