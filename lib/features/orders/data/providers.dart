import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/providers.dart';
import '../../../core/supabase/providers.dart';
import '../domain/orders_repository.dart';
import 'isar_orders_repository.dart';
import 'order_sync_service.dart';
import 'supabase_orders_remote.dart';

/// Exposes [Connectivity]'s change stream. Overridable in tests with a fake
/// `Stream<List<ConnectivityResult>>` (e.g. a `StreamController`).
final Provider<Stream<List<ConnectivityResult>>> connectivityProvider =
    Provider<Stream<List<ConnectivityResult>>>((ref) => Connectivity().onConnectivityChanged);

/// The app's [OrdersRepository], backed by the local Isar instance.
final Provider<OrdersRepository> ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => IsarOrdersRepository(ref.watch(isarProvider)),
);

/// The [OrdersRemote] port, backed by the real `supabase_flutter` client.
final Provider<OrdersRemote> ordersRemoteProvider = Provider<OrdersRemote>(
  (ref) => SupabaseOrdersRemote(ref.watch(supabaseProvider)),
);

/// Drives push/pull sync between Isar and Supabase for the `orders`
/// feature. A single instance lives for the app's lifetime; wires the
/// repository's post-write hook so a local mutation also triggers a drain
/// attempt (design's "post-write" trigger), alongside connectivity-regained
/// and app-resume triggers started internally by [OrderSyncService.start].
final Provider<OrderSyncService> orderSyncServiceProvider = Provider<OrderSyncService>((ref) {
  final repository = ref.watch(ordersRepositoryProvider);
  final service = OrderSyncService(
    repository: repository,
    remote: ref.watch(ordersRemoteProvider),
    isar: ref.watch(isarProvider),
    connectivityStream: ref.watch(connectivityProvider),
  );

  if (repository is IsarOrdersRepository) {
    repository.onWrite = service.drain;
  }

  service.start();
  ref.onDispose(service.dispose);
  return service;
});
