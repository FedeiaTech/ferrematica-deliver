import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/presentation/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_orders_repository.dart';

/// `isOrderUnassigned` drives the "Asignación" filter section — an
/// independent dimension from [OrderStatus] (see `orders_list_screen.dart`
/// doc comment on `_StatusFilterMenu` for why: an earlier version gated
/// this on `status == asignado`, so combining it with e.g. `entregado`
/// always produced an empty list even though a dueño-run delivery reads
/// "No asignado" regardless of what status it's currently in).
void main() {
  group('isOrderUnassigned', () {
    test('true for a pendiente order with no assignedCadeteId at all', () {
      final order = buildTestOrder(status: OrderStatus.pendiente);
      expect(isOrderUnassigned(order, {'cadete-1'}), isTrue);
    });

    test(
      'true for an entregado order still on the dueño\'s default self-assignment '
      '(assignedCadeteId not in the real cadete roster)',
      () {
        final order = buildTestOrder(
          status: OrderStatus.entregado,
          assignedCadeteId: 'dueno-user-id',
        );
        expect(isOrderUnassigned(order, {'cadete-1', 'cadete-2'}), isTrue);
      },
    );

    test('false for any status once assignedCadeteId is a real cadete', () {
      for (final status in OrderStatus.values) {
        final order = buildTestOrder(status: status, assignedCadeteId: 'cadete-1');
        expect(
          isOrderUnassigned(order, {'cadete-1'}),
          isFalse,
          reason: 'status=$status with a real cadete should read as assigned',
        );
      }
    });
  });
}
