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

/// Currently selected list filter — the set of statuses to show. Defaults
/// to every status ("Todos"), so nothing is filtered out until the dueño
/// deselects something from the status filter menu.
final StateProvider<Set<OrderStatus>> orderFilterProvider = StateProvider<Set<OrderStatus>>(
  (ref) => OrderStatus.values.toSet(),
);

/// Extra toggle in the status filter menu, independent of [orderFilterProvider]:
/// when `true`, only orders [isOrderUnassigned] applies to are shown. Every
/// new order is auto-assigned to the dueño at creation (see `createOrder`
/// below), so `asignado` alone can't tell "actually handed to a cadete"
/// apart from "still sitting on the dueño's own plate" — this toggle
/// surfaces the latter.
final StateProvider<bool> orderShowOnlyUnassignedProvider = StateProvider<bool>(
  (ref) => false,
);

/// True when [order] is `asignado` but [cadeteIds] (the real cadete roster,
/// from [cadeteListProvider]) doesn't contain its `assignedCadeteId` — i.e.
/// it's still on the dueño's default self-assignment from `createOrder`,
/// not actually handed off to a cadete.
bool isOrderUnassigned(Order order, Set<String> cadeteIds) =>
    order.status == OrderStatus.asignado &&
    !cadeteIds.contains(order.assignedCadeteId);

/// Fire-and-forget backfill for `resolvedCity` on orders that already have
/// coordinates but predate that field (or whose reverse-geocode attempt
/// previously failed) — no-ops instantly if the order isn't missing it.
/// `OrderDetailScreen` watches this once per `orderId`; Riverpod caches the
/// family instance per key, so re-opening the same order's detail screen
/// doesn't re-fire it once it succeeds (the saved order then has a
/// non-null `resolvedCity` and the early return short-circuits).
final resolvedCityBackfillProvider = FutureProvider.family<void, String>((
  ref,
  orderId,
) async {
  final repository = ref.read(ordersRepositoryProvider);
  final order = await repository.getById(orderId);
  if (order == null) return;
  if (order.latitude == null || order.longitude == null) return;
  if (order.resolvedCity != null) return;

  final client = ref.read(geocodingClientProvider);
  final city = await client.reverseGeocodeCity(order.latitude!, order.longitude!);
  if (city == null) return;

  final latest = await repository.getById(orderId) ?? order;
  if (latest.resolvedCity != null) return;
  await repository.save(latest.copyWith(resolvedCity: city, syncStatus: SyncStatus.pending));
});

/// Predefined cities used to disambiguate geocoding queries against
/// same-named streets elsewhere in Argentina — e.g. "Candioti" exists in
/// more than one place, and without a city hint Nominatim can return the
/// wrong one. The order form appends the selected city to the address
/// before it's sent to [GeocodingClient.geocode]. Seeded with the towns
/// Ferrematica actually operates in; the dueño can add more from the form.
final StateProvider<List<String>> geocodingCitiesProvider = StateProvider<List<String>>(
  (ref) => const ['Santo Tomé, Santa Fe', 'Santa Fe, Santa Fe', 'Paraná, Entre Ríos'],
);

/// Currently selected city hint for the order form — defaults to Santo
/// Tomé, where the dueño's business operates.
final StateProvider<String> selectedGeocodingCityProvider = StateProvider<String>(
  (ref) => 'Santo Tomé, Santa Fe',
);

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
      final onlyUnassigned = ref.watch(orderShowOnlyUnassignedProvider);
      final ordersAsync = ref.watch(ordersStreamProvider);
      final cadeteIds = ref
          .watch(cadeteListProvider)
          .maybeWhen(
            data: (cadetes) => cadetes.map((cadete) => cadete.id).toSet(),
            orElse: () => const <String>{},
          );
      return ordersAsync.whenData((orders) {
        Iterable<Order> result = orders;
        if (filter.length != OrderStatus.values.length) {
          result = result.where((order) => filter.contains(order.status));
        }
        if (onlyUnassigned) {
          result = result.where((order) => isOrderUnassigned(order, cadeteIds));
        }
        return result.toList(growable: false);
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
  ///
  /// [fromVentaIds] (`sdd/ventas-sync-envio` design decision D4,
  /// claim-before-create, extended to support bundling several sales into
  /// one delivery): each `venta_order_links` row is written FIRST, in
  /// order, using the client-generated order id below — only once every
  /// claim succeeds does the order itself get saved locally. A concurrent
  /// claim on any of these ventas from another device surfaces as
  /// [VentaYaVinculadaException] and this method throws without saving
  /// anything, so the caller (order_form_screen.dart) never ends up with an
  /// order that silently lost a venta link.
  ///
  /// A claim already written earlier in this same loop is NOT rolled back
  /// on a later failure — `venta_order_links` rows are never
  /// deleted/broken once written (design decision D8), so there is no
  /// "unclaim" to call. That earlier-claimed venta stays linked to an
  /// [orderId] that will never be saved and simply won't reappear in the
  /// picker again; the caller clears the whole venta selection and has the
  /// dueño re-pick, same recovery shape as the single-venta case already
  /// had.
  Future<void> createOrder({
    required String deliveryAddress,
    String? clientName,
    String? clientPhone,
    String? notes,
    double? amountToCharge,
    double? valorEnvio,
    PaymentMethod paymentMethod = PaymentMethod.efectivo,
    List<OrderItem> items = const <OrderItem>[],
    String? cityHint,
    List<String> fromVentaIds = const <String>[],
  }) async {
    final session = ref.read(sessionProvider).value;
    if (session == null) {
      throw StateError('createOrder requires an authenticated session');
    }
    final orderId = const Uuid().v4();
    for (final ventaId in fromVentaIds) {
      await ref
          .read(ventasRemoteProvider)
          .claimVenta(ventaId: ventaId, orderId: orderId, createdBy: session.userId);
    }
    final now = DateTime.now();
    final order = Order(
      id: orderId,
      deliveryAddress: deliveryAddress,
      createdBy: session.userId,
      createdAt: now,
      updatedAt: now,
      clientName: clientName,
      clientPhone: clientPhone,
      notes: notes,
      amountToCharge: amountToCharge,
      valorEnvio: valorEnvio,
      paymentMethod: paymentMethod,
      items: items,
    );
    await _repository.save(order);
    // Fire-and-forget (design decision #9): geocoding must never delay or
    // block order creation returning to the caller. Failure is swallowed
    // by [GeocodingClient] itself — see [_geocodeAndSave].
    unawaited(_geocodeAndSave(order, cityHint: cityHint));
    // Auto-assign every new order to the dueño themselves ("Base" in
    // assign_cadete_sheet.dart) — this business has no cadete accounts
    // yet, so defaulting to self-delivery means the order form's "Nuevo
    // pedido" flow never leaves an order sitting unassigned needing an
    // extra "Asignar cadete" tap; the detail screen already only offers
    // "Reasignar cadete" once assignedCadeteId is set, so this is a pure
    // default, not a dead-end — a real cadete can still take over later.
    //
    // Deliberately saved directly as `asignado`, NOT routed through
    // [assignCadete] (whose self-delivery case jumps straight to
    // `en_camino`) — that jump is meant for the dueño *actively* picking
    // "Base" mid-flow to start delivering right now, not for this passive
    // default at creation time. Jumping to `en_camino` here would hide
    // "Reasignar cadete" immediately (only offered while
    // pendiente/asignado), making a fresh order impossible to hand off to
    // a real cadete before the dueño heads out.
    await _repository.save(
      order.copyWith(
        assignedCadeteId: session.userId,
        status: OrderStatus.asignado,
        syncStatus: SyncStatus.pending,
      ),
    );
  }

  /// Persists edits to an existing [order]. Callers pass the already
  /// `copyWith`-updated order; this bumps `syncStatus` back to `pending`
  /// implicitly via `copyWith`'s default in the domain model.
  ///
  /// Re-geocodes when `deliveryAddress` actually changed from the
  /// previously-persisted row (spec: "geocode ... on order creation or
  /// edit with a changed address"), so an unrelated edit (e.g. notes,
  /// payment method) doesn't spend an unnecessary API call — or when
  /// [forceRegeocode] is set, which the form passes when the dueño changed
  /// the city selector (`_CitySelector` in `order_form_screen.dart`)
  /// without touching the address text itself. The order doesn't persist
  /// which city hint produced its current coordinates, so an unchanged
  /// address can still need a fresh geocode if the disambiguating city
  /// did change.
  Future<void> updateOrder(
    Order order, {
    String? cityHint,
    bool forceRegeocode = false,
  }) async {
    final previous = await _repository.getById(order.id);
    final updated = order.copyWith(syncStatus: SyncStatus.pending);
    await _repository.save(updated);
    if (forceRegeocode ||
        previous == null ||
        previous.deliveryAddress != updated.deliveryAddress) {
      unawaited(_geocodeAndSave(updated, cityHint: cityHint));
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
  ///
  /// A failed geocode explicitly CLEARS any previously-saved coordinates
  /// (via `copyWith(clearCoordinates: true)`) rather than leaving them
  /// untouched — otherwise an edit that changed the address to something
  /// unresolvable would silently keep showing the OLD address's pin,
  /// which now points at the wrong place. A fresh create has no previous
  /// coordinates, so this is a no-op in that case.
  /// Manually overrides [order]'s coordinates — the reliable fallback for
  /// when geocoding gets it wrong (a common source of error: a street
  /// corner without a house number, per `HttpGeocodingClient`'s
  /// intersection approximation) via `location_picker_screen.dart`'s
  /// tap-to-place map. Also re-attempts reverse geocoding the delivery
  /// city for the corrected point, best-effort.
  Future<void> setManualLocation(
    Order order, {
    required double latitude,
    required double longitude,
  }) async {
    final client = ref.read(geocodingClientProvider);
    final city = await client.reverseGeocodeCity(latitude, longitude);
    final latest = await _repository.getById(order.id) ?? order;
    await _repository.save(
      latest.copyWith(
        latitude: latitude,
        longitude: longitude,
        resolvedCity: city,
        syncStatus: SyncStatus.pending,
      ),
    );
  }

  Future<void> _geocodeAndSave(Order order, {String? cityHint}) async {
    try {
      final client = ref.read(geocodingClientProvider);
      final query = cityHint == null || cityHint.trim().isEmpty
          ? order.deliveryAddress
          : '${order.deliveryAddress}, $cityHint';
      final result = await client.geocode(query);
      if (result == null) {
        final latest = await _repository.getById(order.id) ?? order;
        if (latest.latitude != null || latest.longitude != null) {
          await _repository.save(
            latest.copyWith(clearCoordinates: true, syncStatus: SyncStatus.pending),
          );
        }
        return;
      }
      // Best-effort: the delivery city shown in order detail comes from
      // reverse-geocoding the resolved pin itself, not the forward-search
      // city hint — a failure here still leaves the coordinates saved.
      final city = await client.reverseGeocodeCity(result.latitude, result.longitude);
      final latest = await _repository.getById(order.id) ?? order;
      await _repository.save(
        latest.copyWith(
          latitude: result.latitude,
          longitude: result.longitude,
          resolvedCity: city,
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

  /// Records why a delivery couldn't be completed — shown next to "Marcar
  /// entregado" for the same order (both the assigned cadete and a
  /// self-delivery dueño). Moves the order to `cancelado`, same terminal
  /// state as a dueño-initiated cancellation, since a failed delivery
  /// isn't going to be retried automatically. Allowed from any
  /// non-`cancelado` status, same guard as [cancelOrder].
  Future<void> reportDeliveryProblem(Order order, {required String reason}) async {
    if (order.status == OrderStatus.cancelado) return;
    await _repository.save(
      order.copyWith(
        status: OrderStatus.cancelado,
        deliveryProblem: reason,
        syncStatus: SyncStatus.pending,
      ),
    );
  }

  /// Marks [order] as `entregado`. [paymentStatus] MUST NOT block the
  /// transition even when it is still `pendiente` — the caller surfaces
  /// that via [Order.needsPaymentFollowUp] and the payment-pending banner,
  /// per spec's "Incomplete-order and payment-pending alerts" requirement.
  ///
  /// [pendingBalance] carries the still-owed amount for a partial
  /// collection ("Cobro parcial" in `_openMarkDeliveredSheet`) — `null`
  /// means either nothing was collected yet or it was collected in full.
  /// The clear case is explicit via `clearPendingBalance:
  /// pendingBalance == null` so `copyWith`'s `?? this.pendingBalance`
  /// default can never leave a stale balance behind when this method is
  /// called again (e.g. settling a previously-partial delivery in full).
  Future<void> markDelivered(
    Order order, {
    required PaymentStatus paymentStatus,
    double? pendingBalance,
  }) async {
    if (!isValidTransition(order.status, OrderStatus.entregado)) return;
    await _repository.save(
      order.copyWith(
        status: OrderStatus.entregado,
        paymentStatus: paymentStatus,
        pendingBalance: pendingBalance,
        clearPendingBalance: pendingBalance == null,
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
  ///
  /// Self-delivery ("Base" in assign_cadete_sheet.dart — `cadeteId` is the
  /// dueño's own session id) skips `asignado` and lands straight on
  /// `en_camino`: there's no separate person to hand the order off to, so
  /// making the dueño tap a second "Iniciar navegación" button to start
  /// navigating their own delivery is friction with no purpose.
  Future<void> assignCadete(Order order, String cadeteId) async {
    if (order.status != OrderStatus.pendiente &&
        order.status != OrderStatus.asignado) {
      return;
    }
    final isSelfDelivery = ref.read(sessionProvider).value?.userId == cadeteId;
    await _repository.save(
      order.copyWith(
        assignedCadeteId: cadeteId,
        status: isSelfDelivery ? OrderStatus.enCamino : OrderStatus.asignado,
        syncStatus: SyncStatus.pending,
      ),
    );
  }

  /// Reverses [assignCadete]: clears whoever (or "Base", the dueño's own
  /// self-delivery default from [createOrder]) is on the hook for [order]
  /// and sends it back to `pendiente`. Only valid from `asignado` — same
  /// restriction as [assignCadete] itself, since once `en_camino` the
  /// cadete may already be en route. Covers the case a dueño flagged: a
  /// pedido that turns out nobody should deliver (yet) needs a way out of
  /// the auto-assigned "Base" default besides picking another cadete.
  Future<void> unassignCadete(Order order) async {
    if (order.status != OrderStatus.asignado) return;
    await _repository.save(
      order.copyWith(
        status: OrderStatus.pendiente,
        clearAssignedCadeteId: true,
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
