import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/bootstrap/app_bootstrap.dart';
import 'core/config/providers.dart';
import 'core/database/providers.dart';
import 'core/router/app_router.dart';
import 'core/supabase/providers.dart';
import 'core/theme/app_theme.dart';

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

    return MaterialApp.router(
      title: 'Ferrematica Express',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
