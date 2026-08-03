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
    final onlyUnassigned = ref.watch(orderShowOnlyUnassignedProvider);

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
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusFilterMenu(selected: filter, onlyUnassigned: onlyUnassigned),
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

/// Status filter as a multi-select contextual menu: every checkbox applies
/// immediately (no "apply" step) and toggling "Todos" is a shortcut for
/// selecting/deselecting every individual status at once. Replaces the
/// previous single-select filter chips — the dueño can now show e.g.
/// "Pendiente" and "Asignado" together instead of one status at a time.
class _StatusFilterMenu extends ConsumerWidget {
  const _StatusFilterMenu({required this.selected, required this.onlyUnassigned});

  final Set<OrderStatus> selected;

  /// Mirrors [orderShowOnlyUnassignedProvider] — an extra AND-filter on top
  /// of [selected], not one of the [OrderStatus] values.
  final bool onlyUnassigned;

  String get _buttonLabel {
    final statusPart = selected.length == OrderStatus.values.length
        ? 'Todos'
        : selected.isEmpty
        ? 'Ninguno'
        : selected.length == 1
        ? orderStatusLabel(selected.first)
        : '${selected.length} seleccionados';
    return onlyUnassigned ? '$statusPart · No asignados' : statusPart;
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
        const Divider(height: 1),
        for (final status in OrderStatus.values)
          CheckboxMenuButton(
            value: selected.contains(status),
            onChanged: (checked) {
              final next = {...selected};
              if (checked ?? false) {
                next.add(status);
              } else {
                next.remove(status);
              }
              setFilter(next);
            },
            closeOnActivate: false,
            child: Text(orderStatusLabel(status)),
          ),
        const Divider(height: 1),
        CheckboxMenuButton(
          value: onlyUnassigned,
          onChanged: (checked) =>
              ref.read(orderShowOnlyUnassignedProvider.notifier).state = checked ?? false,
          closeOnActivate: false,
          child: const Text('No asignados'),
        ),
      ],
    );
  }
}
