import 'package:flutter/material.dart';

import '../../domain/order.dart';
import 'incomplete_badge.dart';
import 'sync_status_chip.dart';

/// A single row in [OrdersListScreen]. Tapping navigates to the order's
/// detail view.
class OrderCard extends StatelessWidget {
  const OrderCard({required this.order, required this.onTap, super.key});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: onTap,
        title: Text(order.deliveryAddress),
        subtitle: Text(orderStatusLabel(order.status)),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (order.isIncomplete) const IncompleteBadge(),
            SyncStatusChip(status: order.syncStatus),
          ],
        ),
      ),
    );
  }
}

/// Human-readable (Spanish) label for [status], shared by the list card and
/// the detail screen so both stay in sync.
String orderStatusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.pendiente:
      return 'Pendiente';
    case OrderStatus.asignado:
      return 'Asignado';
    case OrderStatus.entregado:
      return 'Entregado';
    case OrderStatus.cancelado:
      return 'Cancelado';
  }
}
