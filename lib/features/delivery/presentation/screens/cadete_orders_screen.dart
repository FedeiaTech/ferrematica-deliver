import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../orders/presentation/widgets/order_card.dart';
import '../providers.dart';

/// Cadete-facing home screen: shows only the orders assigned to the signed
/// in cadete (spec's `cadete-orders` domain), reusing [OrderCard] so the
/// visual language matches the dueño's list. Tapping a card opens the
/// read-only cadete detail route (`/delivery/:id`), which reuses
/// [OrderDetailScreen] with `readOnlyForCadete: true` (design decision #8)
/// rather than forking a separate detail screen.
///
/// No `AppBar` here — the section title lives in `CadeteHomeScreen`'s
/// `SectionBanner`, and signing out now lives in that banner's role-label
/// menu instead of a per-tab action.
class CadeteOrdersScreen extends ConsumerWidget {
  const CadeteOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(cadeteOrdersProvider);

    return Scaffold(
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Text('Todavía no tenés pedidos asignados.'),
            );
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return OrderCard(
                order: order,
                onTap: () => context.push('/delivery/${order.id}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Error al cargar tus pedidos: $error')),
      ),
    );
  }
}
