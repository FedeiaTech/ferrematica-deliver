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
///
/// [readOnlyForCadete] (design decision #8 — reuse this screen for the
/// cadete-facing detail view instead of forking it) hides every dueño-only
/// action: "Editar", "Asignar cadete"/"Reasignar cadete", "Cancelar
/// pedido", and "Eliminar". "Marcar entregado" stays visible even in
/// cadete mode — per spec's `cadete-orders`/`order-management` domains the
/// assigned cadete is the one who closes out `en_camino → entregado`
/// through this same flow.
///
/// **PR6**: two cadete-only navigation actions. "Iniciar navegación" shows
/// while `status == asignado` — it calls `OrdersController.startDelivery`
/// (the `asignado → en_camino` transition, per spec's "Cadete starts
/// delivery" scenario) and then pushes `NavigationMapScreen`. "Ver ruta"
/// shows while `status == en_camino` — it only navigates, it never
/// re-triggers the transition (the order is already `en_camino`).
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({
    required this.orderId,
    this.readOnlyForCadete = false,
    super.key,
  });

  final String orderId;
  final bool readOnlyForCadete;

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
          return _OrderDetailBody(
            order: order,
            readOnlyForCadete: readOnlyForCadete,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Error al cargar el pedido: $error')),
      ),
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  const _OrderDetailBody({required this.order, required this.readOnlyForCadete});

  final Order order;
  final bool readOnlyForCadete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDeliver = OrdersController.isValidTransition(
      order.status,
      OrderStatus.entregado,
    );
    final canCancel = !readOnlyForCadete && order.status != OrderStatus.cancelado;
    // Spec's order-assignment requirement: assignable only while
    // pendiente/asignado — once en_camino or later, reassignment is
    // rejected (matches OrdersController.assignCadete's own guard).
    // Dueño-only action — never shown in cadete mode.
    final canAssignCadete =
        !readOnlyForCadete &&
        (order.status == OrderStatus.pendiente || order.status == OrderStatus.asignado);
    // Cadete-only navigation actions (PR6). "Iniciar navegación" triggers
    // the asignado -> en_camino transition before opening the map;
    // "Ver ruta" only reopens the map for an already en_camino order.
    final canStartNavigation = readOnlyForCadete && order.status == OrderStatus.asignado;
    final canViewRoute = readOnlyForCadete && order.status == OrderStatus.enCamino;
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
            if (!readOnlyForCadete)
              OutlinedButton.icon(
                onPressed: () => context.push('/orders/${order.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
            if (canStartNavigation)
              FilledButton.icon(
                onPressed: () => _startNavigation(context, ref, order),
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Iniciar navegación'),
              ),
            if (canViewRoute)
              OutlinedButton.icon(
                onPressed: () => context.push('/delivery/${order.id}/navigate'),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ver ruta'),
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
            if (!readOnlyForCadete)
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

  /// Triggers the `asignado -> en_camino` transition, then pushes the map
  /// screen — per spec's "Cadete starts delivery" scenario, only the
  /// assigned cadete reaches this button (`readOnlyForCadete`-gated).
  /// Navigates regardless of whether the save round-trips instantly; the
  /// map screen itself re-reads the order reactively via
  /// `orderByIdProvider`, so it reflects the now-`en_camino` status as soon
  /// as it lands.
  Future<void> _startNavigation(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    await ref.read(ordersControllerProvider.notifier).startDelivery(order);
    if (context.mounted) {
      context.push('/delivery/${order.id}/navigate');
    }
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
