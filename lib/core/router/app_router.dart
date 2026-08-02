import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/providers.dart';
import '../../features/auth/domain/app_session.dart';
import '../../features/auth/presentation/providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/orders/presentation/providers.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/orders/presentation/screens/order_form_screen.dart';
import '../../features/orders/presentation/screens/orders_list_screen.dart';

/// App-wide router. `/orders` and its children are the `pedidos` feature's
/// entry point; `/delivery` is a placeholder for the cadete-facing feature
/// landing in a later PR of this change. Future feature changes nest their
/// own `GoRoute`/`ShellRoute` under this tree.
///
/// Auth guard (design decision #3): a single `redirect` choke-point reads
/// [sessionProvider] — unauthenticated users go to `/login`; authenticated
/// dueños go to `/orders`; authenticated cadetes go to `/delivery`.
/// [_SessionRefreshNotifier] re-runs `redirect` whenever the session
/// changes (sign-in, sign-out, or the initial session restore on app
/// start), since `GoRouter`'s `redirect` alone only re-runs on navigation.
final Provider<GoRouter> goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _SessionRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final sessionAsync = ref.read(sessionProvider);
      final matchedLocation = state.matchedLocation;
      final atSplash = matchedLocation == '/';
      final atLogin = matchedLocation == '/login';

      return sessionAsync.when(
        // Session is still resolving (initial restore or a role lookup in
        // flight) — stay put. The splash route covers the `/` case; other
        // routes render normally and get re-evaluated once the session
        // settles, since [_SessionRefreshNotifier] fires again then.
        loading: () => null,
        error: (_, _) => atLogin ? null : '/login',
        data: (session) {
          if (session == null) {
            return atLogin ? null : '/login';
          }
          final home = session.rol == UserRole.dueno ? '/orders' : '/delivery';
          return (atSplash || atLogin) ? home : null;
        },
      );
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/delivery',
        name: 'delivery',
        // Placeholder cadete home — cadete-scoped views are PR4's scope
        // (`sdd/navegacion-cadete/tasks` obs #341, Phase 4).
        builder: (context, state) => const _CadeteHomePlaceholder(),
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

/// Bridges Riverpod's [sessionProvider] into a [Listenable] so `GoRouter`
/// re-runs `redirect` on every session change, not just on navigation.
class _SessionRefreshNotifier extends ChangeNotifier {
  _SessionRefreshNotifier(Ref ref) {
    _subscription = ref.listen<AsyncValue<AppSession?>>(
      sessionProvider,
      (previous, next) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<AppSession?>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

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

/// Placeholder cadete home screen. Real cadete-scoped order views land in
/// PR4 of this change (`sdd/navegacion-cadete/tasks` obs #341) — this
/// exists only so the router has somewhere to send an authenticated cadete
/// in the meantime, and so the sign-out action is reachable for manual
/// testing of this PR.
class _CadeteHomePlaceholder extends ConsumerWidget {
  const _CadeteHomePlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadete'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: const Center(child: Text('Próximamente: tus pedidos asignados.')),
    );
  }
}
