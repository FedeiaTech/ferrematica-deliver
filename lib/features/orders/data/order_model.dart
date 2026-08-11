import 'package:isar_community/isar.dart';

import '../domain/order.dart';

part 'order_model.g.dart';

/// Isar-persisted representation of [Order]. Maps 1:1 to the domain model;
/// `isar_module.dart` registers [OrderModelSchema] alongside the app's other
/// collections.
///
/// `id` (the client-generated UUID, the real business key) carries a
/// unique+replace index so pulling the same remote row twice updates in
/// place instead of duplicating. Isar's own `Id` (`isarId`) is derived from
/// it via [fastHash] since Isar requires an `int` primary key.
@collection
class OrderModel {
  OrderModel({
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
    this.items = const <OrderItemModel>[],
    this.syncStatus = SyncStatus.pending,
    this.deliveredAt,
    this.deletedAt,
    this.deliveryProblem,
    this.pendingBalance,
    this.valorEnvio,
  });

  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  final String id;

  final String deliveryAddress;
  final double? latitude;
  final double? longitude;
  final String? resolvedCity;
  final String? clientName;
  final String? clientPhone;
  final String? notes;
  final String? assignedCadeteId;
  final String createdBy;
  final double? amountToCharge;

  @enumerated
  final PaymentMethod paymentMethod;

  @enumerated
  final PaymentStatus paymentStatus;

  @Index()
  @enumerated
  final OrderStatus status;

  final List<OrderItemModel> items;

  @Index()
  @enumerated
  final SyncStatus syncStatus;

  @Index()
  final DateTime updatedAt;

  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? deletedAt;
  final String? deliveryProblem;

  /// Mirrors [Order.pendingBalance]. Purely additive nullable property —
  /// no `@enumerated`, no schema-version bump. See design decision DA1.
  final double? pendingBalance;

  /// Mirrors [Order.valorEnvio]. Purely additive nullable property — no
  /// `@enumerated`, no schema-version bump, same shape as [pendingBalance].
  final double? valorEnvio;
}

/// Embedded line item — part of the [OrderModel] row itself, not a separate
/// collection. See design decision "items as embedded objects, not an
/// order_items table".
@embedded
class OrderItemModel {
  OrderItemModel({this.productName = '', this.quantity = 0, this.sourceVentaId});

  final String productName;
  final int quantity;
  final String? sourceVentaId;
}

/// Maps a domain [Order] to its Isar row representation.
OrderModel orderToModel(Order order) {
  return OrderModel(
    id: order.id,
    deliveryAddress: order.deliveryAddress,
    createdBy: order.createdBy,
    createdAt: order.createdAt,
    updatedAt: order.updatedAt,
    latitude: order.latitude,
    longitude: order.longitude,
    resolvedCity: order.resolvedCity,
    clientName: order.clientName,
    clientPhone: order.clientPhone,
    notes: order.notes,
    assignedCadeteId: order.assignedCadeteId,
    amountToCharge: order.amountToCharge,
    paymentMethod: order.paymentMethod,
    paymentStatus: order.paymentStatus,
    status: order.status,
    items: order.items
        .map(
          (item) => OrderItemModel(
            productName: item.productName,
            quantity: item.quantity,
            sourceVentaId: item.sourceVentaId,
          ),
        )
        .toList(growable: false),
    syncStatus: order.syncStatus,
    deliveredAt: order.deliveredAt,
    deletedAt: order.deletedAt,
    deliveryProblem: order.deliveryProblem,
    pendingBalance: order.pendingBalance,
    valorEnvio: order.valorEnvio,
  );
}

/// Maps an Isar [OrderModel] row back to the domain [Order].
Order orderModelToDomain(OrderModel model) {
  return Order(
    id: model.id,
    deliveryAddress: model.deliveryAddress,
    createdBy: model.createdBy,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
    latitude: model.latitude,
    longitude: model.longitude,
    resolvedCity: model.resolvedCity,
    clientName: model.clientName,
    clientPhone: model.clientPhone,
    notes: model.notes,
    assignedCadeteId: model.assignedCadeteId,
    amountToCharge: model.amountToCharge,
    paymentMethod: model.paymentMethod,
    paymentStatus: model.paymentStatus,
    status: model.status,
    items: model.items
        .map(
          (item) => OrderItem(
            productName: item.productName,
            quantity: item.quantity,
            sourceVentaId: item.sourceVentaId,
          ),
        )
        .toList(growable: false),
    syncStatus: model.syncStatus,
    deliveredAt: model.deliveredAt,
    deletedAt: model.deletedAt,
    deliveryProblem: model.deliveryProblem,
    pendingBalance: model.pendingBalance,
    valorEnvio: model.valorEnvio,
  );
}

/// FNV-1a 64-bit hash truncated to a signed 64-bit int, used to derive
/// Isar's required `int` id from the business-key `String id`. Standard
/// community-recommended implementation (not exported by `isar_community`).
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash;
}
