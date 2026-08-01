import 'package:flutter/material.dart';

import '../../domain/order.dart';

/// Dueño-facing alert pinned at the top of the order list whenever one or
/// more orders were marked `entregado` while `payment_status` is still
/// `pendiente`. This is the in-app alert mechanism required by spec's
/// "Delivered with pending payment" scenario — it is informational only
/// and never blocks the status transition that produced it.
class PaymentPendingBanner extends StatelessWidget {
  const PaymentPendingBanner({required this.orders, super.key});

  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final pending = orders.where((order) => order.needsPaymentFollowUp).length;
    if (pending == 0) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colors.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pending == 1
                  ? '1 pedido entregado con cobro pendiente'
                  : '$pending pedidos entregados con cobro pendiente',
              style: TextStyle(
                color: colors.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
