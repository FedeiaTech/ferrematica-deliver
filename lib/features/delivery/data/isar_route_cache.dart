import 'package:isar_community/isar.dart';

import '../domain/route_cache.dart';
import 'route_cache_model.dart';

/// [RouteCache] backed by the local Isar instance — one row per `orderId`,
/// overwritten on every successful fetch (design decision #11).
class IsarRouteCache implements RouteCache {
  IsarRouteCache(this._isar);

  final Isar _isar;

  @override
  Future<CachedRoute?> read(String orderId) async {
    final model = await _isar.routeCacheModels.filter().orderIdEqualTo(orderId).findFirst();
    return model == null ? null : routeCacheModelToDomain(model);
  }

  @override
  Future<void> write(String orderId, CachedRoute route) async {
    await _isar.writeTxn(() async {
      await _isar.routeCacheModels.put(routeCacheModelFromDomain(orderId, route));
    });
  }
}
