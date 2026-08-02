import 'dart:convert';

import 'package:ferrematica_express/features/delivery/data/http_geocoding_client.dart';
import 'package:ferrematica_express/features/delivery/domain/geocoding_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Covers [HttpGeocodingClient] against a fake `http.Client` (via
/// `package:http/testing.dart`'s `MockClient`) — never a real network call,
/// per the design's "external APIs sit behind Dart ports so tests never hit
/// the network" testing strategy.
void main() {
  group('HttpGeocodingClient.geocode', () {
    test('returns coordinates for a successful OK response', () async {
      final client = HttpGeocodingClient(
        apiKey: 'fake-key',
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['address'], 'Av. Siempre Viva 742');
          expect(request.url.queryParameters['key'], 'fake-key');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'status': 'OK',
              'results': [
                {
                  'geometry': {
                    'location': {'lat': -34.6037, 'lng': -58.3816},
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await client.geocode('Av. Siempre Viva 742');

      expect(result, const GeocodeResult(latitude: -34.6037, longitude: -58.3816));
    });

    test('returns null when the API status is not OK (e.g. invalid key)', () async {
      final client = HttpGeocodingClient(
        apiKey: 'placeholder-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(<String, dynamic>{'status': 'REQUEST_DENIED', 'results': []}),
            200,
          ),
        ),
      );

      final result = await client.geocode('Cualquier dirección 123');

      expect(result, isNull);
    });

    test('returns null when there are no results (ZERO_RESULTS)', () async {
      final client = HttpGeocodingClient(
        apiKey: 'fake-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(<String, dynamic>{'status': 'ZERO_RESULTS', 'results': []}),
            200,
          ),
        ),
      );

      final result = await client.geocode('dirección informal sin sentido');

      expect(result, isNull);
    });

    test('returns null on a non-200 HTTP response', () async {
      final client = HttpGeocodingClient(
        apiKey: 'fake-key',
        httpClient: MockClient((request) async => http.Response('Server error', 500)),
      );

      final result = await client.geocode('Calle Falsa 123');

      expect(result, isNull);
    });

    test('returns null instead of throwing when the request throws', () async {
      final client = HttpGeocodingClient(
        apiKey: 'fake-key',
        httpClient: MockClient((request) async {
          throw const SocketExceptionStub();
        }),
      );

      // Must not throw: geocoding failure is always reported as null.
      final result = await client.geocode('Calle Falsa 123');

      expect(result, isNull);
    });

    test('returns null instead of throwing on malformed JSON', () async {
      final client = HttpGeocodingClient(
        apiKey: 'fake-key',
        httpClient: MockClient((request) async => http.Response('not json at all', 200)),
      );

      final result = await client.geocode('Calle Falsa 123');

      expect(result, isNull);
    });

    test('returns null for an empty address without making a request', () async {
      var requested = false;
      final client = HttpGeocodingClient(
        apiKey: 'fake-key',
        httpClient: MockClient((request) async {
          requested = true;
          return http.Response('', 200);
        }),
      );

      final result = await client.geocode('   ');

      expect(result, isNull);
      expect(requested, isFalse);
    });

    test('returns null when the API key is empty (placeholder/unprovisioned)', () async {
      var requested = false;
      final client = HttpGeocodingClient(
        apiKey: '',
        httpClient: MockClient((request) async {
          requested = true;
          return http.Response('', 200);
        }),
      );

      final result = await client.geocode('Calle Falsa 123');

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
