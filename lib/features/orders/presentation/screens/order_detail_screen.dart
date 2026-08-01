import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/order.dart';
import '../providers.dart';
import '../widgets/incomplete_badge.dart';
import '../widgets/order_card.dart'
    show orderStatusColor, orderStatusIcon, orderStatusLabel;
import '../widgets/payment_pending_banner.dart';
import '../widgets/sync_status_chip.dart';

/// Read view for a single order plus its owner-facing actions: edit,
/// cancel, delete (soft), and "Marcar entregado" — the last one opens a
/// sheet offering `cobrado`/`cobro pendiente`; pending never blocks the
/// transition (spec's "Delivered with pending payment" scenario).
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
