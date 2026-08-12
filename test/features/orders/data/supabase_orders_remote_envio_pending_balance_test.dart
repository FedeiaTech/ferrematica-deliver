import 'package:ferrematica_express/features/orders/data/supabase_orders_remote.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors `supabase_orders_remote_pending_balance_test.dart`/
/// `supabase_orders_remote_valor_envio_test.dart`: `envio_pending_balance`
/// (migration 0015's column name) round-trips through
/// [SupabaseOrdersRemote.toRow]/[SupabaseOrdersRemote.fromRow].
void main() {
  group('envio_pending_balance row mapping (migration 0015 column)', () {
    test('a set envioPendingBalance is present under the envio_pending_balance key', () {
      final order = Order(
        id: 'order-1',
        deliveryAddress: 'Calle Falsa 123',
        createdBy: 'owner-1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        valorEnvio: 500,
        envioPendingBalance: 200,
      );

      final row = SupabaseOrdersRemote.toRow(order);

      expect(row['envio_pending_balance'], 200);
    });

    test('a null envioPendingBalance maps to a null envio_pending_balance column', () {
      final order = Order(
        id: 'order-1',
        deliveryAddress: 'Calle Falsa 123',
        createdBy: 'owner-1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final row = SupabaseOrdersRemote.toRow(order);

      expect(row['envio_pending_balance'], isNull);
    });

    test(
      'a row with envio_pending_balance present maps back to a non-null domain value',
      () {
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
          'envio_pending_balance': 200,
        };

        final order = SupabaseOrdersRemote.fromRow(row);

        expect(order.envioPendingBalance, 200);
      },
    );

    test('a row with envio_pending_balance: null maps back to a null domain value', () {
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
        'envio_pending_balance': null,
      };

      final order = SupabaseOrdersRemote.fromRow(row);

      expect(order.envioPendingBalance, isNull);
    });
  });
}
