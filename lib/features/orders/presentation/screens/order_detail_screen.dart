import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../auth/presentation/providers.dart'
    show cadeteListProvider, sessionProvider;
import '../../../delivery/presentation/providers.dart'
    show NavigationRouteData, NavigationTarget, navigationRouteProvider;
import '../../data/providers.dart'
    show linkedVentasLiveProvider, ventasRemoteProvider;
import '../../data/venta_disponible.dart' show VentaDetalleDisponible;
import '../../data/ventas_remote.dart' show LinkedVenta;
import '../../domain/order.dart';
import '../providers.dart';
import '../widgets/assign_cadete_sheet.dart';
import '../widgets/incomplete_badge.dart';
import '../widgets/order_card.dart'
    show orderStatusColor, orderStatusIcon, orderStatusLabel;
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
  const _OrderDetailBody({
    required this.order,
    required this.readOnlyForCadete,
  });

  final Order order;
  final bool readOnlyForCadete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `isValidTransition`'s own `from == to` early-return (true for any
    // status transitioning to itself, a different concern than this check)
    // would otherwise leave `canDeliver` true for an order that's ALREADY
    // entregado — silently re-offering "Marcar entrega" (harmless no-op at
    // worst) alongside "Indicar problema", which is NOT harmless: it
    // cancels the order, reverting a delivery that already, physically,
    // happened. The explicit `!= entregado` guard is the fix.
    final canDeliver =
        order.status != OrderStatus.entregado &&
        OrdersController.isValidTransition(order.status, OrderStatus.entregado);
    // Once entregado, "Cancelar pedido" makes no more sense than
    // "Indicar problema" above does, for the same reason — same guard.
    final canCancel =
        !readOnlyForCadete &&
        order.status != OrderStatus.cancelado &&
        order.status != OrderStatus.entregado;
    // Spec's order-assignment requirement: assignable only while
    // pendiente/asignado — once en_camino or later, reassignment is
    // rejected (matches OrdersController.assignCadete's own guard).
    // Dueño-only action — never shown in cadete mode.
    final canAssignCadete =
        !readOnlyForCadete &&
        (order.status == OrderStatus.pendiente ||
            order.status == OrderStatus.asignado);
    // Cadete-only navigation actions (PR6), also opened up to the dueño
    // when they self-assigned the order to themselves ("Base" in
    // assign_cadete_sheet.dart — no cadete accounts exist yet). "Iniciar
    // navegación" triggers the asignado -> en_camino transition before
    // opening the map; "Ver ruta" only reopens the map for an already
    // en_camino order.
    final session = ref.watch(sessionProvider).value;
    final isSelfAssigned =
        !readOnlyForCadete &&
        session != null &&
        order.assignedCadeteId == session.userId;
    final canNavigateToMap = readOnlyForCadete || isSelfAssigned;
    final canStartNavigation =
        canNavigateToMap && order.status == OrderStatus.asignado;
    final canViewRoute =
        canNavigateToMap && order.status == OrderStatus.enCamino;
    final navigateBasePath = readOnlyForCadete ? '/delivery' : '/orders';
    final statusColor = orderStatusColor(order.status);
    // Design decision D8: a venta_order_links row is never broken once
    // written, so a linked venta that later gets anulada in the POS must be
    // surfaced here instead of silently staying invisible to the dueño —
    // checked across every linked venta, since a pedido can bundle more
    // than one. Polled (not one-shot) and watched in BOTH modes now — the
    // cadete is exactly who needs to be blocked from "Marcar entrega" once
    // the one linked venta is voided, and per the dueño's explicit request
    // this needs to resolve "de forma inmediata" even if the cadete never
    // leaves the navigation screen for the whole trip. A failed poll
    // degrades to the last known value (see linkedVentasLiveProvider) so an
    // offline cadete is never blocked by a check that can't complete.
    final linkedVentasAsync = ref.watch(linkedVentasLiveProvider(order.id));
    final linkedVentas = linkedVentasAsync.maybeWhen(
      data: (ventas) => ventas,
      orElse: () => const <LinkedVenta>[],
    );
    final linkedVentaAnulada = linkedVentas.any(
      (venta) => venta.estado == 'anulada',
    );
    // Dueño-only, same as Editar/Cancelar/Eliminar — retrying is an
    // order-management action, not something the cadete who reported the
    // problem decides on their own. `!linkedVentaAnulada` covers every
    // shape of "this order has a voided venta", not just the single-venta
    // auto-cancel case (_VentaAnuladaLockedView, which never reaches this
    // button at all): a normal cancellation whose venta was — or later
    // became — anulada must ALSO refuse retry, since
    // order_form_screen.dart's retry blindly carries every sourceVentaId
    // item forward and re-claims it on submit without checking whether
    // that venta is still `completada`.
    final canRetry =
        !readOnlyForCadete &&
        order.status == OrderStatus.cancelado &&
        order.deliveryProblem != null &&
        !linkedVentaAnulada;
    // Exactly one linked venta AND it's void: nothing left to deliver.
    // Auto-cancels below (design: block Marcar entrega/Indicar problema/
    // Cancelar pedido alike, not just warn) — two-or-more ventas with only
    // one voided still has real merchandise to deliver, so that case stays
    // a per-line notice instead (_LinkedVentaTile) and never auto-cancels.
    // Also never fires once entregado — the delivery already happened,
    // there is no "un-delivering" it back to cancelado.
    //
    // `ref.listen` (not a plain check + call inline) is the supported way
    // to trigger this kind of imperative side effect from a provider
    // change inside a ConsumerWidget's build — it fires after the frame,
    // never synchronously mid-build. `cancelDueToVentaAnulada` itself
    // no-ops once the order is already cancelado, so a duplicate fire from
    // a later poll tick (or another mounted screen watching the same
    // provider) is harmless.
    ref.listen<AsyncValue<List<LinkedVenta>>>(linkedVentasLiveProvider(order.id), (
      previous,
      next,
    ) {
      final ventas = next.value;
      if (ventas == null ||
          order.status == OrderStatus.cancelado ||
          order.status == OrderStatus.entregado) {
        return;
      }
      final soloVentaAnulada =
          ventas.length == 1 && ventas.single.estado == 'anulada';
      if (soloVentaAnulada) {
        ref.read(ordersControllerProvider.notifier).cancelDueToVentaAnulada(order);
      }
    });
    if (order.status == OrderStatus.cancelado && order.deliveryProblem == kMotivoVentaAnulada) {
      return _VentaAnuladaLockedView(order: order, readOnlyForCadete: readOnlyForCadete);
    }

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
        if (order.hasValidCoordinates) ...[
          const SizedBox(height: 16),
          _OrderRouteMapPreview(
            order: order,
            navigateBasePath: navigateBasePath,
          ),
        ] else ...[
          const SizedBox(height: 16),
          _DetailRow(
            label: 'Ubicación',
            value: 'No se pudo encontrar la coordenada',
          ),
        ],
        if (order.deliveryProblem != null) ...[
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Problema reportado',
            value: order.deliveryProblem!,
            valueIcon: Icons.warning_amber_rounded,
          ),
        ],
        if (order.retriedFromOrderId != null) ...[
          const SizedBox(height: 8),
          _RetryLinkRow(
            label: 'Reintento de',
            targetOrderId: order.retriedFromOrderId!,
          ),
        ],
        if (!readOnlyForCadete) ...[
          Builder(
            builder: (context) {
              final retryAsync = ref.watch(retryOfOrderProvider(order.id));
              final retry = retryAsync.value;
              if (retry == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _RetryLinkRow(
                  label: 'Reintentado en',
                  targetOrderId: retry.id,
                ),
              );
            },
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
          _PricingSummary(
            subtotal: order.amountToCharge!,
            valorEnvio: order.valorEnvio,
            // Only relevant for the still-deliverable multi-venta case —
            // the single-venta-anulada case never reaches this far down
            // the tree (see the _VentaAnuladaLockedView early return above).
            descuentoFacturaAnulada: linkedVentas
                .where((venta) => venta.estado == 'anulada')
                .fold<double>(0, (sum, venta) => sum + venta.total),
          ),
        _DetailRow(
          label: 'Pago',
          valueSpans: [
            if (order.paymentStatus == PaymentStatus.incobrable)
              TextSpan(
                text:
                    'Incobrable'
                    '${(order.pendingBalance ?? order.amountToCharge) != null ? ' (\$${(order.pendingBalance ?? order.amountToCharge!).toStringAsFixed(2)})' : ''}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (order.paymentStatus != PaymentStatus.cobrado)
              const TextSpan(text: 'Pendiente')
            else if (order.pendingBalance == null)
              TextSpan(
                text:
                    'Pago total'
                    '${order.amountToCharge != null ? ' (\$${order.amountToCharge!.toStringAsFixed(2)})' : ''}',
              )
            else ...[
              TextSpan(
                text:
                    'Cobro parcial — cobrado '
                    '\$${(order.amountToCharge! - order.pendingBalance!).toStringAsFixed(2)}, ',
              ),
              TextSpan(
                text: 'falta \$${order.pendingBalance!.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (order.envioPendingBalance != null)
              TextSpan(
                text: '; cadetería pendiente \$${order.envioPendingBalance!.toStringAsFixed(2)}',
              ),
            // "Cobrar" sits right next to the debt it resolves — same
            // request as the dashboard's crossed-dollar indicator: the
            // action lives where the amount owed is already visible,
            // instead of a separate button further down the screen.
            // `!linkedVentaAnulada`: same reasoning as "Marcar incobrable"
            // above — if the sale was voided there's no real debt left to
            // collect against.
            if (!readOnlyForCadete &&
                order.status == OrderStatus.entregado &&
                order.montoAdeudado != null &&
                !linkedVentaAnulada)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: IconButton(
                  onPressed: () => _openCollectPaymentDialog(context, ref, order),
                  icon: Icon(
                    Icons.paid_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: 'Cobrar',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
          ],
        ),
        if (order.paymentStatus == PaymentStatus.incobrable &&
            order.incobrableReason != null)
          _DetailRow(label: 'Motivo (incobrable)', value: order.incobrableReason!),
        if (order.status == OrderStatus.entregado && order.deliveredAt != null)
          _DetailRow(
            label: 'Hora de entrega',
            value: _formatFechaHora(order.deliveredAt!),
          ),
        if (order.notes != null)
          _DetailRow(label: 'Notas', value: order.notes!),
        // Once en_camino, the full "Editar" form is gone (see the Wrap
        // below) — the note is the one thing still worth touching mid-route
        // (e.g. the cadete radios in a gate code), so it gets its own
        // narrow quick-edit instead of reopening the whole order form.
        if (!readOnlyForCadete && order.status == OrderStatus.enCamino)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openEditNoteDialog(context, ref, order),
              icon: const Icon(Icons.edit_note_outlined, size: 18),
              label: Text(order.notes == null ? 'Agregar nota' : 'Editar nota'),
            ),
          ),
        if (order.assignedCadeteId != null)
          _CadeteAssignedRow(cadeteId: order.assignedCadeteId!),
        const SizedBox(height: 24),
        // A cancelado order is a dead end by design — the only way "back"
        // is `canRetry`'s "Reintentar entrega" below, which opens a brand
        // new order pre-filled from this one. Editing or nudging the pin
        // on the cancelled record itself would suggest it can be revived
        // in place, which it can't. Same reasoning for entregado, but for
        // the opposite reason — not a dead end, a *finished* one: the
        // delivery already, physically, happened, at whatever address/pin
        // was on file when it did. Unlike enCamino (which still allows
        // "Corregir ubicación" below), entregado hides BOTH — there's no
        // ongoing navigation left for a corrected pin to help with, paid
        // in full or not.
        if (!readOnlyForCadete &&
            order.status != OrderStatus.cancelado &&
            order.status != OrderStatus.entregado) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // Hidden once en_camino — asignado/no asignado was exactly
              // the boundary meant to gate this: once the cadete is
              // actually driving, the order shouldn't be re-editable out
              // from under them mid-delivery. "Corregir ubicación" stays
              // available, though — the pin is often MORE important to
              // get right once someone is actively navigating to it.
              if (order.status != OrderStatus.enCamino)
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
                  order.assignedCadeteId == null
                      ? 'Asignar cadete'
                      : 'Reasignar cadete',
                ),
              ),
            if (canRetry)
              FilledButton.icon(
                onPressed: () => context.push('/orders/new', extra: order),
                icon: const Icon(Icons.replay_outlined),
                label: const Text('Reintentar entrega'),
              ),
            // `!linkedVentaAnulada`: if the underlying sale was voided,
            // there's no real debt left to write off — the goods (and per
            // the POS's own "Anular" flow, the stock) already went back,
            // so "incobrable" would misrepresent a return as a bad debt.
            if (!readOnlyForCadete && order.needsPaymentFollowUp && !linkedVentaAnulada)
              OutlinedButton.icon(
                onPressed: () => _openMarkIncobrableDialog(context, ref, order),
                icon: Icon(
                  Icons.money_off_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                label: Text(
                  'Marcar incobrable',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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

  /// Parses a comma-or-dot amount, rounded to cents (2 decimals) — the same
  /// rounding [_PartialPaymentStep] applies before computing the resulting
  /// `pendingBalance` — so an entry like `99.999` on a `$100` total is
  /// evaluated as the `$100.00` it rounds to, not the `$99.999` the user
  /// typed. Without this, such a value passed the old unrounded `< total`
  /// check but rounded down to a `pendingBalance` of exactly `0.0`,
  /// violating `Order`'s `pendingBalance > 0` invariant. Returns `null` if
  /// [raw] doesn't parse.
  static double? _parseRoundedAmount(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null) return null;
    return double.parse(value.toStringAsFixed(2));
  }

  /// Returns the step-2 refusal message, or `null` if [raw] is a valid
  /// partial-payment amount (design DA6): a blank/unparseable value, `<= 0`
  /// (use "Cobro pendiente" instead), or `>= total` once rounded to cents
  /// (use "Pago total" instead) are all refused. Every refusal keeps the
  /// confirm button disabled and the user in step 2 — nothing is ever
  /// clamped.
  static String? _partialAmountRefusal(String raw, double total) {
    final value = _parseRoundedAmount(raw);
    if (value == null) return 'Ingresá un monto válido';
    if (value <= 0)
      return 'El monto debe ser mayor a 0 — usá «Cobro pendiente»';
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
          ({
            PaymentStatus status,
            double? pendingBalance,
            double? envioPendingBalance,
          })
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
          envioPendingBalance: result.envioPendingBalance,
        );
    // Marcar entregado es un cierre de flujo, no una edición más — avisamos
    // con un toast y volvemos a la lista en vez de dejar al cadete/dueño
    // parado en el detalle de un pedido que ya terminó.
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pedido entregado')));
    if (context.canPop()) context.pop();
  }

  /// Predefined reasons a delivery couldn't be completed — covers the
  /// dueño's original list plus two common real-world cases they didn't
  /// mention (client not home, wrong/unfindable address — the latter ties
  /// directly into the geocoding-precision limitations elsewhere in this
  /// screen). "Otro" opens a free-text dialog for anything else.
  static const List<String> _deliveryProblemReasons = [
    'Cliente ausente o no atendió',
    'Dirección incorrecta o no encontrada',
    'No recibió porque no pagó',
    'El producto no era el correcto',
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
                          Navigator.of(
                            sheetContext,
                          ).pop('Otro: ${custom.trim()}');
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
    if (!context.mounted) return;
    final confirmed = await _confirmDeliveryProblem(context, reason);
    if (!confirmed) return;
    await ref
        .read(ordersControllerProvider.notifier)
        .reportDeliveryProblem(order, reason: reason);
  }

  /// Reporting a problem cancels the order (`reportDeliveryProblem` sets
  /// `status: OrderStatus.cancelado`) — a real, hard-to-undo consequence
  /// the dueño/cadete should see spelled out before it happens, not
  /// discover after the fact.
  Future<bool> _confirmDeliveryProblem(BuildContext context, String reason) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reportar problema'),
        content: Text(
          'Vas a reportar: "$reason".\n\n'
          'Esto va a CANCELAR el pedido. ¿Confirmás o preferís cancelar '
          'esta elección?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Quick-edit for [Order.notes] on an `en_camino` order — the narrow
  /// replacement for the full "Editar" form once it's hidden (see the
  /// Wrap above). Blank input clears the note entirely
  /// (`copyWith(clearNotes: true)`), not just an empty-string leftover.
  Future<void> _openEditNoteDialog(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final controller = TextEditingController(text: order.notes ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(order.notes == null ? 'Agregar nota' : 'Editar nota'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ej: timbre roto, entrar por el fondo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final text = controller.text.trim();
    await ref
        .read(ordersControllerProvider.notifier)
        .updateOrder(
          text.isEmpty ? order.copyWith(clearNotes: true) : order.copyWith(notes: text),
        );
  }

  /// "Cobrar" — registers a payment against [order]'s [Order.montoAdeudado]
  /// via [OrdersController.collectPayment], covering both an ordinary
  /// pendiente/parcial follow-up AND a late collection on a previously
  /// `incobrable` order with the same two-choice flow: "Pago total"
  /// (clears the debt outright) or "Cobro parcial" (a partial amount,
  /// validated with the same rules as `markDelivered`'s own partial-
  /// payment step — [_parseRoundedAmount]/[_partialAmountRefusal]).
  Future<void> _openCollectPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final total = order.montoAdeudado;
    if (total == null) return;
    final amountController = TextEditingController();
    var showPartialField = false;
    double? confirmedNewBalance;
    var confirmedFull = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final refusal = showPartialField
              ? _partialAmountRefusal(amountController.text, total)
              : null;
          return AlertDialog(
            title: const Text('Cobrar'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Se adeudan \$${total.toStringAsFixed(2)}.'),
                if (showPartialField) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monto cobrado ahora',
                      errorText: amountController.text.isEmpty ? null : refusal,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],
            ),
            actions: showPartialField
                ? [
                    TextButton(
                      onPressed: () => setState(() => showPartialField = false),
                      child: const Text('Atrás'),
                    ),
                    FilledButton(
                      onPressed: refusal != null
                          ? null
                          : () {
                              confirmedNewBalance =
                                  total - _parseRoundedAmount(amountController.text)!;
                              Navigator.of(dialogContext).pop();
                            },
                      child: const Text('Confirmar'),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancelar'),
                    ),
                    OutlinedButton(
                      onPressed: () => setState(() => showPartialField = true),
                      child: const Text('Cobro parcial'),
                    ),
                    FilledButton(
                      onPressed: () {
                        confirmedFull = true;
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text('Pago total'),
                    ),
                  ],
          );
        },
      ),
    );
    if (!confirmedFull && confirmedNewBalance == null) return;
    if (!context.mounted) return;
    await ref
        .read(ordersControllerProvider.notifier)
        .collectPayment(
          order,
          newPendingBalance: confirmedFull ? null : confirmedNewBalance,
        );
  }

  /// "Marcar incobrable" — writes off [order]'s outstanding debt (see
  /// [OrdersController.markIncobrable]: final, no undo, `pendingBalance`
  /// kept as a historical record). Shows the exact amount being written
  /// off before anything happens, plus an optional free-text reason, same
  /// confirm-before-consequence shape as [_confirmDeliveryProblem].
  Future<void> _openMarkIncobrableDialog(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final amount = order.pendingBalance ?? order.amountToCharge;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Marcar incobrable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vas a dar de baja ${amount != null ? '\$${amount.toStringAsFixed(2)}' : 'la deuda'} '
              'de este pedido como incobrable. Esto NO se puede deshacer — '
              'si el cliente paga más adelante, se registra como un cobro '
              'aparte. ¿Confirmás?',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Por qué quedó incobrable',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final reason = reasonController.text.trim();
    await ref
        .read(ordersControllerProvider.notifier)
        .markIncobrable(order, reason: reason.isEmpty ? null : reason);
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
  static const latlong.LatLng _fallbackMapCenter = latlong.LatLng(
    -31.6717,
    -60.7838,
  );

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
        .setManualLocation(
          order,
          latitude: picked.latitude,
          longitude: picked.longitude,
        );
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

/// Content of `_openMarkDeliveredSheet`'s modal (design DA6, extended for
/// cadetería partial collection): step 1 picks `Pago total` / `Cobro
/// parcial` / `Cobro pendiente` for the product subtotal, step 2 (only
/// reachable via `Cobro parcial`, and only offered when
/// `order.amountToCharge` is set) asks for the amount actually collected.
/// When `order.valorEnvio` is set, resolving step 1/2 doesn't pop the sheet
/// yet — it advances to step 3, a follow-up choice for the delivery fee:
/// `Cadetería cobrada completa` / `Cadetería cobro parcial` (step 4, same
/// amount-entry shape as step 2 but against `valorEnvio`) / `Cadetería no
/// cobrada`. Orders with no `valorEnvio` skip step 3/4 entirely and pop
/// immediately, same as before this change. A real `StatefulWidget` (not a
/// `StatefulBuilder` owned by the caller) so [_amountController]/
/// [_envioAmountController] are created and disposed exactly once, tied to
/// this widget's own mount lifecycle — Flutter keeps the sheet's element
/// tree mounted through the modal's closing animation even after `pop()`
/// has already completed the awaited future, so a controller disposed by
/// the *caller* right after that `await` races the animation and throws
/// "used after being disposed". Owning the controllers here means
/// `dispose()` only runs when this widget is actually unmounted, which is
/// after the animation finishes.
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
  final _envioAmountController = TextEditingController();
  var _step = 1;
  PaymentStatus? _resolvedPaymentStatus;
  double? _resolvedPendingBalance;

  @override
  void dispose() {
    _amountController.dispose();
    _envioAmountController.dispose();
    super.dispose();
  }

  /// Resolves the product-side payment outcome (steps 1/2) and either pops
  /// the sheet right away (no `valorEnvio` to ask about) or advances to
  /// step 3 to also resolve the cadetería outcome.
  void _resolveProductPayment(PaymentStatus status, double? pendingBalance) {
    final valorEnvio = widget.order.valorEnvio;
    // `envioPendingBalance` must be strictly > 0 when non-null (mirrors
    // `Order`'s constructor assert / the `orders_envio_pending_balance_valido`
    // CHECK) — a `valorEnvio` of exactly 0 has nothing to collect, so skip
    // step 3 entirely rather than offer choices that could try to set an
    // invalid balance.
    if (valorEnvio == null || valorEnvio <= 0) {
      Navigator.of(context).pop((
        status: status,
        pendingBalance: pendingBalance,
        envioPendingBalance: null,
      ));
      return;
    }
    setState(() {
      _resolvedPaymentStatus = status;
      _resolvedPendingBalance = pendingBalance;
      _step = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.order.amountToCharge;
    final valorEnvio = widget.order.valorEnvio;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: switch (_step) {
          1 => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('¿Cómo queda el cobro?'),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Pago total'),
                onTap: () =>
                    _resolveProductPayment(PaymentStatus.cobrado, null),
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
                onTap: () =>
                    _resolveProductPayment(PaymentStatus.pendiente, null),
              ),
            ],
          ),
          2 => _PartialPaymentStep(
            total: total!,
            controller: _amountController,
            onBack: () => setState(() => _step = 1),
            onConfirm: (balance) =>
                _resolveProductPayment(PaymentStatus.cobrado, balance),
          ),
          3 => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('¿Cómo queda el cobro de la cadetería?'),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Cadetería cobrada completa'),
                onTap: () => Navigator.of(context).pop((
                  status: _resolvedPaymentStatus!,
                  pendingBalance: _resolvedPendingBalance,
                  envioPendingBalance: null,
                )),
              ),
              ListTile(
                leading: const Icon(Icons.percent_outlined),
                title: const Text('Cadetería cobro parcial'),
                onTap: () => setState(() => _step = 4),
              ),
              ListTile(
                leading: const Icon(Icons.hourglass_empty),
                title: const Text('Cadetería no cobrada'),
                onTap: () => Navigator.of(context).pop((
                  status: _resolvedPaymentStatus!,
                  pendingBalance: _resolvedPendingBalance,
                  envioPendingBalance: valorEnvio,
                )),
              ),
            ],
          ),
          _ => _PartialEnvioStep(
            total: valorEnvio!,
            controller: _envioAmountController,
            onBack: () => setState(() => _step = 3),
            onConfirm: (envioBalance) => Navigator.of(context).pop((
              status: _resolvedPaymentStatus!,
              pendingBalance: _resolvedPendingBalance,
              envioPendingBalance: envioBalance,
            )),
          ),
        },
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
      color: anulada ? Theme.of(context).colorScheme.errorContainer : null,
      child: ExpansionTile(
        title: Text('Factura Nº ${venta.ventaLocalId}'),
        // Bundled-order case (2+ ventas, only this one anulada): the
        // delivery keeps going for the rest, so this stays a per-line
        // notice, not a full block — same wording as the single-venta
        // auto-cancel case (kMotivoVentaAnulada), scoped to just this
        // invoice's merchandise instead of the whole pedido.
        subtitle: anulada
            ? Text(
                kMotivoVentaAnulada,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
        leading: anulada
            ? Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
              )
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
              final detalles =
                  snapshot.data ?? const <VentaDetalleDisponible>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final detalle in detalles)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${detalle.descripcion} x${detalle.cantidad}',
                                  ),
                                ),
                                if (detalle.comboId != null) ...[
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Combo',
                                    style: TextStyle(
                                      color: Colors.deepPurple,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
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

/// Locked-out replacement for the normal cancelado view, shown only when
/// [Order.deliveryProblem] is the [kMotivoVentaAnulada] sentinel — the
/// pedido's one linked venta was voided in the POS, auto-cancelling it
/// (`OrdersController.cancelDueToVentaAnulada`). Every normal action
/// (Marcar entrega, Indicar problema, Cancelar pedido) is gone — there's
/// nothing left to deliver — replaced by a single red instruction and a
/// gray, non-interactive placeholder where the live map used to be (no
/// `FlutterMap` at all here, so there's no route/destination left to draw
/// and no way to tap back into navigation).
///
/// Deliberately does NOT offer "Reintentar entrega" (unlike the ordinary
/// cancelado view) — that flow carries the source order's items straight
/// through, `sourceVentaId` included, and re-claims them blind on submit
/// (`order_form_screen.dart`'s retry init + `OrdersController.createOrder`'s
/// `fromVentaIds`) — `claimVenta` only checks whether the claim is
/// currently ACTIVE, never whether the venta itself is still `completada`.
/// Since this auto-cancel just released that exact claim, a "retry" here
/// would silently re-link the new pedido to the SAME voided sale. The only
/// path forward is "Eliminar" this record and create a genuinely new
/// pedido (the "+" button) once the merchandise situation is sorted and a
/// real venta exists to back it.
class _VentaAnuladaLockedView extends ConsumerWidget {
  const _VentaAnuladaLockedView({
    required this.order,
    required this.readOnlyForCadete,
  });

  final Order order;
  final bool readOnlyForCadete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 12),
        Text(order.deliveryAddress, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.block, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  kMotivoVentaAnulada,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (order.latitude != null && order.longitude != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 140,
              width: double.infinity,
              color: Colors.grey.shade400,
              alignment: Alignment.center,
              child: Icon(Icons.map_outlined, color: Colors.grey.shade700, size: 36),
            ),
          ),
        ],
        if (!readOnlyForCadete) ...[
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => _confirmDeleteVentaAnulada(context, ref, order),
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
      ],
    );
  }

  Future<void> _confirmDeleteVentaAnulada(
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
  const _OrderRouteMapPreview({
    required this.order,
    required this.navigateBasePath,
  });

  final Order order;
  final String navigateBasePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = latlong.LatLng(order.latitude!, order.longitude!);
    // A `cancelado`/`entregado` order is a closed case — there's no
    // "current device location" worth tracking and no route left to drive,
    // so this skips `navigationRouteProvider` entirely (no Directions call,
    // no location permission prompt) and shows the destination pin alone,
    // colored green like `orderStatusColor`'s `entregado` to read as
    // "done" at a glance instead of the active/pending red.
    final isTerminal =
        order.status == OrderStatus.entregado || order.status == OrderStatus.cancelado;
    final destinationMarker = Marker(
      point: destination,
      width: 40,
      height: 40,
      alignment: Alignment.topCenter,
      child: Icon(
        Icons.location_pin,
        color: isTerminal ? Colors.green.shade700 : Colors.red,
        size: 40,
      ),
    );

    void openFullMap() =>
        context.push('$navigateBasePath/${order.id}/navigate');

    return GestureDetector(
      onTap: openFullMap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 260,
          child: Stack(
            children: [
              Positioned.fill(
                child: isTerminal
                    ? _StaticLocationMapPreview(
                        destination: destination,
                        destinationMarker: destinationMarker,
                      )
                    : _RouteMapPreviewContent(
                        routeAsync: ref.watch(
                          navigationRouteProvider(
                            NavigationTarget(
                              orderId: order.id,
                              latitude: order.latitude!,
                              longitude: order.longitude!,
                            ),
                          ),
                        ),
                        destination: destination,
                        destinationMarker: destinationMarker,
                      ),
              ),
              // Explicit affordance to open the full interactive map before
              // the trip starts (not just once "Iniciar navegación" is
              // tapped) — the whole preview is already tappable for this,
              // but a visible icon makes it discoverable instead of relying
              // on "the map itself is a button" being obvious.
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.85),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: openFullMap,
                    icon: const Icon(Icons.fullscreen),
                    tooltip: 'Ver mapa completo',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marker-only map for a terminal (`entregado`/`cancelado`) order — no
/// `navigationRouteProvider` watch, so no live location fetch or Directions
/// call happens for an order that's no longer being driven to.
class _StaticLocationMapPreview extends StatelessWidget {
  const _StaticLocationMapPreview({
    required this.destination,
    required this.destinationMarker,
  });

  final latlong.LatLng destination;
  final Marker destinationMarker;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: destination,
        initialZoom: 14,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ferrematica.express',
        ),
        MarkerLayer(markers: [destinationMarker]),
        RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}

/// Extracted so [_OrderRouteMapPreview.build] can layer the top-right
/// "open full map" button over it inside a [Stack] without duplicating the
/// `routeAsync.when(...)` branches.
class _RouteMapPreviewContent extends StatelessWidget {
  const _RouteMapPreviewContent({
    required this.routeAsync,
    required this.destination,
    required this.destinationMarker,
  });

  final AsyncValue<NavigationRouteData> routeAsync;
  final latlong.LatLng destination;
  final Marker destinationMarker;

  @override
  Widget build(BuildContext context) {
    return routeAsync.when(
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
                  .map(
                    (point) => latlong.LatLng(point.latitude, point.longitude),
                  )
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
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
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
                                        _OrderDetailBody._parseRoundedAmount(
                                          rawText,
                                        )!)
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

/// Step 4 of `_openMarkDeliveredSheet` — the cadetería equivalent of
/// [_PartialPaymentStep]: how much of `valorEnvio` was actually collected.
/// Same shape/validation as [_PartialPaymentStep] (reuses
/// [_OrderDetailBody._partialAmountRefusal]/[_OrderDetailBody._parseRoundedAmount]
/// since the amount-vs-total validation rule is identical), just against
/// [total] = `order.valorEnvio` instead of `order.amountToCharge`, and
/// [onConfirm] receives the resulting `envioPendingBalance` instead of
/// `pendingBalance`.
class _PartialEnvioStep extends StatelessWidget {
  const _PartialEnvioStep({
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
              Text(
                'Cadetería — cobro parcial, total \$${total.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Monto cobrado de cadetería',
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
                                        _OrderDetailBody._parseRoundedAmount(
                                          rawText,
                                        )!)
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

/// Shared `dd/mm/yyyy hh:mm` formatter — same shape as
/// `_LinkedVentaTileState._formatFecha`/`_formatHora`, kept as its own
/// top-level function here since it's used outside that class too (the
/// "Hora de entrega" row).
String _formatFechaHora(DateTime fecha) {
  final local = fecha.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Subtotal (bold) / Envío / Total (bold) breakdown — display-only, never
/// persisted as a computed field (design: "el valor total no es necesario
/// registrarlo en la factura"). [subtotal] is [Order.amountToCharge];
/// [valorEnvio] is added on top when non-null, shown as "-" otherwise.
///
/// [descuentoFacturaAnulada] is display-only too — [subtotal] itself is
/// never mutated (it's the dueño's own charge figure, tied to
/// pendingBalance's invariants elsewhere), so a still-bundled order with
/// one voided venta among several shows the original subtotal, an explicit
/// "Factura anulada" deduction line, and a Total that nets the two —
/// letting the dueño see at a glance what actually still needs collecting
/// without silently rewriting the stored amount.
class _PricingSummary extends StatelessWidget {
  const _PricingSummary({
    required this.subtotal,
    required this.valorEnvio,
    this.descuentoFacturaAnulada = 0,
  });

  final double subtotal;
  final double? valorEnvio;
  final double descuentoFacturaAnulada;

  @override
  Widget build(BuildContext context) {
    final total = subtotal - descuentoFacturaAnulada + (valorEnvio ?? 0);
    const boldStyle = TextStyle(fontWeight: FontWeight.bold);
    // Total is bold too (like Subtotal) but needs to stand out as the
    // headline figure, not just match Subtotal's weight — larger and in
    // the theme's primary color, set off by a divider above it.
    final totalStyle = boldStyle.copyWith(
      fontSize: 18,
      color: Theme.of(context).colorScheme.primary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 120,
                child: Text('Subtotal', style: boldStyle),
              ),
              Text('\$${subtotal.toStringAsFixed(2)}', style: boldStyle),
            ],
          ),
          if (descuentoFacturaAnulada > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      'Factura anulada',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                  Text(
                    '-\$${descuentoFacturaAnulada.toStringAsFixed(2)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                const SizedBox(width: 120, child: Text('Envío')),
                Text(
                  valorEnvio != null
                      ? '\$${valorEnvio!.toStringAsFixed(2)}'
                      : '-',
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                SizedBox(width: 120, child: Text('Total', style: totalStyle)),
                Text('\$${total.toStringAsFixed(2)}', style: totalStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable [_DetailRow]-shaped link to another order in the same retry
/// chain — either the order this one was retried FROM
/// ([Order.retriedFromOrderId]) or the retry created FROM this one
/// ([retryOfOrderProvider]). Always navigates to `/orders/:id`, a
/// dueño-only route, so both call sites gate this to `!readOnlyForCadete`.
class _RetryLinkRow extends StatelessWidget {
  const _RetryLinkRow({required this.label, required this.targetOrderId});

  final String label;
  final String targetOrderId;

  @override
  Widget build(BuildContext context) {
    final linkColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => context.push('/orders/$targetOrderId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.replay_outlined, size: 18, color: linkColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Ver pedido',
                style: TextStyle(color: linkColor, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, this.value, this.valueSpans, this.valueIcon})
    : assert(
        (value == null) != (valueSpans == null),
        'pass exactly one of value or valueSpans',
      );

  final String? value;

  /// Alternative to [value] for a row that needs mixed styling within a
  /// single line (e.g. the still-owed portion of "Pago" in red) — pass
  /// this instead of [value] when a single [TextStyle] can't express it.
  final List<InlineSpan>? valueSpans;

  final String label;

  /// Shown before the value when set — e.g. a red warning icon on the
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
            Icon(
              valueIcon,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: valueSpans != null
                ? Text.rich(
                    TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: valueSpans,
                    ),
                  )
                : Text(value!),
          ),
        ],
      ),
    );
  }
}
