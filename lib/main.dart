import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/bootstrap/app_bootstrap.dart';
import 'core/config/providers.dart';
import 'core/database/providers.dart';
import 'core/router/app_router.dart';
import 'core/supabase/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/background_color_provider.dart';
import 'features/orders/data/providers.dart' show orderSyncServiceProvider;

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keeps the native splash on screen through `AppBootstrap.init()`'s async
  // work (Isar open, Supabase init) instead of letting the engine dismiss it
  // at the first drawn frame — which would otherwise flash an empty/loading
  // frame before bootstrap finishes. Paired with the explicit `.remove()`
  // below, once the widget tree is actually ready to paint. LoginScreen's
  // own fade-in (see that file) is what makes the handoff read as a
  // deliberate crossfade rather than an abrupt cut.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
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
  FlutterNativeSplash.remove();
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
    final background = ref.watch(backgroundColorProvider);

    return MaterialApp.router(
      title: 'Ferremática Express',
      theme: AppTheme.light(background.color),
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
