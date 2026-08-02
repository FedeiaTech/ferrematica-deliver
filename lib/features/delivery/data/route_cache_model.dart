import 'package:isar_community/isar.dart';

import '../domain/directions_client.dart' show LatLng;
import '../domain/route_cache.dart';

part 'route_cache_model.g.dart';

/// Isar-persisted last-known route per order (design decision #11: a new,
/// separate collection — `route_cache.dart`'s [RouteCache] port — rather
/// than new fields on `OrderModel`, so the synced `Order` row and its LWW
/// `updatedAt` never carry client-local navigation state).
///
/// Stores the already-decoded polyline points (not the raw Google-encoded
/// string): [HttpDirectionsClient] decodes the polyline once at fetch time,
/// so re-encoding it just to cache it would be pure overhead for no gain —
/// the cache only ever needs to hand the points straight to
/// `NavigationMapScreen`.
@collection
class RouteCacheModel {
  RouteCacheModel({
    required this.orderId,
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.cachedAt,
  });

  Id get isarId => fastHashRouteCache(orderId);

  /// One cached route per order — a fresh successful fetch replaces the
  /// previous entry in place (see [Index.replace]).
  @Index(unique: true, replace: true)
  final String orderId;

  final List<RoutePointModel> points;
  final int distanceMeters;
  final int durationSeconds;
  final DateTime cachedAt;
}

/// Embedded point — part of the [RouteCacheModel] row itself, not a
/// separate collection, mirroring `order_model.dart`'s `OrderItemModel`.
@embedded
class RoutePointModel {
  RoutePointModel({this.latitude = 0, this.longitude = 0});

  final double latitude;
  final double longitude;
}

/// Maps an Isar [RouteCacheModel] row to the domain [CachedRoute].
CachedRoute routeCacheModelToDomain(RouteCacheModel model) {
  return CachedRoute(
    polylinePoints: model.points
        .map((point) => LatLng(latitude: point.latitude, longitude: point.longitude))
        .toList(growable: false),
    distanceMeters: model.distanceMeters,
    durationSeconds: model.durationSeconds,
    cachedAt: model.cachedAt,
  );
}

/// Maps a domain [CachedRoute] to its Isar row representation.
RouteCacheModel routeCacheModelFromDomain(String orderId, CachedRoute route) {
  return RouteCacheModel(
    orderId: orderId,
    points: route.polylinePoints
        .map((point) => RoutePointModel(latitude: point.latitude, longitude: point.longitude))
        .toList(growable: false),
    distanceMeters: route.distanceMeters,
    durationSeconds: route.durationSeconds,
    cachedAt: route.cachedAt,
  );
}

/// FNV-1a 64-bit hash, same algorithm as `order_model.dart`'s `fastHash`.
/// Duplicated rather than imported to keep this file's Isar id derivation
/// self-contained (avoids a cross-feature import for a one-line utility).
int fastHashRouteCache(String string) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash;
}
