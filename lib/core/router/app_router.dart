import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/app_session.dart';
import '../../features/auth/presentation/providers.dart';
import '../../features/auth/presentation/screens/create_cadete_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/manage_cadetes_screen.dart';
import '../../features/delivery/presentation/screens/cadete_home_screen.dart';
import '../../features/delivery/presentation/screens/navigation_map_screen.dart';
import '../../features/orders/domain/order.dart';
import '../../features/orders/presentation/providers.dart';
import '../../features/orders/presentation/screens/dueno_home_screen.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/orders/presentation/screens/order_form_screen.dart';
import '../../features/orders/presentation/screens/orders_map_screen.dart';

/// App-wide router. `/orders` and its children are the dueño-facing
/// `pedidos` feature's entry point; `/delivery` and its children are the
/// cadete-facing views (PR4 of this change — `sdd/navegacion-cadete/tasks`
/// obs #341, Phase 4). Future feature changes nest their own
/// `GoRoute`/`ShellRoute` under this tree.
///
/// Auth guard (design decision #3): a single `redirect` choke-point reads
/// [sessionProvider] — unauthenticated users go to `/login`; authenticated
/// dueños go to `/orders`; authenticated cadetes go to `/delivery`.
/// [_SessionRefreshNotifier] re-runs `redirect` whenever the session
/// changes (sign-in, sign-out, or the initial session restore on app
/// start), since `GoRouter`'s `redirect` alone only re-runs on navigation.
///
/// **Defense-in-depth role gating (PR4)**: beyond `OrderDetailScreen`'s own
/// `readOnlyForCadete`-gated actions, the redirect also blocks a cadete
/// from reaching `/orders/*` at all (and a dueño from `/delivery/*`) even
/// via a direct/deep-linked URL — the RLS policies would reject a cadete's
/// writes on those screens regardless, but this keeps a cadete from ever
/// rendering the dueño-only UI in the first place.
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
          if (atSplash || atLogin) return home;
          // Defense-in-depth: a cadete can never reach `/orders/*` (dueño
          // actions), and a dueño never lands on `/delivery/*` (cadete's
          // scoped view), even via a direct/deep-linked URL.
          final atOrders = matchedLocation.startsWith('/orders');
          final atDelivery = matchedLocation.startsWith('/delivery');
          if (session.rol == UserRole.cadete && atOrders) return home;
          if (session.rol == UserRole.dueno && atDelivery) return home;
          return null;
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
        builder: (context, state) => const CadeteHomeScreen(),
        routes: [
          GoRoute(
            path: ':id',
            name: 'delivery-order-detail',
            builder: (context, state) => OrderDetailScreen(
              orderId: state.pathParameters['id']!,
              readOnlyForCadete: true,
            ),
            routes: [
              GoRoute(
                path: 'navigate',
                name: 'delivery-order-navigate',
                builder: (context, state) =>
                    NavigationMapScreen(orderId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/orders',
        name: 'orders',
        builder: (context, state) => const DuenoHomeScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'order-new',
            // `extra` carries the failed order for "Reintentar entrega"
            // (order_detail_screen.dart) — `null` for the normal "+" FAB
            // create flow.
            builder: (context, state) =>
                OrderFormScreen(prefillFrom: state.extra as Order?),
          ),
          GoRoute(
            path: 'map',
            name: 'orders-map',
            builder: (context, state) => const OrdersMapScreen(),
          ),
          GoRoute(
            path: 'cadetes/new',
            name: 'cadete-new',
            // Dueño-only, same as every other route under `/orders` — the
            // top-level `redirect` above already blocks a cadete session
            // from reaching this path.
            builder: (context, state) => const CreateCadeteScreen(),
          ),
          GoRoute(
            path: 'cadetes',
            name: 'cadetes-manage',
            // Dueño-only, same guard as `cadetes/new` above.
            builder: (context, state) => const ManageCadetesScreen(),
          ),
          GoRoute(
            path: ':id',
            name: 'order-detail',
            builder: (context, state) =>
                OrderDetailScreen(orderId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'navigate',
                name: 'order-navigate',
                // Dueño-facing route to the same map screen the cadete
                // uses, reachable only when the dueño self-assigned the
                // order to themselves ("Base" in assign_cadete_sheet.dart)
                // — OrderDetailScreen only renders the button that leads
                // here in that case.
                builder: (context, state) =>
                    NavigationMapScreen(orderId: state.pathParameters['id']!),
              ),
            ],
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
