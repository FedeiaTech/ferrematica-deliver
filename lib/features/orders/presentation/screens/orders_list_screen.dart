import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/order.dart';
import '../providers.dart';
import '../widgets/order_card.dart';
import '../widgets/payment_pending_banner.dart';

/// Entry point for the `pedidos` feature: watches the local order list,
/// lets the dueño filter by status, and surfaces the payment-pending
/// banner (spec's non-blocking dueño alert).
class OrdersListScreen extends ConsumerWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredOrdersProvider);
    final allOrdersAsync = ref.watch(ordersStreamProvider);
    final filter = ref.watch(orderFilterProvider);
    final assignmentFilter = ref.watch(orderAssignmentFilterProvider);

    return Scaffold(
      // No AppBar here — the section title and the map button both live
      // in DuenoHomeScreen's SectionBanner now, not duplicated per-tab.
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/orders/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          allOrdersAsync.when(
            data: (orders) => PaymentPendingBanner(orders: orders),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _StatusFilterMenu(selected: filter),
                _AssignmentFilterMenu(selected: assignmentFilter),
              ],
            ),
          ),
          Expanded(
            child: filteredAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return const Center(child: Text('Todavía no hay pedidos.'));
                }
                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return OrderCard(
                      order: order,
                      isFirst: index == 0,
                      onTap: () => context.push('/orders/${order.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Error al cargar pedidos: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

/// One checkbox in the status filter menu, applying to every [statuses]
/// value at once — [OrderStatus.asignado] has no checkbox of its own
/// (see the "Pendiente" unit below): it's not a lifecycle category the
/// dueño thinks in terms of, it's the assignment CONDITION, which lives
/// entirely in [_AssignmentFilterMenu] instead. Folding it silently into
/// "Pendiente" keeps every [OrderStatus] value reachable through some
/// checkbox without resurrecting "Asignado" as a fake category.
typedef _StatusFilterUnit = ({String label, Set<OrderStatus> statuses});

/// Filter units grouped for the menu, in display order, with a [Divider]
/// rendered between (not within) each group — see `_StatusFilterMenu.build`:
/// 1. Pendientes — "Pendiente" (covers both [OrderStatus.pendiente] and
///    [OrderStatus.asignado] — not yet en route, whoever ends up carrying
///    it) and "En camino" separately.
/// 2. Pendientes de cobro y completados — `entregado` covers both: whether
///    the charge was collected is [Order.paymentStatus], a field the status
///    filter doesn't slice by, so this group has a single checkbox.
/// 3. Cancelados — terminal, unrelated to payment or assignment.
const List<List<_StatusFilterUnit>> _statusGroups = <List<_StatusFilterUnit>>[
  <_StatusFilterUnit>[
    (label: 'Pendiente', statuses: {OrderStatus.pendiente, OrderStatus.asignado}),
    (label: 'En camino', statuses: {OrderStatus.enCamino}),
  ],
  <_StatusFilterUnit>[
    (label: 'Entregado', statuses: {OrderStatus.entregado}),
  ],
  <_StatusFilterUnit>[
    (label: 'Cancelado', statuses: {OrderStatus.cancelado}),
  ],
];

/// Status filter as a multi-select contextual menu: every checkbox applies
/// immediately (no "apply" step) and toggling "Todos" is a shortcut for
/// selecting/deselecting every status at once. Replaces the previous
/// single-select filter chips — the dueño can now show e.g. "Pendiente" and
/// "Entregado" together instead of one status at a time.
///
/// Assignment ("Asignado"/"No asignado") is NOT part of this menu — see
/// [_AssignmentFilterMenu], its own separate control next to this one, not
/// a section nested inside it. They're different kinds of thing: this menu
/// picks lifecycle CATEGORIES ("where is this pedido right now"), the other
/// picks a CONDITION ("who's actually carrying it") that can be true at any
/// status. An earlier version nested assignment inside this menu (as a
/// checkbox under "Asignado" status, then later as a labeled section at the
/// bottom of the same dropdown) — both read as if assignment were part of
/// the status classification, which it isn't, and the first version
/// combined with an `entregado` status filter always produced an empty
/// list for exactly that reason.
///
/// [OrdersListScreen] is currently only reachable from `DuenoHomeScreen`
/// (the cadete's equivalent, `CadeteOrdersScreen`, has no status filter at
/// all — `cadeteOrdersProvider` already scopes it to the cadete's own
/// orders). So there is no cadete-only "assigned to me" restriction filter
/// here to gate behind `session.rol == UserRole.cadete` today; if one is
/// ever added to this menu, follow the same `session.rol` pattern
/// `DeliveryStatsScreen` uses so the dueño keeps seeing every status
/// unrestricted, as today.
class _StatusFilterMenu extends ConsumerWidget {
  const _StatusFilterMenu({required this.selected});

  final Set<OrderStatus> selected;

  String get _buttonLabel {
    if (selected.length == OrderStatus.values.length) return 'Estado: Todos';
    if (selected.isEmpty) return 'Estado: Ninguno';
    for (final group in _statusGroups) {
      for (final unit in group) {
        if (selected.length == unit.statuses.length && selected.containsAll(unit.statuses)) {
          return unit.label;
        }
      }
    }
    return 'Estado: ${selected.length} selec.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSelected = selected.length == OrderStatus.values.length;

    void setFilter(Set<OrderStatus> next) =>
        ref.read(orderFilterProvider.notifier).state = next;

    return MenuAnchor(
      builder: (context, controller, child) {
        return OutlinedButton.icon(
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            minimumSize: const Size(0, 32),
            // Light semi-opaque fill so the button reads clearly against
            // any custom `BrandBackground`, not just the default surface.
            backgroundColor: Colors.white.withValues(alpha: 0.5),
          ),
          icon: const Icon(Icons.filter_list, size: 18),
          label: Text(_buttonLabel),
        );
      },
      menuChildren: [
        CheckboxMenuButton(
          value: allSelected,
          onChanged: (_) =>
              setFilter(allSelected ? const <OrderStatus>{} : OrderStatus.values.toSet()),
          closeOnActivate: false,
          child: const Text('Todos'),
        ),
        for (final group in _statusGroups)
          ...[
            const Divider(height: 1),
            for (final unit in group)
              CheckboxMenuButton(
                value: selected.containsAll(unit.statuses),
                onChanged: (checked) {
                  final next = {...selected};
                  if (checked ?? false) {
                    next.addAll(unit.statuses);
                  } else {
                    next.removeAll(unit.statuses);
                  }
                  setFilter(next);
                },
                closeOnActivate: false,
                child: Text(unit.label),
              ),
          ],
      ],
    );
  }
}

/// Assignment filter — a separate control from [_StatusFilterMenu], not a
/// section inside it (see that class's doc comment for why): "who's
/// actually carrying this order" is a condition orthogonal to its
/// lifecycle status, not one more status category.
class _AssignmentFilterMenu extends ConsumerWidget {
  const _AssignmentFilterMenu({required this.selected});

  final Set<AssignmentFilter> selected;

  String get _buttonLabel {
    if (selected.length == AssignmentFilter.values.length) return 'Asignación: Todos';
    if (selected.isEmpty) return 'Asignación: Ninguno';
    return selected.first == AssignmentFilter.asignado ? 'Asignado' : 'No asignado';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSelected = selected.length == AssignmentFilter.values.length;

    void setFilter(Set<AssignmentFilter> next) =>
        ref.read(orderAssignmentFilterProvider.notifier).state = next;

    return MenuAnchor(
      builder: (context, controller, child) {
        return OutlinedButton.icon(
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            minimumSize: const Size(0, 32),
            // Light semi-opaque fill so the button reads clearly against
            // any custom `BrandBackground`, not just the default surface.
            backgroundColor: Colors.white.withValues(alpha: 0.5),
          ),
          icon: const Icon(Icons.person_pin_circle_outlined, size: 18),
          label: Text(_buttonLabel),
        );
      },
      menuChildren: [
        CheckboxMenuButton(
          value: allSelected,
          onChanged: (_) => setFilter(
            allSelected ? const <AssignmentFilter>{} : AssignmentFilter.values.toSet(),
          ),
          closeOnActivate: false,
          child: const Text('Todos'),
        ),
        const Divider(height: 1),
        for (final assignment in AssignmentFilter.values)
          CheckboxMenuButton(
            value: selected.contains(assignment),
            onChanged: (checked) {
              final next = {...selected};
              if (checked ?? false) {
                next.add(assignment);
              } else {
                next.remove(assignment);
              }
              setFilter(next);
            },
            closeOnActivate: false,
            child: Text(assignment == AssignmentFilter.asignado ? 'Asignado' : 'No asignado'),
          ),
      ],
    );
  }
}
