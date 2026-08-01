import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../database/isar_module.dart';

/// Bundle of everything `main.dart` needs to build the `ProviderScope`
/// overrides: resolved config, an open Isar instance, and the Supabase
/// client. Nothing here is a global singleton — every dependency is
/// swappable in tests.
final class BootstrapResult {
  const BootstrapResult({
    required this.config,
    required this.isar,
    required this.supabaseClient,
  });

  final AppConfig config;
  final Isar isar;
  final SupabaseClient supabaseClient;
}

/// Thrown when bootstrap cannot produce a usable [BootstrapResult], e.g.
/// missing required config or a failure opening the local database.
final class AppBootstrapException implements Exception {
  const AppBootstrapException(this.message);

  final String message;

  @override
  String toString() => 'AppBootstrapException: $message';
}

/// Single entry point that wires app-wide dependencies before `main.dart`
/// builds the widget tree. Fails loudly instead of letting the app run with
/// partial/invalid configuration.
final class AppBootstrap {
  const AppBootstrap._();

  /// Builds [AppConfig], opens the local Isar instance, and initializes the
  /// Supabase client. Throws [AppBootstrapException] if config is invalid or
  /// if Isar fails to open.
  static Future<BootstrapResult> init() async {
    final AppConfig config = AppConfig.fromEnvironment();
    if (!config.isValid) {
      throw const AppBootstrapException(
        'Missing required config: SUPABASE_URL and/or SUPABASE_ANON_KEY were '
        'not provided via --dart-define-from-file.',
      );
    }

    final Isar isar;
    try {
      final directory = await getApplicationDocumentsDirectory();
      isar = await openIsar(directory: directory.path);
    } catch (error, stackTrace) {
      throw AppBootstrapException('Failed to open Isar: $error\n$stackTrace');
    }

    final supabase = await Supabase.initialize(
      url: config.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: config.supabaseAnonKey,
    );

    return BootstrapResult(
      config: config,
      isar: isar,
      supabaseClient: supabase.client,
    );
  }
}
