import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// Exposes the app's [AppConfig]. Override-only: the real value is supplied
/// by `AppBootstrap` in `main.dart`, or by a fake config in tests. Reading
/// this provider without an override throws.
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden in bootstrap or tests'),
);
