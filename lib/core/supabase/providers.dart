import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exposes the app's [SupabaseClient]. Override-only: the real value is
/// supplied by `AppBootstrap` in `main.dart`, or by a fake client in tests.
/// Reading this provider without an override throws.
final Provider<SupabaseClient> supabaseProvider = Provider<SupabaseClient>(
  (ref) => throw UnimplementedError('supabaseProvider must be overridden in bootstrap or tests'),
);
