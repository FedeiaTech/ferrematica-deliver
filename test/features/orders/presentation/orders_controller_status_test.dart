import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/presentation/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_orders_repository.dart';

void main() {
  group('OrdersController.isValidTransition — en_camino', () {
    test('asignado -> enCamino is accepted', () {
      expect(
        OrdersController.isValidTransition(OrderStatus.asignado, OrderStatus.enCamino),
        isTrue,
      );
    });

    test('enCamino -> entregado is accepted', () {
      expect(
        OrdersController.isValidTransition(OrderStatus.enCamino, OrderStatus.entregado),
        isTrue,
      );
    });

    test('enCamino -> asignado (backward) is rejected', () {
      expect(
        OrdersController.isValidTransition(OrderStatus.enCamino, OrderStatus.asignado),
        isFalse,
      );
    });

    test('pendiente -> enCamino (skips asignado) is rejected', () {
      expect(
        OrdersController.isValidTransition(OrderStatus.pendiente, OrderStatus.enCamino),
        isFalse,
      );
    });

    test('entregado -> enCamino (backward) is rejected', () {
      expect(
        OrdersController.isValidTransition(OrderStatus.entregado, OrderStatus.enCamino),
        isFalse,
      );
    });

    test('any non-cancelado status -> cancelado is still accepted', () {
      expect(
        OrdersController.isValidTransition(OrderStatus.enCamino, OrderStatus.cancelado),
        isTrue,
      );
    });

    test('cancelado -> enCamino is rejected (terminal state)', () {
      expect(
        OrdersController.isValidTransition(OrderStatus.cancelado, OrderStatus.enCamino),
        isFalse,
      );
    });
  });

  group('OrdersController.startDelivery', () {
    late FakeOrdersRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeOrdersRepository();
      container = ProviderContainer(
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      addTearDown(repository.dispose);
    });

    test('transitions asignado -> enCamino', () async {
      final order = buildTestOrder(status: OrderStatus.asignado);
      await repository.save(order);

      await container.read(ordersControllerProvider.notifier).startDelivery(order);

      final saved = await repository.getById(order.id);
      expect(saved!.status, OrderStatus.enCamino);
      expect(saved.syncStatus, SyncStatus.pending);
    });

    test('is a no-op from pendiente (skips asignado)', () async {
      final order = buildTestOrder(status: OrderStatus.pendiente);
      await repository.save(order);

      await container.read(ordersControllerProvider.notifier).startDelivery(order);

      final saved = await repository.getById(order.id);
      expect(saved!.status, OrderStatus.pendiente);
    });
  });

  group('OrdersController.markDelivered', () {
    late FakeOrdersRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeOrdersRepository();
      container = ProviderContainer(
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      addTearDown(repository.dispose);
    });

    test('cobrado with no pendingBalance leaves it null', () async {
      final order = buildTestOrder(status: OrderStatus.enCamino, amountToCharge: 100);
      await repository.save(order);

      await container
          .read(ordersControllerProvider.notifier)
          .markDelivered(order, paymentStatus: PaymentStatus.cobrado);

      final saved = await repository.getById(order.id);
      expect(saved!.status, OrderStatus.entregado);
      expect(saved.paymentStatus, PaymentStatus.cobrado);
      expect(saved.pendingBalance, isNull);
    });

    test('cobrado with a partial pendingBalance persists it', () async {
      final order = buildTestOrder(status: OrderStatus.enCamino, amountToCharge: 100);
      await repository.save(order);

      await container
          .read(ordersControllerProvider.notifier)
          .markDelivered(order, paymentStatus: PaymentStatus.cobrado, pendingBalance: 60);

      final saved = await repository.getById(order.id);
      expect(saved!.status, OrderStatus.entregado);
      expect(saved.paymentStatus, PaymentStatus.cobrado);
      expect(saved.pendingBalance, 60);
    });

    test('an order that already had a pendingBalance gets it cleared on full payment', () async {
      // Simulates re-marking delivered (or a follow-up settle) where the
      // caller now passes null — pendingBalance must not silently linger
      // via copyWith's default `?? this.pendingBalance` behavior.
      final order = buildTestOrder(
        status: OrderStatus.entregado,
        paymentStatus: PaymentStatus.cobrado,
        amountToCharge: 100,
        pendingBalance: 60,
      );
      await repository.save(order);

      await container
          .read(ordersControllerProvider.notifier)
          .markDelivered(order, paymentStatus: PaymentStatus.cobrado);

      final saved = await repository.getById(order.id);
      expect(saved!.pendingBalance, isNull);
    });

    test('cobrado with no envioPendingBalance leaves it null', () async {
      final order = buildTestOrder(status: OrderStatus.enCamino, valorEnvio: 200);
      await repository.save(order);

      await container
          .read(ordersControllerProvider.notifier)
          .markDelivered(order, paymentStatus: PaymentStatus.cobrado);

      final saved = await repository.getById(order.id);
      expect(saved!.status, OrderStatus.entregado);
      expect(saved.envioPendingBalance, isNull);
    });

    test('cobrado with a partial envioPendingBalance persists it', () async {
      final order = buildTestOrder(status: OrderStatus.enCamino, valorEnvio: 200);
      await repository.save(order);

      await container
          .read(ordersControllerProvider.notifier)
          .markDelivered(
            order,
            paymentStatus: PaymentStatus.cobrado,
            envioPendingBalance: 80,
          );

      final saved = await repository.getById(order.id);
      expect(saved!.status, OrderStatus.entregado);
      expect(saved.envioPendingBalance, 80);
    });

    test(
      'an order that already had an envioPendingBalance gets it cleared on full collection',
      () async {
        // Same shape as the pendingBalance regression above: re-marking
        // delivered (or a follow-up settle) with no envioPendingBalance
        // passed must not leave the old one lingering via copyWith's
        // default `?? this.envioPendingBalance` behavior.
        final order = buildTestOrder(
          status: OrderStatus.entregado,
          paymentStatus: PaymentStatus.cobrado,
          valorEnvio: 200,
          envioPendingBalance: 80,
        );
        await repository.save(order);

        await container
            .read(ordersControllerProvider.notifier)
            .markDelivered(order, paymentStatus: PaymentStatus.cobrado);

        final saved = await repository.getById(order.id);
        expect(saved!.envioPendingBalance, isNull);
      },
    );
  });

  group('OrdersController.assignCadete', () {
    late FakeOrdersRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeOrdersRepository();
      container = ProviderContainer(
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      addTearDown(repository.dispose);
    });

    test('sets assignedCadeteId and status=asignado from pendiente', () async {
      final order = buildTestOrder(status: OrderStatus.pendiente);
      await repository.save(order);

      await container
          .read(ordersControllerProvider.notifier)
          .assignCadete(order, 'cadete-1');

      final saved = await repository.getById(order.id);
      expect(saved!.assignedCadeteId, 'cadete-1');
      expect(saved.status, OrderStatus.asignado);
    });

    test('reassigns from asignado (still allowed pre-en_camino)', () async {
      final order = buildTestOrder(status: OrderStatus.asignado);
      await repository.save(order);

      await container
          .read(ordersControllerProvider.notifier)
          .assignCadete(order, 'cadete-2');

      final saved = await repository.getById(order.id);
      expect(saved!.assignedCadeteId, 'cadete-2');
      expect(saved.status, OrderStatus.asignado);
    });

    test('is rejected once the order is enCamino (no reassignment)', () async {
      final order = buildTestOrder(status: OrderStatus.enCamino);
      await repository.save(order);

      await container
          .read(ordersControllerProvider.notifier)
          .assignCadete(order, 'cadete-2');

      final saved = await repository.getById(order.id);
      expect(saved!.assignedCadeteId, isNull);
      expect(saved.status, OrderStatus.enCamino);
    });

    test('is rejected once the order is entregado (no reassignment)', () async {
      final order = buildTestOrder(status: OrderStatus.entregado);
      await repository.save(order);

      await container
          .read(ordersControllerProvider.notifier)
          .assignCadete(order, 'cadete-2');

      final saved = await repository.getById(order.id);
      expect(saved!.assignedCadeteId, isNull);
      expect(saved.status, OrderStatus.entregado);
    });
  });
}
