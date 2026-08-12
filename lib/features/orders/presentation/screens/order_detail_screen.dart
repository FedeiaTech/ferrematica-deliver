import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../auth/presentation/providers.dart'
    show cadeteListProvider, sessionProvider;
import '../../../delivery/presentation/providers.dart'
    show NavigationTarget, navigationRouteProvider;
import '../../data/providers.dart' show linkedVentasProvider, ventasRemoteProvider;
import '../../data/venta_disponible.dart' show VentaDetalleDisponible;
import '../../data/ventas_remote.dart' show LinkedVenta;
import '../../domain/order.dart';
import '../providers.dart';
import '../widgets/assign_cadete_sheet.dart';
import '../widgets/incomplete_badge.dart';
import '../widgets/order_card.dart' show orderStatusColor, orderStatusIcon, orderStatusLabel;
import '../widgets/sync_status_chip.dart';
import 'location_picker_screen.dart';

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
    // No-op unless this order has coordinates but no resolved city yet
    // (see resolvedCityBackfillProvider's doc comment).
    ref.watch(resolvedCityBackfillProvider(orderId));

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
    // Cadete-only navigation actions (PR6), also opened up to the dueño
    // when they self-assigned the order to themselves ("Base" in
    // assign_cadete_sheet.dart — no cadete accounts exist yet). "Iniciar
    // navegación" triggers the asignado -> en_camino transition before
    // opening the map; "Ver ruta" only reopens the map for an already
    // en_camino order.
    final session = ref.watch(sessionProvider).value;
    final isSelfAssigned = !readOnlyForCadete &&
        session != null &&
        order.assignedCadeteId == session.userId;
    final canNavigateToMap = readOnlyForCadete || isSelfAssigned;
    final canStartNavigation = canNavigateToMap && order.status == OrderStatus.asignado;
    final canViewRoute = canNavigateToMap && order.status == OrderStatus.enCamino;
    final navigateBasePath = readOnlyForCadete ? '/delivery' : '/orders';
    // Dueño-only, same as Editar/Cancelar/Eliminar — retrying is an
    // order-management action, not something the cadete who reported the
    // problem decides on their own.
    final canRetry =
        !readOnlyForCadete &&
        order.status == OrderStatus.cancelado &&
        order.deliveryProblem != null;
    final statusColor = orderStatusColor(order.status);
    // Design decision D8: a venta_order_links row is never broken once
    // written, so a linked venta that later gets anulada in the POS must be
    // surfaced here instead of silently staying invisible to the dueño —
    // checked across every linked venta, since a pedido can bundle more
    // than one. Cadete mode skips the check — it's dueño-facing
    // information, and avoids an extra Supabase round trip on a screen the
    // cadete may open offline mid-delivery.
    final linkedVentas = readOnlyForCadete
        ? const <LinkedVenta>[]
        : ref.watch(linkedVentasProvider(order.id)).maybeWhen(
              data: (ventas) => ventas,
              orElse: () => const <LinkedVenta>[],
            );
    final linkedVentaAnulada = linkedVentas.any((venta) => venta.estado == 'anulada');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        if (linkedVentaAnulada) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La venta del POS vinculada a este pedido fue anulada.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (order.latitude != null && order.longitude != null) ...[
          const SizedBox(height: 16),
          _OrderRouteMapPreview(order: order, navigateBasePath: navigateBasePath),
        ] else ...[
          const SizedBox(height: 16),
          _DetailRow(label: 'Ubicación', value: 'No se pudo encontrar la coordenada'),
        ],
        if (order.deliveryProblem != null) ...[
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Problema reportado',
            value: order.deliveryProblem!,
            valueIcon: Icons.warning_amber_rounded,
          ),
        ],
        const SizedBox(height: 16),
        if (linkedVentas.isNotEmpty) ...[
          _LinkedVentasSection(linkedVentas: linkedVentas),
          const SizedBox(height: 8),
        ],
        if (order.clientName != null)
          _DetailRow(label: 'Cliente', value: order.clientName!),
        if (order.resolvedCity != null)
          _DetailRow(label: 'Ciudad', value: order.resolvedCity!),
        if (order.clientPhone != null)
          _DetailRow(label: 'Teléfono', value: order.clientPhone!),
        if (order.amountToCharge != null)
          _DetailRow(
            label: 'Monto a cobrar',
            value: order.amountToCharge!.toStringAsFixed(2),
          ),
        _DetailRow(
          label: 'Pago',
          value: order.paymentStatus != PaymentStatus.cobrado
              ? 'Pendiente'
              : order.pendingBalance == null
              ? 'Pago total'
                    '${order.amountToCharge != null ? ' (\$${order.amountToCharge!.toStringAsFixed(2)})' : ''}'
              : 'Cobro parcial — cobrado '
                    '\$${(order.amountToCharge! - order.pendingBalance!).toStringAsFixed(2)}, '
                    'falta \$${order.pendingBalance!.toStringAsFixed(2)}',
        ),
        if (order.notes != null)
          _DetailRow(label: 'Notas', value: order.notes!),
        if (order.assignedCadeteId != null)
          _CadeteAssignedRow(cadeteId: order.assignedCadeteId!),
        const SizedBox(height: 24),
        if (!readOnlyForCadete) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/orders/${order.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: () => _correctLocation(context, ref, order),
                icon: const Icon(Icons.pin_drop_outlined),
                label: const Text('Corregir ubicación'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (canStartNavigation)
              FilledButton.icon(
                onPressed: () =>
                    _startNavigation(context, ref, order, navigateBasePath),
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Iniciar navegación'),
              ),
            if (canViewRoute)
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('$navigateBasePath/${order.id}/navigate'),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ver ruta'),
              ),
            if (canDeliver)
              FilledButton.icon(
                onPressed: () => _openMarkDeliveredSheet(context, ref, order),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Marcar entrega'),
              ),
            if (canDeliver)
              OutlinedButton.icon(
                onPressed: () => _openDeliveryProblemSheet(context, ref, order),
                icon: Icon(
                  Icons.report_problem_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                label: Text(
                  'Indicar problema',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (canAssignCadete)
              OutlinedButton.icon(
                onPressed: () => _openAssignCadeteSheet(context, ref, order),
                icon: const Icon(Icons.person_add_alt_outlined),
                label: Text(
                  order.assignedCadeteId == null ? 'Asignar cadete' : 'Reasignar cadete',
                ),
              ),
            if (canRetry)
              FilledButton.icon(
                onPressed: () => context.push('/orders/new', extra: order),
                icon: const Icon(Icons.replay_outlined),
                label: const Text('Reintentar entrega'),
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

  /// Parses a comma-or-dot amount and returns the step-2 refusal message,
  /// or `null` if [raw] is a valid partial-payment amount (design DA6): a
  /// blank/unparseable value, `<= 0` (use "Cobro pendiente" instead), or
  /// `>= total` (use "Pago total" instead) are all refused. Every refusal
  /// keeps the confirm button disabled and the user in step 2 — nothing is
  /// ever clamped.
  static String? _partialAmountRefusal(String raw, double total) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null) return 'Ingresá un monto válido';
    if (value <= 0) return 'El monto debe ser mayor a 0 — usá «Cobro pendiente»';
    if (value >= total) return 'Ese es el total — usá «Pago total»';
    return null;
  }

  Future<void> _openMarkDeliveredSheet(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final result =
        await showModalBottomSheet<
          ({PaymentStatus status, double? pendingBalance})
        >(
          context: context,
          isScrollControlled: true,
          // Sheet content lives in its own `StatefulWidget` (not a
          // `StatefulBuilder` owned by this method) precisely so its
          // `TextEditingController` is disposed by Flutter's normal
          // `State.dispose()` lifecycle — i.e. only once the sheet's
          // closing animation actually finishes unmounting it. A
          // controller created here and disposed right after this
          // `await` returns races the reverse transition: `pop()`
          // completes the future immediately, while the sheet widget
          // (and its still-focused `TextField`) stays mounted for a few
          // more animated frames — disposing eagerly throws "used after
          // being disposed" mid-animation.
          builder: (sheetContext) => _MarkDeliveredSheetContent(order: order),
        );
    if (result == null) return;
    await ref
        .read(ordersControllerProvider.notifier)
        .markDelivered(
          order,
          paymentStatus: result.status,
          pendingBalance: result.pendingBalance,
        );
    // Marcar entregado es un cierre de flujo, no una edición más — avisamos
    // con un toast y volvemos a la lista en vez de dejar al cadete/dueño
    // parado en el detalle de un pedido que ya terminó.
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pedido entregado')),
    );
    if (context.canPop()) context.pop();
  }

  /// Predefined reasons a delivery couldn't be completed — covers the
  /// dueño's original list plus two common real-world cases they didn't
  /// mention (client not home, wrong/unfindable address — the latter ties
  /// directly into the geocoding-precision limitations elsewhere in this
  /// screen). "Otro" opens a free-text dialog for anything else.
  static const List<String> _deliveryProblemReasons = [
    'Cliente ausente o no atendió',
    'El cliente no pagó',
    'El producto no llegó',
    'El producto no era el correcto',
    'Dirección incorrecta o no encontrada',
    'Inconveniente con el vehículo',
  ];

  Future<void> _openDeliveryProblemSheet(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('¿Cuál fue el problema con la entrega?'),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final reason in _deliveryProblemReasons)
                      ListTile(
                        title: Text(reason),
                        onTap: () => Navigator.of(sheetContext).pop(reason),
                      ),
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Otro'),
                      onTap: () async {
                        final custom = await _promptCustomProblem(sheetContext);
                        if (custom == null || custom.trim().isEmpty) return;
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop('Otro: ${custom.trim()}');
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (reason == null) return;
    await ref
        .read(ordersControllerProvider.notifier)
        .reportDeliveryProblem(order, reason: reason);
  }

  Future<String?> _promptCustomProblem(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Indicar problema'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Describí qué pasó'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
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
    String navigateBasePath,
  ) async {
    await ref.read(ordersControllerProvider.notifier).startDelivery(order);
    if (context.mounted) {
      context.push('$navigateBasePath/${order.id}/navigate');
    }
  }

  Future<void> _openAssignCadeteSheet(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final result = await showAssignCadeteSheet(
      context,
      allowUnassign: order.status == OrderStatus.asignado,
    );
    if (result == null) return;
    final controller = ref.read(ordersControllerProvider.notifier);
    if (result == kUnassignCadeteSentinel) {
      await controller.unassignCadete(order);
    } else {
      await controller.assignCadete(order, result);
    }
  }

  /// Fallback center for the manual location picker when the order has no
  /// coordinates yet — approximately Santo Tomé, Santa Fe (the default
  /// city hint in `_CitySelector`), just so the map doesn't open zoomed
  /// out over the whole world.
  static const latlong.LatLng _fallbackMapCenter = latlong.LatLng(-31.6717, -60.7838);

  Future<void> _correctLocation(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final initialCenter = order.latitude != null && order.longitude != null
        ? latlong.LatLng(order.latitude!, order.longitude!)
        : _fallbackMapCenter;
    final picked = await Navigator.of(context).push<latlong.LatLng>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialCenter: initialCenter),
      ),
    );
    if (picked == null) return;
    await ref
        .read(ordersControllerProvider.notifier)
        .setManualLocation(order, latitude: picked.latitude, longitude: picked.longitude);
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

/// Content of `_openMarkDeliveredSheet`'s modal (design DA6): a two-step
/// flow — step 1 picks `Pago total` / `Cobro parcial` / `Cobro pendiente`,
/// step 2 (only reachable via `Cobro parcial`, and only offered when
/// `order.amountToCharge` is set) asks for the amount actually collected.
/// A real `StatefulWidget` (not a `StatefulBuilder` owned by the caller) so
/// [_amountController] is created and disposed exactly once, tied to this
/// widget's own mount lifecycle — Flutter keeps the sheet's element tree
/// mounted through the modal's closing animation even after `pop()` has
/// already completed the awaited future, so a controller disposed by the
/// *caller* right after that `await` races the animation and throws "used
/// after being disposed". Owning the controller here means `dispose()`
/// only runs when this widget is actually unmounted, which is after the
/// animation finishes.
class _MarkDeliveredSheetContent extends StatefulWidget {
  const _MarkDeliveredSheetContent({required this.order});

  final Order order;

  @override
  State<_MarkDeliveredSheetContent> createState() =>
      _MarkDeliveredSheetContentState();
}

class _MarkDeliveredSheetContentState
    extends State<_MarkDeliveredSheetContent> {
  final _amountController = TextEditingController();
  var _step = 1;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.order.amountToCharge;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: _step == 1
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('¿Cómo queda el cobro?'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: const Text('Pago total'),
                    onTap: () => Navigator.of(context).pop((
                      status: PaymentStatus.cobrado,
                      pendingBalance: null,
                    )),
                  ),
                  if (total != null && total > 0)
                    ListTile(
                      leading: const Icon(Icons.percent_outlined),
                      title: const Text('Cobro parcial'),
                      onTap: () => setState(() => _step = 2),
                    ),
                  ListTile(
                    leading: const Icon(Icons.hourglass_empty),
                    title: const Text('Cobro pendiente'),
                    onTap: () => Navigator.of(context).pop((
                      status: PaymentStatus.pendiente,
                      pendingBalance: null,
                    )),
                  ),
                ],
              )
            : _PartialPaymentStep(
                total: total!,
                controller: _amountController,
                onBack: () => setState(() => _step = 1),
                onConfirm: (balance) => Navigator.of(context).pop((
                  status: PaymentStatus.cobrado,
                  pendingBalance: balance,
                )),
              ),
      ),
    );
  }
}

/// One [ExpansionTile] per venta linked to this order (`linkedVentasProvider`
/// — a pedido can bundle more than one POS sale since the multi-venta
/// change). The collapsed header just names the invoice ("Factura Nº ...");
/// expanding it reveals fecha/hora/monto plus the full product detail.
class _LinkedVentasSection extends StatelessWidget {
  const _LinkedVentasSection({required this.linkedVentas});

  final List<LinkedVenta> linkedVentas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          linkedVentas.length == 1 ? 'Venta vinculada' : 'Ventas vinculadas',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        for (final venta in linkedVentas) _LinkedVentaTile(venta: venta),
      ],
    );
  }
}

/// A single linked venta's expandable detail. The product-line fetch
/// (`VentasRemote.fetchDetalleVenta`) is lazy — triggered only the first
/// time this tile is expanded, then cached in [_detalleFuture] for the rest
/// of this tile's lifetime, so a dueño who never opens a tile never pays
/// for the extra round trip.
class _LinkedVentaTile extends ConsumerStatefulWidget {
  const _LinkedVentaTile({required this.venta});

  final LinkedVenta venta;

  @override
  ConsumerState<_LinkedVentaTile> createState() => _LinkedVentaTileState();
}

class _LinkedVentaTileState extends ConsumerState<_LinkedVentaTile> {
  Future<List<VentaDetalleDisponible>>? _detalleFuture;

  void _onExpansionChanged(bool expanded) {
    if (!expanded || _detalleFuture != null) return;
    setState(() {
      _detalleFuture = ref
          .read(ventasRemoteProvider)
          .fetchDetalleVenta(
            installId: widget.venta.installId,
            ventaLocalId: widget.venta.ventaLocalId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final venta = widget.venta;
    final anulada = venta.estado == 'anulada';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text('Factura Nº ${venta.ventaLocalId}'),
        leading: anulada
            ? Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error)
            : null,
        onExpansionChanged: _onExpansionChanged,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _DetailRow(label: 'Fecha', value: _formatFecha(venta.fecha)),
          _DetailRow(label: 'Hora', value: _formatHora(venta.fecha)),
          _DetailRow(label: 'Monto', value: venta.total.toStringAsFixed(2)),
          const SizedBox(height: 8),
          FutureBuilder<List<VentaDetalleDisponible>>(
            future: _detalleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return const Text('No se pudo cargar el detalle de la venta.');
              }
              final detalles = snapshot.data ?? const <VentaDetalleDisponible>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final detalle in detalles)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${detalle.descripcion} x${detalle.cantidad}'),
                          ),
                          Text(detalle.subtotal.toStringAsFixed(2)),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _formatFecha(DateTime fecha) {
    final local = fecha.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }

  static String _formatHora(DateTime fecha) {
    final local = fecha.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}

/// Resolves and shows the assigned cadete's display name against the
/// already-fetched [cadeteListProvider] roster. `cadeteListProvider` only
/// returns `rol = 'cadete'` profiles, so an id that isn't in that list is
/// either the "Base" (dueño self-delivery) fallback from
/// `assign_cadete_sheet.dart` or a stale/orphaned id — shown as `-` rather
/// than a raw UID, which would look like a data-integrity bug to a
/// non-technical dueño.
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
        return '-';
      },
      orElse: () => '-',
    );
    return _DetailRow(label: 'Cadete asignado', value: name);
  }
}

/// Large, tappable route preview shown on every order that has resolved
/// coordinates (dueño's request: "a map on each pedido, big, so you don't
/// miss it with your finger, showing the route from where you are to the
/// delivery point"). The whole map area is the tap target — interaction
/// gestures (pan/zoom) are disabled on this preview so a stray drag can't
/// be mistaken for a tap — leading to the full [NavigationMapScreen] at
/// `$navigateBasePath/:id/navigate` for a proper interactive view.
///
/// Shown regardless of role/assignment — it's read-only and never
/// triggers a status transition (unlike "Iniciar navegación"/"Ver ruta",
/// which stay gated to the assigned cadete or a self-assigned dueño).
class _OrderRouteMapPreview extends ConsumerWidget {
  const _OrderRouteMapPreview({required this.order, required this.navigateBasePath});

  final Order order;
  final String navigateBasePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = NavigationTarget(
      orderId: order.id,
      latitude: order.latitude!,
      longitude: order.longitude!,
    );
    final routeAsync = ref.watch(navigationRouteProvider(target));
    final destination = latlong.LatLng(order.latitude!, order.longitude!);
    final destinationMarker = Marker(
      point: destination,
      width: 40,
      height: 40,
      alignment: Alignment.topCenter,
      child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
    );

    return GestureDetector(
      onTap: () => context.push('$navigateBasePath/${order.id}/navigate'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 260,
          child: routeAsync.when(
            data: (data) {
              final markers = <Marker>[destinationMarker];
              final polylines = <Polyline>[];
              if (data.currentLocation != null) {
                markers.add(
                  Marker(
                    point: latlong.LatLng(
                      data.currentLocation!.latitude,
                      data.currentLocation!.longitude,
                    ),
                    width: 30,
                    height: 30,
                    child: const Icon(Icons.my_location, color: Colors.blue),
                  ),
                );
              }
              if (data.route != null) {
                polylines.add(
                  Polyline(
                    points: data.route!.polylinePoints
                        .map((point) => latlong.LatLng(point.latitude, point.longitude))
                        .toList(growable: false),
                    strokeWidth: 4,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                );
              }
              return FlutterMap(
                options: MapOptions(
                  initialCenter: data.currentLocation != null
                      ? latlong.LatLng(
                          data.currentLocation!.latitude,
                          data.currentLocation!.longitude,
                        )
                      : destination,
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ferrematica.express',
                  ),
                  PolylineLayer(polylines: polylines),
                  MarkerLayer(markers: markers),
                  // Required by OpenStreetMap's tile usage policy — see
                  // https://operations.osmfoundation.org/policies/tiles/.
                  RichAttributionWidget(
                    attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Container(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Center(
                child: Text(
                  'No se pudo calcular la ruta.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Step 2 of `_openMarkDeliveredSheet` (design DA6) — the amount actually
/// collected. Wraps [controller] (owned/disposed by the caller so a modal
/// rebuild never recreates it mid-typing) in a [ValueListenableBuilder] so
/// [_OrderDetailBody._partialAmountRefusal] re-evaluates on every keystroke
/// without needing its own [StatefulWidget] state.
class _PartialPaymentStep extends StatelessWidget {
  const _PartialPaymentStep({
    required this.total,
    required this.controller,
    required this.onBack,
    required this.onConfirm,
  });

  final double total;
  final TextEditingController controller;
  final VoidCallback onBack;
  final ValueChanged<double> onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final rawText = value.text;
          final refusal = _OrderDetailBody._partialAmountRefusal(
            rawText,
            total,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cobro parcial — total \$${total.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Monto cobrado',
                  border: const OutlineInputBorder(),
                  errorText: rawText.isEmpty ? null : refusal,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onBack,
                      child: const Text('Volver'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: refusal == null
                          ? () => onConfirm(
                              double.parse(
                                (total -
                                        double.parse(
                                          rawText.trim().replaceAll(',', '.'),
                                        ))
                                    .toStringAsFixed(2),
                              ),
                            )
                          : null,
                      child: const Text('Confirmar'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueIcon});

  final String label;
  final String value;
  /// Shown before [value] when set — e.g. a red warning icon on the
  /// "Problema reportado" row, so a failed delivery stands out at a
  /// glance instead of reading identically to every other detail row.
  final IconData? valueIcon;

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
          if (valueIcon != null) ...[
            Icon(valueIcon, size: 18, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
