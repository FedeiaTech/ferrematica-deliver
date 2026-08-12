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

/// Whether the order's charge has been collected.
enum PaymentStatus { pendiente, cobrado }

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
  }) : assert(
         deliveryAddress.trim().isNotEmpty,
         'deliveryAddress must not be empty',
       ),
       assert(
         pendingBalance == null ||
             (paymentStatus == PaymentStatus.cobrado &&
                 pendingBalance > 0 &&
                 amountToCharge != null &&
                 pendingBalance < amountToCharge),
         'pendingBalance must be null, or a strict partial of amountToCharge on a cobrado order',
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

  /// True when the dueño hasn't finished filling in payment details yet.
  bool get isIncomplete =>
      amountToCharge == null || paymentMethod == PaymentMethod.sinDefinir;

  /// True when the order was marked delivered but money is still owed —
  /// either nothing was collected yet, or only part of it was. Drives the
  /// dueño-facing alert banner and follow-up counters.
  bool get needsPaymentFollowUp =>
      (status == OrderStatus.entregado && paymentStatus == PaymentStatus.pendiente) ||
      pendingBalance != null;

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
  /// with no one on the hook for it) and [pendingBalance] when
  /// [clearPendingBalance] is `true` (needed to mark a partial payment as
  /// fully collected without leaving the old balance behind).
  Order copyWith({
    String? deliveryAddress,
    double? latitude,
    double? longitude,
    String? resolvedCity,
    bool clearCoordinates = false,
    String? clientName,
    String? clientPhone,
    String? notes,
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
      notes: notes ?? this.notes,
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
    );
  }
}
