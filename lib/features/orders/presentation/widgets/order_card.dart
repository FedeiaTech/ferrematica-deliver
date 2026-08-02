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
    final statusColor = orderStatusColor(order.status);
    final isCancelled = order.status == OrderStatus.cancelado;

    return Opacity(
      opacity: isCancelled ? 0.6 : 1,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.15),
            child: Icon(orderStatusIcon(order.status), color: statusColor),
          ),
          isThreeLine: true,
          title: Text(
            order.deliveryAddress,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                orderStatusLabel(order.status),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (order.needsPaymentFollowUp)
                    Tooltip(
                      message: 'Cobro pendiente',
                      child: Icon(
                        Icons.money_off_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (order.isIncomplete) const IncompleteBadge(),
                  SyncStatusChip(status: order.syncStatus),
                ],
              ),
            ],
          ),
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
    case OrderStatus.enCamino:
      return 'En camino';
    case OrderStatus.entregado:
      return 'Entregado';
    case OrderStatus.cancelado:
      return 'Cancelado';
  }
}

/// Status color, shared by the list card and the detail screen so both stay
/// in sync. Fixed hues (not theme color-scheme roles) since these carry
/// semantic meaning (pending/assigned/delivered/cancelled) independent of
/// the app's brand palette.
Color orderStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pendiente:
      return Colors.amber.shade800;
    case OrderStatus.asignado:
      return Colors.blue.shade700;
    case OrderStatus.enCamino:
      return Colors.deepPurple.shade400;
    case OrderStatus.entregado:
      return Colors.green.shade700;
    case OrderStatus.cancelado:
      return Colors.grey.shade600;
  }
}

/// Status icon, shared by the list card and the detail screen so both stay
/// in sync.
IconData orderStatusIcon(OrderStatus status) {
  switch (status) {
    case OrderStatus.pendiente:
      return Icons.schedule_outlined;
    case OrderStatus.asignado:
      return Icons.assignment_ind_outlined;
    case OrderStatus.enCamino:
      return Icons.local_shipping_outlined;
    case OrderStatus.entregado:
      return Icons.check_circle_outline;
    case OrderStatus.cancelado:
      return Icons.cancel_outlined;
  }
}
