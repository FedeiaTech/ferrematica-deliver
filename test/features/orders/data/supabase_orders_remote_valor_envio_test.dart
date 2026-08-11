import 'package:ferrematica_express/features/orders/data/supabase_orders_remote.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors `supabase_orders_remote_pending_balance_test.dart`: `valor_envio`
/// (migration 0014's column name) round-trips through
/// [SupabaseOrdersRemote.toRow]/[SupabaseOrdersRemote.fromRow].
void main() {
  group('valor_envio row mapping (migration 0014 column)', () {
    test('a set valorEnvio is present under the valor_envio key', () {
      final order = Order(
        id: 'order-1',
        deliveryAddress: 'Calle Falsa 123',
        createdBy: 'owner-1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        valorEnvio: 500,
      );

      final row = SupabaseOrdersRemote.toRow(order);

      expect(row['valor_envio'], 500);
    });

    test('a null valorEnvio maps to a null valor_envio column', () {
      final order = Order(
        id: 'order-1',
        deliveryAddress: 'Calle Falsa 123',
        createdBy: 'owner-1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final row = SupabaseOrdersRemote.toRow(order);

      expect(row['valor_envio'], isNull);
    });

    test('a row with valor_envio present maps back to a non-null domain value', () {
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
        'pending_balance': null,
        'valor_envio': 500,
      };

      final order = SupabaseOrdersRemote.fromRow(row);

      expect(order.valorEnvio, 500);
    });

    test('a row with valor_envio: null maps back to a null domain value', () {
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
        'valor_envio': null,
      };

      final order = SupabaseOrdersRemote.fromRow(row);

      expect(order.valorEnvio, isNull);
    });
  });
}
