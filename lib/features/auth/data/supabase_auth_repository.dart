import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_session.dart';
import '../domain/auth_repository.dart';

/// [AuthRepository] backed by `supabase_flutter`'s [GoTrueClient] for the
/// auth surface (sign in/out, auth-state stream) and a `profiles` read for
/// role resolution.
///
/// The `profiles` lookup is routed through an injectable [roleFetcher]
/// rather than calling the Postgrest fluent builder inline. This mirrors
/// the codebase's existing convention of not exercising vendor Postgrest
/// chains directly in unit tests (see `supabase_orders_remote.dart`, which
/// has no direct unit test for the same reason) — `mocktail` cannot cleanly
/// stub `SupabaseQueryBuilder`'s chained builder methods, so tests inject a
/// fake [roleFetcher] instead while still exercising the real
/// [GoTrueClient] surface via a mocked client. The default [roleFetcher]
/// performs the real `profiles` read and is what production wiring uses.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, {Future<String> Function(String userId)? roleFetcher}) {
    _roleFetcher = roleFetcher ?? _fetchRoleFromProfiles;
  }

  final SupabaseClient _client;
  late final Future<String> Function(String userId) _roleFetcher;

  @override
  Stream<AppSession?> watchSession() {
    return _client.auth.onAuthStateChange.asyncMap((authState) async {
      final user = authState.session?.user;
      if (user == null) return null;
      return _resolveSession(user.id);
    });
  }

  @override
  Future<AppSession> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(email: email, password: password);
    final user = response.user;
    if (user == null) {
      throw const AuthSessionException('signIn did not return a user');
    }
    return _resolveSession(user.id);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  Future<AppSession> _resolveSession(String userId) async {
    final rolValue = await _roleFetcher(userId);
    return AppSession(userId: userId, rol: UserRoleParsing.fromRow(rolValue));
  }

  Future<String> _fetchRoleFromProfiles(String userId) async {
    final row = await _client.from('profiles').select('rol').eq('id', userId).single();
    final rolValue = row['rol'] as String?;
    if (rolValue == null) {
      throw AuthSessionException('No profiles row found for user $userId');
    }
    return rolValue;
  }
}
