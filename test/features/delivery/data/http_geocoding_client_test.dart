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
    test('returns coordinates for a successful response', () async {
      final client = HttpGeocodingClient(
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['q'], 'Av. Siempre Viva 742');
          expect(request.url.queryParameters['format'], 'json');
          expect(request.url.queryParameters['limit'], '1');
          expect(request.headers['User-Agent'], contains('Ferrematica'));
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              {'lat': '-34.6037', 'lon': '-58.3816'},
            ]),
            200,
          );
        }),
      );

      final result = await client.geocode('Av. Siempre Viva 742');

      expect(result, const GeocodeResult(latitude: -34.6037, longitude: -58.3816));
    });

    test('returns null when there are no results', () async {
      final client = HttpGeocodingClient(
        httpClient: MockClient((request) async => http.Response(jsonEncode(<dynamic>[]), 200)),
      );

      final result = await client.geocode('dirección informal sin sentido');

      expect(result, isNull);
    });

    test('returns null on a non-200 HTTP response', () async {
      final client = HttpGeocodingClient(
        httpClient: MockClient((request) async => http.Response('Server error', 500)),
      );

      final result = await client.geocode('Calle Falsa 123');

      expect(result, isNull);
    });

    test('returns null instead of throwing when the request throws', () async {
      final client = HttpGeocodingClient(
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
        httpClient: MockClient((request) async => http.Response('not json at all', 200)),
      );

      final result = await client.geocode('Calle Falsa 123');

      expect(result, isNull);
    });

    test('returns null when lat/lon are not parseable strings', () async {
      final client = HttpGeocodingClient(
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(<Map<String, dynamic>>[
              {'lat': 'not-a-number', 'lon': '-58.3816'},
            ]),
            200,
          ),
        ),
      );

      final result = await client.geocode('Calle Falsa 123');

      expect(result, isNull);
    });

    test('falls back to the midpoint of both streets for an intersection', () async {
      final requestedQueries = <String>[];
      final client = HttpGeocodingClient(
        httpClient: MockClient((request) async {
          final q = request.url.queryParameters['q']!;
          requestedQueries.add(q);
          if (q == 'Hernandarias y Luján, Santo Tomé, Santa Fe') {
            return http.Response(jsonEncode(<dynamic>[]), 200);
          }
          if (q == 'Hernandarias, Santo Tomé, Santa Fe') {
            return http.Response(
              jsonEncode(<Map<String, dynamic>>[
                {'lat': '-31.6700', 'lon': '-60.7800'},
              ]),
              200,
            );
          }
          if (q == 'Luján, Santo Tomé, Santa Fe') {
            return http.Response(
              jsonEncode(<Map<String, dynamic>>[
                {'lat': '-31.6800', 'lon': '-60.7900'},
              ]),
              200,
            );
          }
          return http.Response(jsonEncode(<dynamic>[]), 200);
        }),
      );

      final result = await client.geocode(
        'Hernandarias y Luján, Santo Tomé, Santa Fe',
      );

      expect(
        result,
        const GeocodeResult(latitude: -31.675, longitude: -60.785),
      );
      expect(requestedQueries, [
        'Hernandarias y Luján, Santo Tomé, Santa Fe',
        'Hernandarias, Santo Tomé, Santa Fe',
        'Luján, Santo Tomé, Santa Fe',
      ]);
    });

    test('picks the closest candidate pair, not just the first result of each street', () async {
      final client = HttpGeocodingClient(
        httpClient: MockClient((request) async {
          final q = request.url.queryParameters['q']!;
          if (q == 'Belgrano y Mitre, Santo Tomé') {
            return http.Response(jsonEncode(<dynamic>[]), 200);
          }
          // Belgrano has two segments far apart; Mitre has one, close to
          // Belgrano's SECOND segment, not its first (best-ranked) one.
          if (q == 'Belgrano, Santo Tomé') {
            return http.Response(
              jsonEncode(<Map<String, dynamic>>[
                {'lat': '-31.0000', 'lon': '-60.0000'},
                {'lat': '-31.6720', 'lon': '-60.7830'},
              ]),
              200,
            );
          }
          if (q == 'Mitre, Santo Tomé') {
            return http.Response(
              jsonEncode(<Map<String, dynamic>>[
                {'lat': '-31.6740', 'lon': '-60.7850'},
              ]),
              200,
            );
          }
          return http.Response(jsonEncode(<dynamic>[]), 200);
        }),
      );

      final result = await client.geocode('Belgrano y Mitre, Santo Tomé');

      // Midpoint of Belgrano's SECOND candidate and Mitre's only
      // candidate — not Belgrano's first (naively "best") one.
      expect(result, isNotNull);
      expect(result!.latitude, closeTo(-31.673, 0.0001));
      expect(result.longitude, closeTo(-60.784, 0.0001));
    });

    test('returns null for an empty address without making a request', () async {
      var requested = false;
      final client = HttpGeocodingClient(
        httpClient: MockClient((request) async {
          requested = true;
          return http.Response('', 200);
        }),
      );

      final result = await client.geocode('   ');

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
