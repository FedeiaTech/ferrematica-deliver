import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/orders/presentation/providers.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/orders/presentation/screens/order_form_screen.dart';
import '../../features/orders/presentation/screens/orders_list_screen.dart';

/// App-wide router. `/orders` and its children are the `pedidos` feature's
/// entry point — the placeholder scaffold route has been replaced now that
/// a real feature exists. Future feature changes nest their own
/// `GoRoute`/`ShellRoute` under this tree.
final Provider<GoRouter> goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    // TODO(auth): replace with a real auth/role guard (SDD §4) once login
    // exists. For now `/` only exists as a redirect landing spot to `/orders`.
    redirect: (context, state) =>
        state.matchedLocation == '/' ? '/orders' : null,
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/orders',
        name: 'orders',
        builder: (context, state) => const OrdersListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'order-new',
            builder: (context, state) => const OrderFormScreen(),
          ),
          GoRoute(
            path: ':id',
            name: 'order-detail',
            builder: (context, state) =>
                OrderDetailScreen(orderId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: ':id/edit',
            name: 'order-edit',
            builder: (context, state) =>
                _OrderEditRoute(orderId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});

/// Resolves the order to edit by id before handing off to
/// [OrderFormScreen], since the route only carries the id in the URL.
class _OrderEditRoute extends ConsumerWidget {
  const _OrderEditRoute({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderByIdProvider(orderId));
    return orderAsync.when(
      data: (order) {
        if (order == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Editar pedido')),
            body: const Center(child: Text('Pedido no encontrado.')),
          );
        }
        return OrderFormScreen(existingOrder: order);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Editar pedido')),
        body: Center(child: Text('Error al cargar el pedido: $error')),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
