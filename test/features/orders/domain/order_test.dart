import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

Order _buildOrder({
  String deliveryAddress = 'Calle Falsa 123',
  double? amountToCharge,
  PaymentMethod paymentMethod = PaymentMethod.sinDefinir,
  PaymentStatus paymentStatus = PaymentStatus.pendiente,
  OrderStatus status = OrderStatus.pendiente,
}) {
  final now = DateTime(2026, 1, 1);
  return Order(
    id: 'order-1',
    deliveryAddress: deliveryAddress,
    createdBy: 'owner-1',
    createdAt: now,
    updatedAt: now,
    amountToCharge: amountToCharge,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus,
    status: status,
  );
}

void main() {
  group('Order delivery_address invariant', () {
    test('non-empty address builds successfully', () {
      expect(() => _buildOrder(deliveryAddress: 'Av. Siempreviva 742'), returnsNormally);
    });

    test('empty address throws an assertion error', () {
      expect(() => _buildOrder(deliveryAddress: ''), throwsA(isA<AssertionError>()));
    });

    test('whitespace-only address throws an assertion error', () {
      expect(() => _buildOrder(deliveryAddress: '   '), throwsA(isA<AssertionError>()));
    });
  });

  group('Order.isIncomplete', () {
    test('true when amountToCharge is null', () {
      final order = _buildOrder(amountToCharge: null, paymentMethod: PaymentMethod.efectivo);
      expect(order.isIncomplete, isTrue);
    });

    test('true when paymentMethod is sinDefinir', () {
      final order = _buildOrder(amountToCharge: 100, paymentMethod: PaymentMethod.sinDefinir);
      expect(order.isIncomplete, isTrue);
    });

    test('false when both amountToCharge and paymentMethod are set', () {
      final order = _buildOrder(amountToCharge: 100, paymentMethod: PaymentMethod.efectivo);
      expect(order.isIncomplete, isFalse);
    });
  });

  group('Order.needsPaymentFollowUp', () {
    test('true when delivered with payment pending', () {
      final order = _buildOrder(
        status: OrderStatus.entregado,
        paymentStatus: PaymentStatus.pendiente,
      );
      expect(order.needsPaymentFollowUp, isTrue);
    });

    test('false when delivered and paid', () {
      final order = _buildOrder(
        status: OrderStatus.entregado,
        paymentStatus: PaymentStatus.cobrado,
      );
      expect(order.needsPaymentFollowUp, isFalse);
    });

    test('false when not yet delivered', () {
      final order = _buildOrder(
        status: OrderStatus.asignado,
        paymentStatus: PaymentStatus.pendiente,
      );
      expect(order.needsPaymentFollowUp, isFalse);
    });
  });

  group('Order.copyWith', () {
    test('bumps updatedAt when not explicitly provided', () async {
      final order = _buildOrder();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final updated = order.copyWith(status: OrderStatus.asignado);

      expect(updated.updatedAt.isAfter(order.updatedAt), isTrue);
    });

    test('preserves an explicitly provided updatedAt', () {
      final order = _buildOrder();
      final explicit = DateTime(2030, 1, 1);

      final updated = order.copyWith(updatedAt: explicit);

      expect(updated.updatedAt, explicit);
    });

    test('preserves identity fields (id, createdBy, createdAt)', () {
      final order = _buildOrder();

      final updated = order.copyWith(status: OrderStatus.cancelado);

      expect(updated.id, order.id);
      expect(updated.createdBy, order.createdBy);
      expect(updated.createdAt, order.createdAt);
    });

    test('replaces only the given field, keeps the rest', () {
      final order = _buildOrder(amountToCharge: 50);

      final updated = order.copyWith(notes: 'llamar antes de llegar');

      expect(updated.notes, 'llamar antes de llegar');
      expect(updated.amountToCharge, 50);
      expect(updated.deliveryAddress, order.deliveryAddress);
    });
  });

  group('OrderStatus enum round-trip', () {
    test('name maps back to the same enum value', () {
      for (final status in OrderStatus.values) {
        final restored = OrderStatus.values.byName(status.name);
        expect(restored, status);
      }
    });
  });

  group('PaymentMethod enum round-trip', () {
    test('name maps back to the same enum value', () {
      for (final method in PaymentMethod.values) {
        final restored = PaymentMethod.values.byName(method.name);
        expect(restored, method);
      }
    });
  });

  group('PaymentStatus enum round-trip', () {
    test('name maps back to the same enum value', () {
      for (final status in PaymentStatus.values) {
        final restored = PaymentStatus.values.byName(status.name);
        expect(restored, status);
      }
    });
  });

  group('SyncStatus enum round-trip', () {
    test('name maps back to the same enum value', () {
      for (final status in SyncStatus.values) {
        final restored = SyncStatus.values.byName(status.name);
        expect(restored, status);
      }
    });
  });
}
