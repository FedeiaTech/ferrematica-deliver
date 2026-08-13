import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/presentation/screens/delivery_stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import 'fake_orders_repository.dart';

/// DA5 (design): a `cobrado` order with a non-null `pendingBalance` (a
/// partial collection) must NOT be reported as fully collected — the
/// screen must credit only `amountToCharge - pendingBalance` to
/// "Productos" and separately surface the still-owed amount under
/// "Pendientes de cobrar"/"Monto adeudado", same as an order that hasn't
/// been collected at all.
void main() {
  testWidgets(
    'a partially-paid delivered order credits only the collected portion to "Productos", '
    'not the full amountToCharge, and "Total cobrado" adds valorEnvio on top',
    (tester) async {
      final deliveredAt = DateTime.now();
      final repository = FakeOrdersRepository(
        seed: [
          buildTestOrder(
            id: 'order-1',
            status: OrderStatus.entregado,
            paymentStatus: PaymentStatus.cobrado,
            amountToCharge: 100,
            pendingBalance: 60,
            assignedCadeteId: 'fake-owner',
          ).copyWith(deliveredAt: deliveredAt, updatedAt: deliveredAt, valorEnvio: 15),
        ],
      );
      addTearDown(repository.dispose);

      await pumpApp(
        tester,
        const MaterialApp(home: DeliveryStatsScreen()),
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      // Correct behavior: only the collected $40 (100 - 60) is credited as
      // "Productos". The pre-fix code credited the full $100 under
      // "Cobrado" (this stat's old label/name).
      expect(find.text('\$40.00'), findsOneWidget);
      expect(find.text('\$100.00'), findsNothing);

      // "Envíos" is the full valorEnvio for the delivered order — this
      // order's envioPendingBalance is null (fully collected, the default
      // for an order that doesn't set it), so the whole fee counts.
      expect(find.text('\$15.00'), findsOneWidget);

      // "Total cobrado" = productos collected ($40) + cadetería ($15) = $55.
      expect(find.text('Total cobrado'), findsOneWidget);
      expect(find.text('\$55.00'), findsOneWidget);

      // The still-owed $60 must surface under "Pendientes de cobrar" /
      // "Monto adeudado", same as a delivery collected $0 would.
      expect(find.text('Pendientes de cobrar'), findsOneWidget);
      expect(find.text('Monto adeudado'), findsOneWidget);
      expect(find.text('\$60.00'), findsOneWidget); // pendingPaymentAmount
    },
  );

  testWidgets(
    '"Envíos" credits only the collected portion of each cadetería fee: '
    'nothing on a fully-pending one, in full on a fully-collected one, and '
    'the partial remainder on a genuinely partial one',
    (tester) async {
      final deliveredAt = DateTime.now();
      final repository = FakeOrdersRepository(
        seed: [
          buildTestOrder(
            id: 'order-pending-envio',
            status: OrderStatus.entregado,
            paymentStatus: PaymentStatus.cobrado,
            amountToCharge: 40,
            assignedCadeteId: 'fake-owner',
          ).copyWith(
            deliveredAt: deliveredAt,
            updatedAt: deliveredAt,
            valorEnvio: 50,
            envioPendingBalance: 50, // nothing collected yet
          ),
          buildTestOrder(
            id: 'order-collected-envio',
            status: OrderStatus.entregado,
            paymentStatus: PaymentStatus.cobrado,
            assignedCadeteId: 'fake-owner',
          ).copyWith(
            deliveredAt: deliveredAt,
            updatedAt: deliveredAt,
            valorEnvio: 30, // fully collected (envioPendingBalance null)
          ),
          buildTestOrder(
            id: 'order-partial-envio',
            status: OrderStatus.entregado,
            paymentStatus: PaymentStatus.cobrado,
            assignedCadeteId: 'fake-owner',
          ).copyWith(
            deliveredAt: deliveredAt,
            updatedAt: deliveredAt,
            valorEnvio: 100,
            envioPendingBalance: 40, // $60 actually collected, $40 still owed
          ),
        ],
      );
      addTearDown(repository.dispose);

      await pumpApp(
        tester,
        const MaterialApp(home: DeliveryStatsScreen()),
        overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      // "Envíos" = $0 (pending) + $30 (fully collected) + $60 (partial,
      // collected portion only) = $90 — NOT $80 (which is what the old,
      // buggy "all-or-nothing" gate would have produced by dropping the
      // partial order's $60 entirely) and NOT $180 (the full valorEnvio
      // sum, which would double-count the still-owed portions).
      // "Productos" = $40 (only order-pending-envio sets amountToCharge).
      // "Total cobrado" = $40 + $90 = $130.
      expect(find.text('\$90.00'), findsOneWidget);
      expect(find.text('\$80.00'), findsNothing);
      expect(find.text('\$180.00'), findsNothing);
      expect(find.text('\$130.00'), findsOneWidget);
    },
  );

  group('period navigation', () {
    testWidgets(
      'stepping the "Hoy" anchor back to yesterday reveals a delivery excluded '
      'from today\'s totals, and the label switches from "Hoy" to "Ayer"',
      (tester) async {
        final now = DateTime.now();
        final yesterday = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 1)).add(const Duration(hours: 10));
        final repository = FakeOrdersRepository(
          seed: [
            buildTestOrder(
              id: 'order-yesterday',
              status: OrderStatus.entregado,
              paymentStatus: PaymentStatus.cobrado,
              amountToCharge: 321,
              assignedCadeteId: 'fake-owner',
            ).copyWith(deliveredAt: yesterday, updatedAt: yesterday),
          ],
        );
        addTearDown(repository.dispose);

        await pumpApp(
          tester,
          const MaterialApp(home: DeliveryStatsScreen()),
          overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
        );
        await tester.pumpAndSettle();

        // "Hoy" appears twice at rest: the period-type chip and the
        // anchor-range label both read "Hoy" while anchored on today.
        expect(find.text('Hoy'), findsNWidgets(2));
        // Today's "Hoy" period excludes yesterday's delivery — its unique
        // amount shouldn't be credited to "Productos" yet.
        expect(find.text('\$321.00'), findsNothing);

        await tester.tap(find.byTooltip('Período anterior'));
        await tester.pumpAndSettle();

        // The chip still reads "Hoy" (period type unchanged) — only the
        // anchor label moves to "Ayer".
        expect(find.text('Hoy'), findsOneWidget);
        expect(find.text('Ayer'), findsOneWidget);
        // Shows twice: "Productos" and "Total cobrado" both read $321.00
        // since this order has no valorEnvio (envioTotal stays 0).
        expect(find.text('\$321.00'), findsNWidgets(2));
      },
    );

    testWidgets(
      'the "next period" button is disabled at the current period and enables '
      'once stepped back',
      (tester) async {
        final repository = FakeOrdersRepository();
        addTearDown(repository.dispose);

        await pumpApp(
          tester,
          const MaterialApp(home: DeliveryStatsScreen()),
          overrides: [ordersRepositoryProvider.overrideWithValue(repository)],
        );
        await tester.pumpAndSettle();

        Finder nextIconButton() => find.ancestor(
          of: find.byTooltip('Período siguiente'),
          matching: find.byType(IconButton),
        );

        expect(tester.widget<IconButton>(nextIconButton()).onPressed, isNull);

        await tester.tap(find.byTooltip('Período anterior'));
        await tester.pumpAndSettle();

        expect(tester.widget<IconButton>(nextIconButton()).onPressed, isNotNull);
      },
    );
  });
}
