import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/providers.dart';
import '../domain/auth_repository.dart';
import '../domain/cadete_directory.dart';
import 'supabase_auth_repository.dart';
import 'supabase_cadete_directory.dart';

/// The app's [AuthRepository], backed by the real `supabase_flutter`
/// client. Overridden in tests with a fake (see `test/helpers/pump_app.dart`
/// and `test/helpers/fake_auth_repository.dart`).
final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseProvider)),
);

/// The app's [CadeteDirectory], backed by a real `profiles` read. Overridden
/// in tests with a fake (see `assign_cadete_sheet_test.dart`).
final Provider<CadeteDirectory> cadeteDirectoryProvider = Provider<CadeteDirectory>(
  (ref) => SupabaseCadeteDirectory(ref.watch(supabaseProvider)),
);
