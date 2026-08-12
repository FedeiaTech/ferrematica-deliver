import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../auth/domain/cadete_directory.dart' show CadeteProfile;
import '../../../auth/presentation/providers.dart' show cadeteListProvider;
import '../../../delivery/presentation/providers.dart'
    show currentDeviceLocationProvider;
import '../../domain/order.dart';
import '../providers.dart' show isOrderUnassigned;
import 'incomplete_badge.dart';
import 'sync_status_chip.dart';

/// A single row in [OrdersListScreen]. Tapping navigates to the order's
/// detail view.
class OrderCard extends ConsumerWidget {
  const OrderCard({
    required this.order,
    required this.onTap,
    this.isFirst = false,
    super.key,
  });

  final Order order;
  final VoidCallback onTap;

  /// Whether this is the first card in the list — drops the top margin so
  /// it doesn't stack with the filter row's own bottom padding above it.
  final bool isFirst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cadetes = ref
        .watch(cadeteListProvider)
        .maybeWhen(data: (cadetes) => cadetes, orElse: () => const <CadeteProfile>[]);
    final cadeteIds = cadetes.map((cadete) => cadete.id).toSet();
    // "Asignado" only reflects a real cadete handoff. Every new order is
    // auto-assigned to the dueño themselves at creation (see
    // `OrdersController.createOrder`), so without this check every fresh
    // order would misleadingly read "Asignado" despite sitting unclaimed —
    // see user-reported correction 2026-08-03.
    final isUnassigned = isOrderUnassigned(order, cadeteIds);
    final String statusLabel;
    final Color statusColor;
    if (order.status == OrderStatus.asignado && isUnassigned) {
      statusLabel = 'No asignado';
      statusColor = Colors.grey.shade600;
    } else if (order.status == OrderStatus.asignado) {
      statusLabel = cadetes
          .firstWhere((cadete) => cadete.id == order.assignedCadeteId)
          .displayName;
      statusColor = orderStatusColor(order.status);
    } else {
      statusLabel = orderStatusLabel(order.status);
      statusColor = orderStatusColor(order.status);
    }
    final isCancelled = order.status == OrderStatus.cancelado;

    final currentLocation = ref.watch(currentDeviceLocationProvider).value;
    double? distanceKm;
    if (currentLocation != null && order.latitude != null && order.longitude != null) {
      distanceKm =
          Geolocator.distanceBetween(
            currentLocation.latitude,
            currentLocation.longitude,
            order.latitude!,
            order.longitude!,
          ) /
          1000;
    }
    final hasCityOrDistance = order.resolvedCity != null || distanceKm != null;

    return Opacity(
      opacity: isCancelled ? 0.6 : 1,
      child: Card(
        margin: EdgeInsets.fromLTRB(12, isFirst ? 0 : 6, 12, 6),
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
          trailing: order.amountToCharge != null || order.needsPaymentFollowUp
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (order.amountToCharge != null)
                      Text(
                        '\$${order.amountToCharge!.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    if (order.needsPaymentFollowUp)
                      Tooltip(
                        message: 'Cobro pendiente',
                        child: Icon(
                          Icons.money_off_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                )
              : null,
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasCityOrDistance) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (distanceKm != null) ...[
                      Icon(
                        Icons.social_distance_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${distanceKm.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (distanceKm != null && order.resolvedCity != null)
                      const SizedBox(width: 8),
                    if (order.resolvedCity != null)
                      Flexible(
                        child: Text(
                          order.resolvedCity!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Text(
                statusLabel,
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
