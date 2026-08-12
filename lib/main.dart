import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/bootstrap/app_bootstrap.dart';
import 'core/config/providers.dart';
import 'core/database/providers.dart';
import 'core/router/app_router.dart';
import 'core/supabase/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/orders/data/providers.dart' show orderSyncServiceProvider;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await AppBootstrap.init();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(bootstrap.config),
        isarProvider.overrideWithValue(bootstrap.isar),
        supabaseProvider.overrideWithValue(bootstrap.supabaseClient),
      ],
      child: const FerrematicaApp(),
    ),
  );
}

class FerrematicaApp extends ConsumerWidget {
  const FerrematicaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    // `Provider`s are lazy in Riverpod — without reading this at least
    // once, OrderSyncService.start() (connectivity/app-resume/onWrite
    // triggers) never runs and orders silently never sync in the
    // background. Value never changes once built, so this never causes an
    // extra rebuild.
    ref.watch(orderSyncServiceProvider);

    return MaterialApp.router(
      title: 'Ferremática Express',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
