import 'dart:async';

import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/domain/orders_repository.dart';

/// Builds a valid [Order] with sensible test defaults, overridable per field.
Order buildTestOrder({
  String id = 'order-1',
  String deliveryAddress = 'Calle Falsa 123',
  OrderStatus status = OrderStatus.pendiente,
  PaymentStatus paymentStatus = PaymentStatus.pendiente,
  PaymentMethod paymentMethod = PaymentMethod.sinDefinir,
  double? amountToCharge,
  SyncStatus syncStatus = SyncStatus.pending,
  DateTime? updatedAt,
  String? assignedCadeteId,
  double? pendingBalance,
  double? valorEnvio,
  double? envioPendingBalance,
  String? deliveryProblem,
  DateTime? incobrableAt,
}) {
  final at = updatedAt ?? DateTime(2026, 1, 1);
  return Order(
    id: id,
    deliveryAddress: deliveryAddress,
    createdBy: 'owner-1',
    createdAt: at,
    updatedAt: at,
    status: status,
    paymentStatus: paymentStatus,
    paymentMethod: paymentMethod,
    amountToCharge: amountToCharge,
    syncStatus: syncStatus,
    assignedCadeteId: assignedCadeteId,
    pendingBalance: pendingBalance,
    valorEnvio: valorEnvio,
    envioPendingBalance: envioPendingBalance,
    deliveryProblem: deliveryProblem,
    incobrableAt: incobrableAt,
  );
}

/// In-memory [OrdersRepository] double for widget tests, per design's
/// testing strategy ("overriding `ordersRepositoryProvider` with an
/// in-memory fake"). Mirrors [IsarOrdersRepository]'s soft-delete and
/// status-filter semantics closely enough for presentation-layer tests
/// without touching Isar.
class FakeOrdersRepository implements OrdersRepository {
  FakeOrdersRepository({List<Order> seed = const <Order>[]}) {
    for (final order in seed) {
      _orders[order.id] = order;
    }
  }

  final Map<String, Order> _orders = <String, Order>{};
  final StreamController<List<Order>> _controller =
      StreamController<List<Order>>.broadcast();

  List<Order> get _visible =>
      _orders.values.where((order) => order.deletedAt == null).toList(growable: false);

  void _emit() {
    if (!_controller.isClosed) _controller.add(_visible);
  }

  @override
  Stream<List<Order>> watchOrders({OrderStatus? status}) async* {
    final initial = status == null
        ? _visible
        : _visible.where((order) => order.status == status).toList(growable: false);
    yield initial;
    yield* _controller.stream.map(
      (orders) => status == null
          ? orders
          : orders.where((order) => order.status == status).toList(growable: false),
    );
  }

  @override
  Future<Order?> getById(String id) async {
    final order = _orders[id];
    if (order == null || order.deletedAt != null) return null;
    return order;
  }

  @override
  Future<void> save(Order order) async {
    _orders[order.id] = order;
    _emit();
  }

  @override
  Future<void> softDelete(String id) async {
    final order = _orders[id];
    if (order == null) return;
    _orders[id] = order.copyWith(deletedAt: DateTime.now(), syncStatus: SyncStatus.pending);
    _emit();
  }

  @override
  Future<List<Order>> pendingSync() async {
    return _orders.values.where((o) => o.syncStatus == SyncStatus.pending).toList();
  }

  @override
  Future<void> markSynced(String id) async {
    final order = _orders[id];
    if (order == null) return;
    _orders[id] = order.copyWith(syncStatus: SyncStatus.synced, updatedAt: order.updatedAt);
  }

  @override
  Future<void> markFailed(String id, String error) async {
    final order = _orders[id];
    if (order == null) return;
    _orders[id] = order.copyWith(syncStatus: SyncStatus.failed, updatedAt: order.updatedAt);
  }

  void dispose() => _controller.close();
}
