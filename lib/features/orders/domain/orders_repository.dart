import 'order.dart';

/// Port interface for order persistence. Implemented by the data layer
/// (`IsarOrdersRepository`, PR3) and mocked/faked directly in tests — the
/// presentation layer only ever depends on this abstraction, never on Isar
/// or Supabase types.
abstract interface class OrdersRepository {
  /// Emits the current list of orders whenever the local store changes.
  /// Soft-deleted orders (`deletedAt != null`) MUST be excluded. If
  /// [status] is provided, only orders with that status are emitted.
  Stream<List<Order>> watchOrders({OrderStatus? status});

  /// Returns the order with the given [id], or `null` if it doesn't exist
  /// (or has been soft-deleted).
  Future<Order?> getById(String id);

  /// Persists [order]. Upsert semantics: creates if `id` is new, otherwise
  /// updates the existing row in place.
  Future<void> save(Order order);

  /// Marks the order with the given [id] as deleted (`deletedAt = now`)
  /// without physically removing the row, so the deletion itself can sync.
  Future<void> softDelete(String id);

  /// Returns all orders whose `syncStatus == pending`, used by the sync
  /// service's drain loop.
  Future<List<Order>> pendingSync();

  /// Marks the order with the given [id] as successfully synced.
  Future<void> markSynced(String id);

  /// Marks the order with the given [id] as failed to sync, recording
  /// [error] for diagnostics.
  Future<void> markFailed(String id, String error);
}
