import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// App-wide router. Only a splash and a placeholder route exist at scaffold
/// time — feature changes add real routes here or nest their own
/// `GoRoute`/`ShellRoute` under this tree.
final Provider<GoRouter> goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    // Reserved for a future auth/role guard (SDD §4). Empty for now: no
    // redirect logic exists until a real auth provider is wired.
    redirect: (context, state) => null,
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/placeholder',
        name: 'placeholder',
        builder: (context, state) => const _PlaceholderScreen(),
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ferrematica Express')),
      body: const Center(child: Text('Scaffold ready — no feature yet.')),
    );
  }
}
