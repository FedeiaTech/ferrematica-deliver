/// Pure-Dart domain model for the `pedidos` (order management) slice. No
/// Isar or Supabase imports here — the data layer maps to/from this type.
library;

/// Lifecycle of an [Order]. Forward-only progression `pendiente` →
/// `asignado` → `en_camino` → `entregado`; any state MAY transition to
/// `cancelado`.
///
/// `enCamino` is deliberately **appended** at the end of this declaration
/// instead of being declared between `asignado` and `entregado` — see
/// `navegacion-cadete` design decision #6. `OrderModel.status` in
/// `order_model.dart` is annotated `@enumerated`, which defaults to Isar's
/// `EnumType.ordinal` storage: it persists the enum's *declaration index*,
/// not its name. Inserting `enCamino` mid-declaration would silently shift
/// `entregado` from ordinal 2→3 and `cancelado` from 3→4, corrupting the
/// status of every existing local row on the next read. The *logical*
/// lifecycle position (between `asignado` and `entregado`) lives instead in
/// `providers.dart`'s `_forwardLifecycle` list, which `isValidTransition`
/// indexes by list position — not by enum ordinal — so it is free to encode
/// the real order without touching on-disk storage.
enum OrderStatus { pendiente, asignado, entregado, cancelado, enCamino }

/// How the order will be / was paid. `sinDefinir` is the default until the
/// dueño fills it in.
enum PaymentMethod { efectivo, transferencia, sinDefinir }

/// Whether the order's charge has been collected. `incobrable` is
/// deliberately **appended** at the end, not inserted after `cobrado` — see
/// `OrderStatus.enCamino`'s doc comment above for why: `OrderModel
/// .paymentStatus` is `@enumerated` (Isar's ordinal storage), so inserting
/// a value mid-declaration would silently corrupt every existing row's
/// on-disk `paymentStatus`.
enum PaymentStatus { pendiente, cobrado, incobrable }

/// Local sync state against Supabase. Lives on the row itself — see design
/// decision "Sync state on the row, not a mutation-log outbox".
enum SyncStatus { pending, synced, failed }

/// A single line item embedded in an [Order]. Not a separate entity/table —
/// see design decision on embedded items vs. an `order_items` table.
final class OrderItem {
  const OrderItem({
    required this.productName,
    required this.quantity,
    this.sourceVentaId,
  });

  final String productName;
  final int quantity;

  /// The `ventas.id` this line was prefilled from via `_pickVenta`
  /// (order_form_screen.dart), or `null` for a manually-added/free-form
  /// line. A venta-sourced item mirrors an actual completed POS sale, so
  /// the order form locks its quantity/removal controls when this is set —
  /// only a manual line stays freely editable.
  final String? sourceVentaId;

  OrderItem copyWith({String? productName, int? quantity}) {
    return OrderItem(
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      sourceVentaId: sourceVentaId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderItem &&
        other.productName == productName &&
        other.quantity == quantity &&
        other.sourceVentaId == sourceVentaId;
  }

  @override
  int get hashCode => Object.hash(productName, quantity, sourceVentaId);
}

/// The order aggregate. Only [deliveryAddress] is required; every other
/// field is nullable or defaulted so a dueño can create an order with the
/// bare minimum and fill in the rest later.
final class Order {
  Order({
    required this.id,
    required this.deliveryAddress,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.resolvedCity,
    this.clientName,
    this.clientPhone,
    this.notes,
    this.assignedCadeteId,
    this.amountToCharge,
    this.paymentMethod = PaymentMethod.sinDefinir,
    this.paymentStatus = PaymentStatus.pendiente,
    this.status = OrderStatus.pendiente,
    this.items = const <OrderItem>[],
    this.syncStatus = SyncStatus.pending,
    this.deliveredAt,
    this.deletedAt,
    this.deliveryProblem,
    this.pendingBalance,
    this.valorEnvio,
    this.envioPendingBalance,
    this.retriedFromOrderId,
    this.incobrableAt,
    this.incobrableReason,
  }) : assert(
         deliveryAddress.trim().isNotEmpty,
         'deliveryAddress must not be empty',
       ),
       assert(
         pendingBalance == null ||
             ((paymentStatus == PaymentStatus.cobrado ||
                     paymentStatus == PaymentStatus.incobrable) &&
                 pendingBalance > 0 &&
                 amountToCharge != null &&
                 pendingBalance < amountToCharge),
         'pendingBalance must be null, or a strict partial of amountToCharge on a cobrado/incobrable order',
       ),
       assert(
         envioPendingBalance == null ||
             (valorEnvio != null && envioPendingBalance > 0 && envioPendingBalance <= valorEnvio),
         'envioPendingBalance must be null, or a partial (up to and including the full amount) of valorEnvio',
       );

  final String id;
  final String deliveryAddress;
  final double? latitude;
  final double? longitude;
  /// The delivery city, resolved by reverse-geocoding [latitude]/
  /// [longitude] once they're known — the ground truth of where the pin
  /// actually landed, not the city hint the dueño picked in the order form
  /// to disambiguate the forward geocoding search (that hint is transient
  /// form state, never persisted).
  final String? resolvedCity;
  final String? clientName;
  final String? clientPhone;
  final String? notes;
  final String? assignedCadeteId;
  final String createdBy;
  final double? amountToCharge;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final OrderStatus status;
  final List<OrderItem> items;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deliveredAt;
  final DateTime? deletedAt;
  /// Reason the assigned cadete (or dueño, for a self-delivery) couldn't
  /// complete this delivery — set by [OrdersController.reportDeliveryProblem],
  /// which also moves [status] to `cancelado`. `null` for every order that
  /// hasn't had a delivery problem reported against it.
  final String? deliveryProblem;

  /// Amount still owed on a `cobrado` order after a partial collection.
  /// `null` means either the order isn't `cobrado` yet, or it was
  /// collected in full. When non-null, it is strictly between `0` and
  /// [amountToCharge] — enforced by the constructor assert below and by
  /// the `orders_pending_balance_valido` CHECK constraint in Supabase.
  final double? pendingBalance;

  /// Delivery fee, entered separately from [amountToCharge] (the goods'
  /// price) — optional, `null` until the dueño/cadete fills it in. Kept
  /// entirely outside the `amountToCharge`/`pendingBalance` invariants: the
  /// delivery fee is not part of what's "cobrado" on the sale, it's a
  /// display-only addend for the Subtotal/Envío/Total breakdown (design:
  /// "el valor total no es necesario registrarlo en la factura").
  final double? valorEnvio;

  /// Amount still owed on [valorEnvio] after a partial (or nil) collection
  /// of the delivery fee. `null` means either there's no delivery fee at
  /// all ([valorEnvio] is `null`), or it was collected in full. When
  /// non-null, it is between `0` (exclusive) and [valorEnvio] (inclusive)
  /// — enforced by the constructor assert above and by the
  /// `orders_envio_pending_balance_valido` CHECK constraint in Supabase.
  /// Unlike [pendingBalance], the upper bound is inclusive: there is no
  /// separate "pendiente" status for the delivery fee, so "nothing
  /// collected yet" is represented as `envioPendingBalance == valorEnvio`.
  final double? envioPendingBalance;

  /// The `id` of the cancelled order this one was created FROM, via
  /// "Reintentar entrega" (`order_form_screen.dart`'s `prefillFrom`) —
  /// `null` for every order created any other way. Never cleared once set:
  /// a retry-of-a-retry keeps pointing at its own immediate predecessor,
  /// not the original — walk the chain backwards (`retriedFromOrderId` →
  /// that order's own `retriedFromOrderId` → ...) to reach the very first
  /// attempt. Purely a display/navigation aid (`order_detail_screen.dart`
  /// links to it); no FK server-side, same rationale as
  /// `venta_order_links.order_id` in `0011_ventas_mirror.sql` — the
  /// referenced order may not have synced to Supabase yet.
  final String? retriedFromOrderId;

  /// Set once, by `OrdersController.markIncobrable`, when the dueño writes
  /// off an entregado order's outstanding debt as uncollectible — either
  /// the remainder of a partial collection (`pendingBalance` stays set, as
  /// a historical record of what was forgiven) or a delivery that never
  /// collected anything at all. Final: there is no "undo" action, matching
  /// this codebase's other one-way claims (`venta_order_links`,
  /// `deliveryProblem`). `null` for every order that hasn't been written
  /// off.
  final DateTime? incobrableAt;

  /// Optional free-text note captured alongside [incobrableAt] — why the
  /// debt was written off. Never required, never cleared once set.
  final String? incobrableReason;

  /// True when [latitude]/[longitude] are both present AND finite,
  /// in-range geographic values — rejects the NaN/Infinity/out-of-range
  /// coordinate a bad geocode result can occasionally produce (observed on
  /// a real device: a malformed pair reaching `flutter_map`'s
  /// `CameraFit`/`TileLayer` crashes the whole render pipeline, since that
  /// failure surfaces from *inside* an animation frame callback, outside
  /// any synchronous try/catch around the call that triggered it — see
  /// `order_detail_screen.dart`'s `_OrderRouteMapPreview` and
  /// `navigation_map_screen.dart`, the two places that gate on this before
  /// ever constructing a map widget from this order's coordinates).
  bool get hasValidCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;

  /// True when the dueño hasn't finished filling in payment details yet.
  bool get isIncomplete =>
      amountToCharge == null || paymentMethod == PaymentMethod.sinDefinir;

  /// True when the delivery fee is either absent or fully collected — i.e.
  /// there is nothing still owed on [valorEnvio]. Drives the "Envíos" stat
  /// in `delivery_stats_screen.dart`, which must only count a fee once it's
  /// actually in hand.
  bool get envioFullyCollected => valorEnvio == null || envioPendingBalance == null;

  /// True when the order was marked delivered but money is still owed —
  /// either nothing was collected yet, or only part of it was. Drives the
  /// dueño-facing alert banner, follow-up counters, and whether "Marcar
  /// incobrable" is offered (`order_detail_screen.dart`). `false` once
  /// [paymentStatus] is `incobrable` — that debt has already been resolved
  /// (by write-off, not collection), so it must stop being chased.
  bool get needsPaymentFollowUp =>
      paymentStatus != PaymentStatus.incobrable &&
      ((status == OrderStatus.entregado && paymentStatus == PaymentStatus.pendiente) ||
          pendingBalance != null);

  /// Returns a copy of this order with the given fields replaced.
  /// [updatedAt] always advances to `DateTime.now()` (or [updatedAt] if
  /// explicitly provided) — callers must not silently leave a stale
  /// timestamp after a mutation, since LWW sync relies on it.
  ///
  /// Every nullable field here can only be *set* or *kept*, never cleared,
  /// EXCEPT [latitude]/[longitude]/[resolvedCity] when [clearCoordinates]
  /// is `true` (needed so a re-geocode that fails after an address edit
  /// drops the OLD address's stale pin instead of silently leaving it
  /// pointing at a place that no longer matches [deliveryAddress]) and
  /// [assignedCadeteId] when [clearAssignedCadeteId] is `true` (needed for
  /// [OrdersController.unassignCadete] to send an order back to `pendiente`
  /// with no one on the hook for it), [pendingBalance] when
  /// [clearPendingBalance] is `true` (needed to mark a partial payment as
  /// fully collected without leaving the old balance behind), and
  /// [envioPendingBalance] when [clearEnvioPendingBalance] is `true` (same
  /// need, but for the delivery fee), and [notes] when [clearNotes] is
  /// `true` (needed so the "Editar nota" quick action on an `en_camino`
  /// order — `order_detail_screen.dart` — can blank an existing note
  /// instead of only ever replacing it with different non-empty text).
  Order copyWith({
    String? deliveryAddress,
    double? latitude,
    double? longitude,
    String? resolvedCity,
    bool clearCoordinates = false,
    String? clientName,
    String? clientPhone,
    String? notes,
    bool clearNotes = false,
    String? assignedCadeteId,
    bool clearAssignedCadeteId = false,
    double? amountToCharge,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    OrderStatus? status,
    List<OrderItem>? items,
    SyncStatus? syncStatus,
    DateTime? updatedAt,
    DateTime? deliveredAt,
    DateTime? deletedAt,
    String? deliveryProblem,
    double? pendingBalance,
    bool clearPendingBalance = false,
    double? valorEnvio,
    bool clearValorEnvio = false,
    double? envioPendingBalance,
    bool clearEnvioPendingBalance = false,
    DateTime? incobrableAt,
    String? incobrableReason,
  }) {
    return Order(
      id: id,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      resolvedCity: clearCoordinates ? null : (resolvedCity ?? this.resolvedCity),
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      notes: clearNotes ? null : (notes ?? this.notes),
      assignedCadeteId: clearAssignedCadeteId
          ? null
          : (assignedCadeteId ?? this.assignedCadeteId),
      amountToCharge: amountToCharge ?? this.amountToCharge,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      items: items ?? this.items,
      syncStatus: syncStatus ?? this.syncStatus,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deliveryProblem: deliveryProblem ?? this.deliveryProblem,
      pendingBalance: clearPendingBalance ? null : (pendingBalance ?? this.pendingBalance),
      valorEnvio: clearValorEnvio ? null : (valorEnvio ?? this.valorEnvio),
      envioPendingBalance: clearEnvioPendingBalance
          ? null
          : (envioPendingBalance ?? this.envioPendingBalance),
      // Set once at creation only, in `OrdersController.createOrder` — no
      // param to overwrite it here, just carried through every mutation
      // unchanged (a bug fixed alongside adding `incobrableAt`/
      // `incobrableReason` below: this line was missing entirely, so any
      // `copyWith` call — e.g. `reportDeliveryProblem` cancelling a retry
      // order — silently dropped its retry-chain link).
      retriedFromOrderId: retriedFromOrderId,
      incobrableAt: incobrableAt ?? this.incobrableAt,
      incobrableReason: incobrableReason ?? this.incobrableReason,
    );
  }
}
