import 'package:ferrematica_express/features/orders/data/supabase_orders_remote.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers `SupabaseOrdersRemote.statusToRow`/`statusFromRow` — the explicit
/// wire mapper added in the `navegacion-cadete` PR2 (design decision #7).
///
/// This is the single highest-risk correctness point flagged by the design:
/// `OrderStatus.enCamino.name` is the Dart-camelCase `'enCamino'`, but the
/// `orders.status` SQL check constraint (0003 migration) only accepts the
/// snake_case `'en_camino'`. Relying on `.name` would silently reject every
/// write once an order reaches `en_camino`.
void main() {
  group('SupabaseOrdersRemote.statusToRow', () {
    test('en_camino maps to the snake_case wire string, not .name', () {
      expect(SupabaseOrdersRemote.statusToRow(OrderStatus.enCamino), 'en_camino');
      // Sanity-check the risk itself: .name would NOT equal the wire string.
      expect(OrderStatus.enCamino.name, isNot('en_camino'));
      expect(OrderStatus.enCamino.name, 'enCamino');
    });

    test('all other statuses map 1:1 to their snake_case name', () {
      expect(SupabaseOrdersRemote.statusToRow(OrderStatus.pendiente), 'pendiente');
      expect(SupabaseOrdersRemote.statusToRow(OrderStatus.asignado), 'asignado');
      expect(SupabaseOrdersRemote.statusToRow(OrderStatus.entregado), 'entregado');
      expect(SupabaseOrdersRemote.statusToRow(OrderStatus.cancelado), 'cancelado');
    });
  });

  group('SupabaseOrdersRemote status round-trip', () {
    test('every OrderStatus value survives toRow -> fromRow unchanged', () {
      for (final status in OrderStatus.values) {
        final wire = SupabaseOrdersRemote.statusToRow(status);
        final restored = SupabaseOrdersRemote.statusFromRow(wire);
        expect(restored, status, reason: 'round-trip failed for $status ("$wire")');
      }
    });

    test('fromRow accepts the literal en_camino wire value', () {
      expect(SupabaseOrdersRemote.statusFromRow('en_camino'), OrderStatus.enCamino);
    });
  });
}
