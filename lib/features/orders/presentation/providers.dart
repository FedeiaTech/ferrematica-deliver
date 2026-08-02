import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:uuid/uuid.dart';

import '../../auth/presentation/providers.dart';
import '../../delivery/data/providers.dart' show geocodingClientProvider;
import '../data/providers.dart';
import '../domain/order.dart';
import '../domain/orders_repository.dart';

/// Forward-only lifecycle order used to reject backward status transitions.
/// `cancelado` is reachable from any of these and is terminal (no further
/// transitions once cancelled) — see spec's "Status lifecycle" requirement.
///
/// `enCamino` is inserted here at its *logical* lifecycle position (between
/// `asignado` and `entregado`), even though it is declared at the END of
/// the `OrderStatus` enum itself. [isValidTransition] indexes this list by
/// position, not the enum's ordinal, so this mid-list insertion is safe and
/// does not touch Isar's on-disk `@enumerated` ordinal storage — see design
/// decision #6 and the comment on `OrderStatus` in `order.dart`.
const List<OrderStatus> _forwardLifecycle = <OrderStatus>[
  OrderStatus.pendiente,
  OrderStatus.asignado,
  OrderStatus.enCamino,
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
    // Fire-and-forget (design decision #9): geocoding must never delay or
    // block order creation returning to the caller. Failure is swallowed
    // by [GeocodingClient] itself — see [_geocodeAndSave].
    unawaited(_geocodeAndSave(order));
  }

  /// Persists edits to an existing [order]. Callers pass the already
  /// `copyWith`-updated order; this bumps `syncStatus` back to `pending`
  /// implicitly via `copyWith`'s default in the domain model.
  ///
  /// Re-geocodes only when `deliveryAddress` actually changed from the
  /// previously-persisted row (spec: "geocode ... on order creation or
  /// edit with a changed address"), so an unrelated edit (e.g. notes,
  /// payment method) doesn't spend an unnecessary API call.
  Future<void> updateOrder(Order order) async {
    final previous = await _repository.getById(order.id);
    final updated = order.copyWith(syncStatus: SyncStatus.pending);
    await _repository.save(updated);
    if (previous == null || previous.deliveryAddress != updated.deliveryAddress) {
      unawaited(_geocodeAndSave(updated));
    }
  }

  /// Best-effort background geocode of [order]'s `deliveryAddress`,
  /// followed by a second save populating `latitude`/`longitude` if (and
  /// only if) resolution succeeded. Runs after the caller-visible save has
  /// already completed — per spec's "Geocoding does not block creation",
  /// the order is already durably persisted with null coordinates before
  /// this ever runs, so any failure here (including an unexpected throw
  /// from a misbehaving [GeocodingClient] implementation) is caught and
  /// simply results in no follow-up save.
  Future<void> _geocodeAndSave(Order order) async {
    try {
      final client = ref.read(geocodingClientProvider);
      final result = await client.geocode(order.deliveryAddress);
      if (result == null) return;
      final latest = await _repository.getById(order.id) ?? order;
      await _repository.save(
        latest.copyWith(
          latitude: result.latitude,
          longitude: result.longitude,
          syncStatus: SyncStatus.pending,
        ),
      );
    } catch (_) {
      // Never let a geocoding failure surface — the order is already
      // saved; this background step is best-effort only.
    }
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

  /// Assigns [cadeteId] to [order]. Restricted to `pendiente`/`asignado`
  /// orders per spec's order-assignment requirement — reassignment after
  /// `en_camino` must be rejected. The dueño-facing UI that calls this
  /// (`assign_cadete_sheet.dart`) lands in PR3; this method only needs to
  /// exist and enforce the invariant so PR3 can wire it without touching
  /// this file again.
  Future<void> assignCadete(Order order, String cadeteId) async {
    if (order.status != OrderStatus.pendiente &&
        order.status != OrderStatus.asignado) {
      return;
    }
    await _repository.save(
      order.copyWith(
        assignedCadeteId: cadeteId,
        status: OrderStatus.asignado,
        syncStatus: SyncStatus.pending,
      ),
    );
  }

  /// Transitions [order] from `asignado` to `en_camino`. Per spec, only the
  /// assigned cadete triggers this (by starting navigation) — the
  /// navigation screen that calls this lands in PR6; this method only
  /// needs to exist and enforce the transition invariant now.
  Future<void> startDelivery(Order order) async {
    if (!isValidTransition(order.status, OrderStatus.enCamino)) return;
    await _repository.save(
      order.copyWith(status: OrderStatus.enCamino, syncStatus: SyncStatus.pending),
    );
  }

  /// True when moving from [from] to [to] is a single forward step in the
  /// lifecycle `pendiente` → `asignado` → `en_camino` → `entregado` — per
  /// spec's "Transitions MUST NOT skip backward or skip forward steps".
  /// `cancelado` is reachable from any non-terminal status in one step;
  /// nothing is reachable from `cancelado`.
  ///
  /// **PR2 fix**: previously this only checked `toIndex > fromIndex`
  /// (monotonic-forward), which incorrectly allowed skipping a step (e.g.
  /// `pendiente` straight to `entregado`) — a latent violation of the same
  /// "MUST NOT skip forward steps" spec line that predates `en_camino`.
  /// Tightened to adjacency (`toIndex == fromIndex + 1`) while adding
  /// `en_camino` to the lifecycle, since both changes touch this exact
  /// function and no existing test relied on the skip-forward gap. Flagged
  /// for sdd-verify as a deviation beyond PR2's literal scope.
  static bool isValidTransition(OrderStatus from, OrderStatus to) {
    if (from == to) return true;
    if (from == OrderStatus.cancelado) return false;
    if (to == OrderStatus.cancelado) return true;
    final fromIndex = _forwardLifecycle.indexOf(from);
    final toIndex = _forwardLifecycle.indexOf(to);
    return toIndex == fromIndex + 1;
  }
}

final NotifierProvider<OrdersController, AsyncValue<void>>
ordersControllerProvider = NotifierProvider<OrdersController, AsyncValue<void>>(
  OrdersController.new,
);
