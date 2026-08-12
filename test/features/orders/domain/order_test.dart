import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

Order _buildOrder({
  String deliveryAddress = 'Calle Falsa 123',
  double? amountToCharge,
  PaymentMethod paymentMethod = PaymentMethod.sinDefinir,
  PaymentStatus paymentStatus = PaymentStatus.pendiente,
  OrderStatus status = OrderStatus.pendiente,
  double? pendingBalance,
  double? valorEnvio,
  double? envioPendingBalance,
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
    pendingBalance: pendingBalance,
    valorEnvio: valorEnvio,
    envioPendingBalance: envioPendingBalance,
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

    test('true when delivered with a partial payment', () {
      final order = _buildOrder(
        status: OrderStatus.entregado,
        paymentStatus: PaymentStatus.cobrado,
        amountToCharge: 100,
        pendingBalance: 60,
      );
      expect(order.needsPaymentFollowUp, isTrue);
    });

    test('false when delivered and fully paid (pendingBalance null)', () {
      final order = _buildOrder(
        status: OrderStatus.entregado,
        paymentStatus: PaymentStatus.cobrado,
        amountToCharge: 100,
        pendingBalance: null,
      );
      expect(order.needsPaymentFollowUp, isFalse);
    });
  });

  group('Order.pendingBalance invariant', () {
    test('null is always valid, regardless of paymentStatus', () {
      expect(
        () => _buildOrder(paymentStatus: PaymentStatus.pendiente, pendingBalance: null),
        returnsNormally,
      );
      expect(
        () => _buildOrder(
          paymentStatus: PaymentStatus.cobrado,
          amountToCharge: 100,
          pendingBalance: null,
        ),
        returnsNormally,
      );
    });

    test('a strict partial value on a cobrado order is valid', () {
      expect(
        () => _buildOrder(
          paymentStatus: PaymentStatus.cobrado,
          amountToCharge: 100,
          pendingBalance: 60,
        ),
        returnsNormally,
      );
    });

    test('non-null pendingBalance on a pendiente order throws', () {
      expect(
        () => _buildOrder(
          paymentStatus: PaymentStatus.pendiente,
          amountToCharge: 100,
          pendingBalance: 60,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('pendingBalance >= amountToCharge throws', () {
      expect(
        () => _buildOrder(
          paymentStatus: PaymentStatus.cobrado,
          amountToCharge: 100,
          pendingBalance: 100,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => _buildOrder(
          paymentStatus: PaymentStatus.cobrado,
          amountToCharge: 100,
          pendingBalance: 150,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('pendingBalance <= 0 throws', () {
      expect(
        () => _buildOrder(
          paymentStatus: PaymentStatus.cobrado,
          amountToCharge: 100,
          pendingBalance: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => _buildOrder(
          paymentStatus: PaymentStatus.cobrado,
          amountToCharge: 100,
          pendingBalance: -5,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('non-null pendingBalance with a null amountToCharge throws', () {
      expect(
        () => _buildOrder(
          paymentStatus: PaymentStatus.cobrado,
          amountToCharge: null,
          pendingBalance: 60,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Order.copyWith clearPendingBalance', () {
    test('keeps the existing pendingBalance when not touched', () {
      final order = _buildOrder(
        paymentStatus: PaymentStatus.cobrado,
        amountToCharge: 100,
        pendingBalance: 60,
      );

      final updated = order.copyWith(notes: 'llamar antes');

      expect(updated.pendingBalance, 60);
    });

    test('sets a new pendingBalance when provided', () {
      final order = _buildOrder(
        paymentStatus: PaymentStatus.cobrado,
        amountToCharge: 100,
        pendingBalance: 60,
      );

      final updated = order.copyWith(pendingBalance: 30);

      expect(updated.pendingBalance, 30);
    });

    test('clearPendingBalance explicitly nulls the field', () {
      final order = _buildOrder(
        paymentStatus: PaymentStatus.cobrado,
        amountToCharge: 100,
        pendingBalance: 60,
      );

      final updated = order.copyWith(clearPendingBalance: true);

      expect(updated.pendingBalance, isNull);
    });
  });

  group('Order.copyWith clearValorEnvio', () {
    test('keeps the existing valorEnvio when not touched', () {
      final order = _buildOrder().copyWith(valorEnvio: 500);

      final updated = order.copyWith(notes: 'llamar antes');

      expect(updated.valorEnvio, 500);
    });

    test('sets a new valorEnvio when provided', () {
      final order = _buildOrder().copyWith(valorEnvio: 500);

      final updated = order.copyWith(valorEnvio: 700);

      expect(updated.valorEnvio, 700);
    });

    test('clearValorEnvio explicitly nulls the field', () {
      final order = _buildOrder().copyWith(valorEnvio: 500);

      final updated = order.copyWith(clearValorEnvio: true);

      expect(updated.valorEnvio, isNull);
    });

    test('valorEnvio defaults to null on construction', () {
      final order = _buildOrder();

      expect(order.valorEnvio, isNull);
    });
  });

  group('Order.envioPendingBalance invariant', () {
    test('null is always valid, regardless of valorEnvio', () {
      expect(
        () => _buildOrder(valorEnvio: null, envioPendingBalance: null),
        returnsNormally,
      );
      expect(
        () => _buildOrder(valorEnvio: 500, envioPendingBalance: null),
        returnsNormally,
      );
    });

    test('a partial value up to and including valorEnvio is valid', () {
      expect(
        () => _buildOrder(valorEnvio: 500, envioPendingBalance: 200),
        returnsNormally,
      );
      // Unlike pendingBalance, equal to the total is valid here — it
      // represents "nothing collected on the delivery fee yet", since
      // there's no separate payment-status flag for valorEnvio.
      expect(
        () => _buildOrder(valorEnvio: 500, envioPendingBalance: 500),
        returnsNormally,
      );
    });

    test('envioPendingBalance > valorEnvio throws', () {
      expect(
        () => _buildOrder(valorEnvio: 500, envioPendingBalance: 600),
        throwsA(isA<AssertionError>()),
      );
    });

    test('envioPendingBalance <= 0 throws', () {
      expect(
        () => _buildOrder(valorEnvio: 500, envioPendingBalance: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => _buildOrder(valorEnvio: 500, envioPendingBalance: -5),
        throwsA(isA<AssertionError>()),
      );
    });

    test('non-null envioPendingBalance with a null valorEnvio throws', () {
      expect(
        () => _buildOrder(valorEnvio: null, envioPendingBalance: 60),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Order.envioFullyCollected', () {
    test('true when there is no delivery fee at all', () {
      final order = _buildOrder(valorEnvio: null);
      expect(order.envioFullyCollected, isTrue);
    });

    test('true when the delivery fee was collected in full', () {
      final order = _buildOrder(valorEnvio: 500, envioPendingBalance: null);
      expect(order.envioFullyCollected, isTrue);
    });

    test('false when part of the delivery fee is still owed', () {
      final order = _buildOrder(valorEnvio: 500, envioPendingBalance: 200);
      expect(order.envioFullyCollected, isFalse);
    });
  });

  group('Order.copyWith clearEnvioPendingBalance', () {
    test('keeps the existing envioPendingBalance when not touched', () {
      final order = _buildOrder(valorEnvio: 500, envioPendingBalance: 200);

      final updated = order.copyWith(notes: 'llamar antes');

      expect(updated.envioPendingBalance, 200);
    });

    test('sets a new envioPendingBalance when provided', () {
      final order = _buildOrder(valorEnvio: 500, envioPendingBalance: 200);

      final updated = order.copyWith(envioPendingBalance: 100);

      expect(updated.envioPendingBalance, 100);
    });

    test('clearEnvioPendingBalance explicitly nulls the field', () {
      final order = _buildOrder(valorEnvio: 500, envioPendingBalance: 200);

      final updated = order.copyWith(clearEnvioPendingBalance: true);

      expect(updated.envioPendingBalance, isNull);
    });

    test('envioPendingBalance defaults to null on construction', () {
      final order = _buildOrder();

      expect(order.envioPendingBalance, isNull);
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

  group('OrderStatus enum declaration order (Isar ordinal regression)', () {
    // Isar's `@enumerated` field on `OrderModel.status` defaults to
    // `EnumType.ordinal`, which persists `OrderStatus.values.indexOf(status)`
    // — the enum's *declaration* index, not its name. `enCamino` was
    // deliberately appended at the END of the `OrderStatus` declaration
    // (navegacion-cadete design decision #6) specifically so this index
    // stays fixed for every status that predates it. If a future change
    // ever moves `enCamino` (or any status) to a different declaration
    // position, this test fails loudly instead of silently corrupting the
    // status of every existing local Isar row on the next read.
    test('pendiente keeps ordinal 0', () {
      expect(OrderStatus.values.indexOf(OrderStatus.pendiente), 0);
    });

    test('asignado keeps ordinal 1', () {
      expect(OrderStatus.values.indexOf(OrderStatus.asignado), 1);
    });

    test('entregado keeps ordinal 2 (unshifted by enCamino)', () {
      expect(OrderStatus.values.indexOf(OrderStatus.entregado), 2);
    });

    test('cancelado keeps ordinal 3 (unshifted by enCamino)', () {
      expect(OrderStatus.values.indexOf(OrderStatus.cancelado), 3);
    });

    test('enCamino was appended at ordinal 4, not inserted mid-enum', () {
      expect(OrderStatus.values.indexOf(OrderStatus.enCamino), 4);
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
