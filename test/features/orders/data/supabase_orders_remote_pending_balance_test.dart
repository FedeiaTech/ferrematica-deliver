import 'package:ferrematica_express/features/orders/data/supabase_orders_remote.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers `cobro-parcial-pedidos` DA1/spec: `pending_balance` (migration
/// 0013's column name) round-trips through [SupabaseOrdersRemote.toRow]/
/// [SupabaseOrdersRemote.fromRow], mirroring the `statusToRow`/
/// `statusFromRow` testability precedent in this file.
void main() {
  group('pending_balance row mapping (migration 0013 column)', () {
    test('a partial balance is present under the pending_balance key', () {
      final order = Order(
        id: 'order-1',
        deliveryAddress: 'Calle Falsa 123',
        createdBy: 'owner-1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        amountToCharge: 100,
        paymentStatus: PaymentStatus.cobrado,
        pendingBalance: 60,
      );

      final row = SupabaseOrdersRemote.toRow(order);

      expect(row['pending_balance'], 60);
    });

    test('a null pendingBalance maps to a null pending_balance column', () {
      final order = Order(
        id: 'order-1',
        deliveryAddress: 'Calle Falsa 123',
        createdBy: 'owner-1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final row = SupabaseOrdersRemote.toRow(order);

      expect(row['pending_balance'], isNull);
    });

    test('a row with pending_balance present maps back to a non-null domain value', () {
      final row = <String, dynamic>{
        'id': 'order-1',
        'delivery_address': 'Calle Falsa 123',
        'created_by': 'owner-1',
        'assigned_cadete_id': null,
        'latitude': null,
        'longitude': null,
        'resolved_city': null,
        'client_name': null,
        'client_phone': null,
        'notes': null,
        'amount_to_charge': 100,
        'payment_method': 'sin_definir',
        'payment_status': 'cobrado',
        'status': 'entregado',
        'items': <dynamic>[],
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
        'delivered_at': null,
        'deleted_at': null,
        'delivery_problem': null,
        'pending_balance': 60,
      };

      final order = SupabaseOrdersRemote.fromRow(row);

      expect(order.pendingBalance, 60);
    });

    test('a row with pending_balance: null maps back to a null domain value', () {
      final row = <String, dynamic>{
        'id': 'order-1',
        'delivery_address': 'Calle Falsa 123',
        'created_by': 'owner-1',
        'assigned_cadete_id': null,
        'latitude': null,
        'longitude': null,
        'resolved_city': null,
        'client_name': null,
        'client_phone': null,
        'notes': null,
        'amount_to_charge': null,
        'payment_method': 'sin_definir',
        'payment_status': 'pendiente',
        'status': 'pendiente',
        'items': <dynamic>[],
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
        'delivered_at': null,
        'deleted_at': null,
        'delivery_problem': null,
        'pending_balance': null,
      };

      final order = SupabaseOrdersRemote.fromRow(row);

      expect(order.pendingBalance, isNull);
    });
  });
}
