import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/providers.dart';
import '../domain/auth_repository.dart';
import 'supabase_auth_repository.dart';

/// The app's [AuthRepository], backed by the real `supabase_flutter`
/// client. Overridden in tests with a fake (see `test/helpers/pump_app.dart`
/// and `test/helpers/fake_auth_repository.dart`).
final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseProvider)),
);
