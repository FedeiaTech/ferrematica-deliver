import 'package:ferrematica_express/features/delivery/data/isar_route_cache.dart';
import 'package:ferrematica_express/features/delivery/domain/directions_client.dart';
import 'package:ferrematica_express/features/delivery/domain/route_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../../../helpers/test_isar.dart';

CachedRoute _buildRoute({
  double lat = -34.61,
  double lng = -58.38,
  int distanceMeters = 2500,
  int durationSeconds = 420,
  DateTime? cachedAt,
}) {
  return CachedRoute(
    polylinePoints: [LatLng(latitude: lat, longitude: lng)],
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
    cachedAt: cachedAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  late Isar isar;
  late IsarRouteCache cache;

  setUp(() async {
    isar = await openTestIsar();
    cache = IsarRouteCache(isar);
  });

  tearDown(() async {
    await closeTestIsar(isar);
  });

  group('read', () {
    test('returns null when nothing was ever cached for the order', () async {
      final result = await cache.read('order-1');

      expect(result, isNull);
    });

    test('returns the previously written route for the order', () async {
      await cache.write('order-1', _buildRoute());

      final result = await cache.read('order-1');

      expect(result, isNotNull);
      expect(result!.distanceMeters, 2500);
      expect(result.durationSeconds, 420);
      expect(result.polylinePoints, [const LatLng(latitude: -34.61, longitude: -58.38)]);
    });
  });

  group('write', () {
    test('a later write for the same order overwrites the previous entry, not a duplicate', () async {
      await cache.write('order-1', _buildRoute(distanceMeters: 1000, durationSeconds: 100));
      await cache.write('order-1', _buildRoute(distanceMeters: 5000, durationSeconds: 900));

      final result = await cache.read('order-1');

      expect(result!.distanceMeters, 5000);
      expect(result.durationSeconds, 900);
    });

    test('caches are independent per order', () async {
      await cache.write('order-1', _buildRoute(distanceMeters: 1000, durationSeconds: 100));
      await cache.write('order-2', _buildRoute(distanceMeters: 2000, durationSeconds: 200));

      expect((await cache.read('order-1'))!.distanceMeters, 1000);
      expect((await cache.read('order-2'))!.distanceMeters, 2000);
    });
  });
}
