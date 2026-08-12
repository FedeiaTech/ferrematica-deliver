import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/order.dart';

/// Port over the `orders` Supabase table. Wraps only the vendor
/// [SupabaseClient] calls this feature needs, so [OrderSyncService] tests
/// mock **this** interface with `mocktail` instead of faking the vendor SDK
/// directly (design decision #7 — vendor surfaces aren't exercised in unit
/// tests, only our own port interfaces).
abstract interface class OrdersRemote {
  /// Upserts [order] into `orders` (`on_conflict: id`) and returns the row
  /// Supabase reports after the write.
  ///
  /// The server-side `orders_reject_stale_update` trigger enforces
  /// last-write-wins: if `order.updatedAt` is not strictly newer than the
  /// row currently stored, the trigger silently discards the write and the
  /// trigger's `RETURN OLD` means the upsert echoes back the row's
  /// pre-existing state instead of [order]. Callers detect this by
  /// comparing the returned row's `updatedAt` against what they sent — a
  /// mismatch means the push was rejected as stale.
  Future<Order> upsert(Order order);

  /// Returns all rows with `updated_at > since`, ordered by `updated_at`
  /// ascending. Used by the pull side of sync.
  Future<List<Order>> fetchSince(DateTime since);
}

/// [OrdersRemote] backed by the real `supabase_flutter` client.
class SupabaseOrdersRemote implements OrdersRemote {
  SupabaseOrdersRemote(this._client);

  final SupabaseClient _client;

  static const String _table = 'orders';

  @override
  Future<Order> upsert(Order order) async {
    final row = await _client
        .from(_table)
        .upsert(toRow(order), onConflict: 'id')
        .select()
        .single();
    return fromRow(row);
  }

  @override
  Future<List<Order>> fetchSince(DateTime since) async {
    final rows = await _client
        .from(_table)
        .select()
        .gt('updated_at', since.toUtc().toIso8601String())
        .order('updated_at');
    return rows.map((row) => fromRow(row)).toList(growable: false);
  }

  /// Maps a domain [Order] to its `orders` row shape. Not underscore-private
  /// so `pending_balance` (migration 0013) round-trip mapping can be
  /// unit-tested directly, matching the [statusToRow]/[statusFromRow]
  /// precedent.
  @visibleForTesting
  static Map<String, dynamic> toRow(Order order) => <String, dynamic>{
    'id': order.id,
    'created_by': order.createdBy,
    'assigned_cadete_id': order.assignedCadeteId,
    'delivery_address': order.deliveryAddress,
    'latitude': order.latitude,
    'longitude': order.longitude,
    'resolved_city': order.resolvedCity,
    'client_name': order.clientName,
    'client_phone': order.clientPhone,
    'notes': order.notes,
    'amount_to_charge': order.amountToCharge,
    'payment_method': _paymentMethodToRow(order.paymentMethod),
    'payment_status': _paymentStatusToRow(order.paymentStatus),
    'status': SupabaseOrdersRemote.statusToRow(order.status),
    'items': order.items
        .map(
          (item) => <String, dynamic>{
            'product_name': item.productName,
            'quantity': item.quantity,
            'source_venta_id': item.sourceVentaId,
          },
        )
        .toList(growable: false),
    'created_at': order.createdAt.toUtc().toIso8601String(),
    'updated_at': order.updatedAt.toUtc().toIso8601String(),
    'delivered_at': order.deliveredAt?.toUtc().toIso8601String(),
    'deleted_at': order.deletedAt?.toUtc().toIso8601String(),
    'delivery_problem': order.deliveryProblem,
    'pending_balance': order.pendingBalance,
    'valor_envio': order.valorEnvio,
    'envio_pending_balance': order.envioPendingBalance,
  };

  /// Maps an `orders` row back to the domain [Order]. See [toRow].
  @visibleForTesting
  static Order fromRow(Map<String, dynamic> row) => Order(
    id: row['id'] as String,
    deliveryAddress: row['delivery_address'] as String,
    createdBy: row['created_by'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    latitude: (row['latitude'] as num?)?.toDouble(),
    longitude: (row['longitude'] as num?)?.toDouble(),
    resolvedCity: row['resolved_city'] as String?,
    clientName: row['client_name'] as String?,
    clientPhone: row['client_phone'] as String?,
    notes: row['notes'] as String?,
    assignedCadeteId: row['assigned_cadete_id'] as String?,
    amountToCharge: (row['amount_to_charge'] as num?)?.toDouble(),
    paymentMethod: _paymentMethodFromRow(row['payment_method'] as String),
    paymentStatus: _paymentStatusFromRow(row['payment_status'] as String),
    status: SupabaseOrdersRemote.statusFromRow(row['status'] as String),
    items: ((row['items'] as List<dynamic>?) ?? const <dynamic>[])
        .map(
          (dynamic item) => OrderItem(
            productName: (item as Map<String, dynamic>)['product_name'] as String,
            quantity: item['quantity'] as int,
            sourceVentaId: item['source_venta_id'] as String?,
          ),
        )
        .toList(growable: false),
    // A row fetched from Supabase is, by definition, already synced.
    syncStatus: SyncStatus.synced,
    deliveredAt: row['delivered_at'] == null
        ? null
        : DateTime.parse(row['delivered_at'] as String),
    deletedAt: row['deleted_at'] == null ? null : DateTime.parse(row['deleted_at'] as String),
    deliveryProblem: row['delivery_problem'] as String?,
    pendingBalance: (row['pending_balance'] as num?)?.toDouble(),
    valorEnvio: (row['valor_envio'] as num?)?.toDouble(),
    envioPendingBalance: (row['envio_pending_balance'] as num?)?.toDouble(),
  );

  /// Explicit `status` ↔ row mapper — mirrors [_paymentMethodToRow]/
  /// [_paymentMethodFromRow]'s style. Required because `OrderStatus.name`
  /// (Dart) yields `enCamino` for the new status, but the `orders.status`
  /// SQL check constraint (0003 migration) only accepts the snake_case
  /// `'en_camino'` — see design decision #7.
  ///
  /// Deliberately **not** underscore-private (unlike the payment mappers)
  /// so it can be unit-tested directly: the design flagged the
  /// `.name`-vs-wire-format mismatch as the single highest correctness risk
  /// in this change, so its round-trip gets a real test rather than relying
  /// on the untested-vendor-surface precedent used elsewhere in this file.
  @visibleForTesting
  static String statusToRow(OrderStatus status) => switch (status) {
    OrderStatus.pendiente => 'pendiente',
    OrderStatus.asignado => 'asignado',
    OrderStatus.enCamino => 'en_camino',
    OrderStatus.entregado => 'entregado',
    OrderStatus.cancelado => 'cancelado',
  };

  @visibleForTesting
  static OrderStatus statusFromRow(String value) => switch (value) {
    'pendiente' => OrderStatus.pendiente,
    'asignado' => OrderStatus.asignado,
    'en_camino' => OrderStatus.enCamino,
    'entregado' => OrderStatus.entregado,
    'cancelado' => OrderStatus.cancelado,
    _ => OrderStatus.pendiente,
  };

  static String _paymentMethodToRow(PaymentMethod method) => switch (method) {
    PaymentMethod.efectivo => 'efectivo',
    PaymentMethod.transferencia => 'transferencia',
    PaymentMethod.sinDefinir => 'sin_definir',
  };

  static PaymentMethod _paymentMethodFromRow(String value) => switch (value) {
    'efectivo' => PaymentMethod.efectivo,
    'transferencia' => PaymentMethod.transferencia,
    _ => PaymentMethod.sinDefinir,
  };

  static String _paymentStatusToRow(PaymentStatus status) => switch (status) {
    PaymentStatus.pendiente => 'pendiente',
    PaymentStatus.cobrado => 'cobrado',
  };

  static PaymentStatus _paymentStatusFromRow(String value) => switch (value) {
    'cobrado' => PaymentStatus.cobrado,
    _ => PaymentStatus.pendiente,
  };
}
