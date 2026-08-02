import 'app_session.dart';

/// Port over authentication. Mirrors the existing `OrdersRepository`/
/// `OrdersRemote` port pattern (design decision #1) so a fake is trivial in
/// tests — no widget test needs to touch `supabase_flutter` directly.
abstract interface class AuthRepository {
  /// Emits the current [AppSession] whenever auth state changes (sign-in,
  /// sign-out, token refresh, or session restore on app start), resolving
  /// `profiles.rol` for the signed-in user. Emits `null` when signed out.
  Stream<AppSession?> watchSession();

  /// Signs in with [email]/[password] and returns the resolved session.
  /// Throws if the credentials are rejected or no matching `profiles` row
  /// exists for the authenticated user.
  Future<AppSession> signIn({required String email, required String password});

  /// Signs out the current user, if any.
  Future<void> signOut();
}

/// Thrown when sign-in succeeds at the auth layer but returns no user, or
/// when no `profiles` row exists to resolve a role from. Accounts
/// provisioned via the README runbook always have a matching `profiles`
/// row, so this signals a data-integrity problem rather than an expected
/// user-facing error.
final class AuthSessionException implements Exception {
  const AuthSessionException(this.message);

  final String message;

  @override
  String toString() => 'AuthSessionException: $message';
}
