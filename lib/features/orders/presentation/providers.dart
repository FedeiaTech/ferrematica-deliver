import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:uuid/uuid.dart';

import '../../auth/presentation/providers.dart';
import '../data/providers.dart';
import '../domain/order.dart';
import '../domain/orders_repository.dart';

/// Forward-only lifecycle order used to reject backward status transitions.
/// `cancelado` is reachable from any of these and is terminal (no further
/// transitions once cancelled) — see spec's "Status lifecycle" requirement.
const List<OrderStatus> _forwardLifecycle = <OrderStatus>[
  OrderStatus.pendiente,
  OrderStatus.asignado,
  OrderStatus.entregado,
];

/// Currently selected list filter. `null` means "show all statuses".
final StateProvider<OrderStatus?> orderFilterProvider =
    StateProvider<OrderStatus?>((ref) => null);

/// Unfiltered, reactive stream of every non-deleted order. This is the
/// single subscription the payment-pending banner and [orderByIdProvider]
/// read from, so opening a filtered list view never hides an order that a
/// deep link (e.g. `/orders/:id`) still needs to resolve.
final StreamProvider<List<Order>> ordersStreamProvider =
    StreamProvider<List<Order>>((ref) {
      final repository = ref.watch(ordersRepositoryProvider);
      return repository.watchOrders();
    });

/// [ordersStreamProvider] filtered client-side by [orderFilterProvider], so
/// the list screen only opens a single Isar watch query regardless of which
/// filter chip is active.
final Provider<AsyncValue<List<Order>>> filteredOrdersProvider =
    Provider<AsyncValue<List<Order>>>((ref) {
      final filter = ref.watch(orderFilterProvider);
      final ordersAsync = ref.watch(ordersStreamProvider);
      return ordersAsync.whenData((orders) {
        if (filter == null) return orders;
        return orders
            .where((order) => order.status == filter)
            .toList(growable: false);
      });
    });

/// Looks up a single order by [id] from the already-watched order list,
/// so the detail/edit screens stay reactive without a second repository
/// subscription.
final orderByIdProvider = Provider.family<AsyncValue<Order?>, String>((
  ref,
  id,
) {
  final ordersAsync = ref.watch(ordersStreamProvider);
  return ordersAsync.whenData((orders) {
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  });
});

/// Owner-facing write operations for orders: create, edit, cancel, delete
/// (soft), and mark-delivered (with or without payment collected). Every
/// mutation goes through [OrdersRepository.save]/`softDelete`, which write
/// to Isar first and fire a sync attempt — the UI never awaits the network.
class OrdersController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  OrdersRepository get _repository => ref.read(ordersRepositoryProvider);

  /// Creates a new order. Only [deliveryAddress] is required — every other
  /// field is optional, matching the domain's only invariant.
  ///
  /// `createdBy` is the authenticated user's id from [sessionProvider]
  /// (design decision #4) — throws [StateError] if there is no session,
  /// since an unauthenticated create would violate the
  /// `orders.created_by → profiles.id` FK against a real project. The
  /// router guard should make this unreachable in practice (order screens
  /// only render for an authenticated dueño).
  Future<void> createOrder({
    required String deliveryAddress,
    String? clientName,
    String? clientPhone,
    String? notes,
    double? amountToCharge,
    PaymentMethod paymentMethod = PaymentMethod.sinDefinir,
    List<OrderItem> items = const <OrderItem>[],
  }) async {
    final session = ref.read(sessionProvider).value;
    if (session == null) {
      throw StateError('createOrder requires an authenticated session');
    }
    final now = DateTime.now();
    final order = Order(
      id: const Uuid().v4(),
      deliveryAddress: deliveryAddress,
      createdBy: session.userId,
      createdAt: now,
      updatedAt: now,
      clientName: clientName,
      clientPhone: clientPhone,
      notes: notes,
      amountToCharge: amountToCharge,
      paymentMethod: paymentMethod,
      items: items,
    );
    await _repository.save(order);
  }

  /// Persists edits to an existing [order]. Callers pass the already
  /// `copyWith`-updated order; this bumps `syncStatus` back to `pending`
  /// implicitly via `copyWith`'s default in the domain model.
  Future<void> updateOrder(Order order) async {
    await _repository.save(order.copyWith(syncStatus: SyncStatus.pending));
  }

  /// Cancels [order]. Allowed from any non-`cancelado` status per spec.
  Future<void> cancelOrder(Order order) async {
    if (order.status == OrderStatus.cancelado) return;
    await _repository.save(
      order.copyWith(
        status: OrderStatus.cancelado,
        syncStatus: SyncStatus.pending,
      ),
    );
  }

  /// Soft-deletes the order with [id].
  Future<void> deleteOrder(String id) async {
    await _repository.softDelete(id);
  }

  /// Marks [order] as `entregado`. [paymentStatus] MUST NOT block the
  /// transition even when it is still `pendiente` — the caller surfaces
  /// that via [Order.needsPaymentFollowUp] and the payment-pending banner,
  /// per spec's "Incomplete-order and payment-pending alerts" requirement.
  Future<void> markDelivered(
    Order order, {
    required PaymentStatus paymentStatus,
  }) async {
    if (!isValidTransition(order.status, OrderStatus.entregado)) return;
    await _repository.save(
      order.copyWith(
        status: OrderStatus.entregado,
        paymentStatus: paymentStatus,
        deliveredAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      ),
    );
  }

  /// True when moving from [from] to [to] does not skip backward in the
  /// forward-only lifecycle `pendiente` → `asignado` → `entregado`.
  /// `cancelado` is reachable from any non-terminal status; nothing is
  /// reachable from `cancelado`.
  static bool isValidTransition(OrderStatus from, OrderStatus to) {
    if (from == to) return true;
    if (from == OrderStatus.cancelado) return false;
    if (to == OrderStatus.cancelado) return true;
    final fromIndex = _forwardLifecycle.indexOf(from);
    final toIndex = _forwardLifecycle.indexOf(to);
    return toIndex > fromIndex;
  }
}

final NotifierProvider<OrdersController, AsyncValue<void>>
ordersControllerProvider = NotifierProvider<OrdersController, AsyncValue<void>>(
  OrdersController.new,
);
