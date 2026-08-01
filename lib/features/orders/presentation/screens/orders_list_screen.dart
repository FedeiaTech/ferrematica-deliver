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

    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos')),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                _FilterChip(
                  label: 'Todos',
                  selected: filter == null,
                  onSelected: (ref) => null,
                ),
                for (final status in OrderStatus.values)
                  _FilterChip(
                    label: orderStatusLabel(status),
                    selected: filter == status,
                    onSelected: (ref) => status,
                  ),
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

class _FilterChip extends ConsumerWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final OrderStatus? Function(WidgetRef ref) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) =>
          ref.read(orderFilterProvider.notifier).state = onSelected(ref),
    );
  }
}
