import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

/// Exposes the app's [Isar] instance. Override-only: the real value is
/// supplied by `AppBootstrap` in `main.dart`, or by a fake/temp-dir instance
/// in tests. Reading this provider without an override throws.
final Provider<Isar> isarProvider = Provider<Isar>(
  (ref) => throw UnimplementedError('isarProvider must be overridden in bootstrap or tests'),
);
