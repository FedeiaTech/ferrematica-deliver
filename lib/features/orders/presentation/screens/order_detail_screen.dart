import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../auth/presentation/providers.dart'
    show cadeteListProvider, sessionProvider;
import '../../../delivery/presentation/providers.dart'
    show NavigationTarget, navigationRouteProvider;
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
          value: order.paymentStatus == PaymentStatus.cobrado
              ? 'Cobrado'
              : 'Pendiente',
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
