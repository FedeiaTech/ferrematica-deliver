import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers.dart' show cadeteListProvider;
import '../../domain/order.dart';
import '../providers.dart';
import '../widgets/assign_cadete_sheet.dart';
import '../widgets/incomplete_badge.dart';
import '../widgets/order_card.dart'
    show orderStatusColor, orderStatusIcon, orderStatusLabel;
import '../widgets/payment_pending_banner.dart';
import '../widgets/sync_status_chip.dart';

/// Read view for a single order plus its owner-facing actions: edit,
/// cancel, delete (soft), "Marcar entregado" (opens a sheet offering
/// `cobrado`/`cobro pendiente`; pending never blocks the transition, per
/// spec's "Delivered with pending payment" scenario), and "Asignar cadete"
/// (opens `assign_cadete_sheet.dart`, restricted to `pendiente`/`asignado`
/// orders per spec's order-assignment requirement).
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del pedido')),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Pedido no encontrado.'));
          }
          return _OrderDetailBody(order: order);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Error al cargar el pedido: $error')),
      ),
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  const _OrderDetailBody({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDeliver = OrdersController.isValidTransition(
      order.status,
      OrderStatus.entregado,
    );
    final canCancel = order.status != OrderStatus.cancelado;
    // Spec's order-assignment requirement: assignable only while
    // pendiente/asignado — once en_camino or later, reassignment is
    // rejected (matches OrdersController.assignCadete's own guard).
    final canAssignCadete =
        order.status == OrderStatus.pendiente || order.status == OrderStatus.asignado;
    final statusColor = orderStatusColor(order.status);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (order.needsPaymentFollowUp) PaymentPendingBanner(orders: [order]),
        const SizedBox(height: 12),
        Text(
          order.deliveryAddress,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            Chip(
              avatar: Icon(
                orderStatusIcon(order.status),
                size: 18,
                color: statusColor,
              ),
              label: Text(orderStatusLabel(order.status)),
              backgroundColor: statusColor.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (order.isIncomplete) const IncompleteBadge(),
            SyncStatusChip(status: order.syncStatus),
          ],
        ),
        const SizedBox(height: 16),
        if (order.clientName != null)
          _DetailRow(label: 'Cliente', value: order.clientName!),
        if (order.clientPhone != null)
          _DetailRow(label: 'Teléfono', value: order.clientPhone!),
        if (order.amountToCharge != null)
          _DetailRow(
            label: 'Monto a cobrar',
            value: order.amountToCharge!.toStringAsFixed(2),
          ),
        _DetailRow(
          label: 'Pago',
          value: order.paymentStatus == PaymentStatus.cobrado
              ? 'Cobrado'
              : 'Pendiente',
        ),
        if (order.notes != null)
          _DetailRow(label: 'Notas', value: order.notes!),
        if (order.assignedCadeteId != null)
          _CadeteAssignedRow(cadeteId: order.assignedCadeteId!),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.push('/orders/${order.id}/edit'),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
            if (canDeliver)
              FilledButton.icon(
                onPressed: () => _openMarkDeliveredSheet(context, ref, order),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Marcar entregado'),
              ),
            if (canAssignCadete)
              OutlinedButton.icon(
                onPressed: () => _openAssignCadeteSheet(context, ref, order),
                icon: const Icon(Icons.person_add_alt_outlined),
                label: Text(
                  order.assignedCadeteId == null ? 'Asignar cadete' : 'Reasignar cadete',
                ),
              ),
            if (canCancel)
              OutlinedButton.icon(
                onPressed: () => _confirmCancel(context, ref, order),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar pedido'),
              ),
            TextButton.icon(
              onPressed: () => _confirmDelete(context, ref, order),
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              label: Text(
                'Eliminar',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openMarkDeliveredSheet(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final paymentStatus = await showModalBottomSheet<PaymentStatus>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('¿Cómo queda el cobro?'),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Cobrado'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(PaymentStatus.cobrado),
            ),
            ListTile(
              leading: const Icon(Icons.hourglass_empty),
              title: const Text('Cobro pendiente'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(PaymentStatus.pendiente),
            ),
          ],
        ),
      ),
    );
    if (paymentStatus == null) return;
    await ref
        .read(ordersControllerProvider.notifier)
        .markDelivered(order, paymentStatus: paymentStatus);
  }

  Future<void> _openAssignCadeteSheet(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final cadeteId = await showAssignCadeteSheet(context);
    if (cadeteId == null) return;
    await ref
        .read(ordersControllerProvider.notifier)
        .assignCadete(order, cadeteId);
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: const Text('¿Seguro que querés cancelar este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(ordersControllerProvider.notifier).cancelOrder(order);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar pedido'),
        content: const Text('¿Seguro que querés eliminar este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(ordersControllerProvider.notifier).deleteOrder(order.id);
      if (context.mounted && context.canPop()) context.pop();
    }
  }
}

/// Resolves and shows the assigned cadete's display name against the
/// already-fetched [cadeteListProvider] roster, falling back to the raw id
/// while that list is loading/errored/stale — good enough for this
/// read-only row (the picker itself is the source of truth for who gets
/// assigned).
class _CadeteAssignedRow extends ConsumerWidget {
  const _CadeteAssignedRow({required this.cadeteId});

  final String cadeteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cadetesAsync = ref.watch(cadeteListProvider);
    final name = cadetesAsync.maybeWhen(
      data: (cadetes) {
        for (final cadete in cadetes) {
          if (cadete.id == cadeteId) return cadete.displayName;
        }
        return cadeteId;
      },
      orElse: () => cadeteId,
    );
    return _DetailRow(label: 'Cadete asignado', value: name);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
