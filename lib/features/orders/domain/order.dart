/// Pure-Dart domain model for the `pedidos` (order management) slice. No
/// Isar or Supabase imports here — the data layer maps to/from this type.
library;

/// Lifecycle of an [Order]. Forward-only progression `pendiente` →
/// `asignado` → `entregado`; any state MAY transition to `cancelado`.
/// Deliberately excludes `en_camino` for this slice (decision #1).
enum OrderStatus { pendiente, asignado, entregado, cancelado }

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
  const OrderItem({required this.productName, required this.quantity});

  final String productName;
  final int quantity;

  OrderItem copyWith({String? productName, int? quantity}) {
    return OrderItem(
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderItem &&
        other.productName == productName &&
        other.quantity == quantity;
  }

  @override
  int get hashCode => Object.hash(productName, quantity);
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
  }) : assert(
         deliveryAddress.trim().isNotEmpty,
         'deliveryAddress must not be empty',
       );

  final String id;
  final String deliveryAddress;
  final double? latitude;
  final double? longitude;
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

  /// True when the dueño hasn't finished filling in payment details yet.
  bool get isIncomplete =>
      amountToCharge == null || paymentMethod == PaymentMethod.sinDefinir;

  /// True when the order was marked delivered but the charge is still
  /// pending — this drives the dueño-facing alert banner.
  bool get needsPaymentFollowUp =>
      status == OrderStatus.entregado && paymentStatus == PaymentStatus.pendiente;

  /// Returns a copy of this order with the given fields replaced.
  /// [updatedAt] always advances to `DateTime.now()` (or [updatedAt] if
  /// explicitly provided) — callers must not silently leave a stale
  /// timestamp after a mutation, since LWW sync relies on it.
  Order copyWith({
    String? deliveryAddress,
    double? latitude,
    double? longitude,
    String? clientName,
    String? clientPhone,
    String? notes,
    String? assignedCadeteId,
    double? amountToCharge,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    OrderStatus? status,
    List<OrderItem>? items,
    SyncStatus? syncStatus,
    DateTime? updatedAt,
    DateTime? deliveredAt,
    DateTime? deletedAt,
  }) {
    return Order(
      id: id,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      notes: notes ?? this.notes,
      assignedCadeteId: assignedCadeteId ?? this.assignedCadeteId,
      amountToCharge: amountToCharge ?? this.amountToCharge,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      items: items ?? this.items,
      syncStatus: syncStatus ?? this.syncStatus,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
