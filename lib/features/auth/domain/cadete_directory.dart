/// A minimal read-only projection of a `rol = 'cadete'` `profiles` row,
/// just enough to render a picker (design: "assign_cadete_sheet.dart").
/// Deliberately not `AppSession` — a cadete's own session additionally
/// carries a `rol`, which is meaningless in a list the *dueño* is
/// browsing.
final class CadeteProfile {
  const CadeteProfile({required this.id, this.fullName});

  final String id;
  final String? fullName;

  /// Falls back to the id when `full_name` is null. `full_name` is always
  /// supplied through `createCadete`'s `nombre` field for accounts created
  /// in-app, but stays nullable to cover any account provisioned another
  /// way (e.g. directly in the Supabase Dashboard, still possible for an
  /// admin with project access).
  String get displayName => fullName?.trim().isNotEmpty == true ? fullName! : id;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CadeteProfile && other.id == id && other.fullName == fullName;
  }

  @override
  int get hashCode => Object.hash(id, fullName);
}

/// Port over listing and creating cadete accounts, so dueño-facing UI never
/// touches Supabase directly. Mirrors the `AuthRepository`/`OrdersRepository`
/// port pattern (design decision #1).
///
/// [createCadete] lives on this same port rather than a separate class:
/// both methods are "how a dueño administers the cadete roster", and the
/// port is still small enough (two methods) that splitting it would just
/// add an extra file/provider/test double for no real isolation benefit.
abstract interface class CadeteDirectory {
  /// Returns every active `rol = 'cadete'` profile, ordered for display.
  /// Relies on the `profiles_select_cadetes` RLS policy (migration 0003)
  /// to scope the read to an authenticated, active dueño.
  Future<List<CadeteProfile>> listCadetes();

  /// Creates a new cadete account (auth user + `profiles` row) via the
  /// `create-cadete` Edge Function, replacing the previous manual Supabase
  /// Dashboard provisioning process. [password] is handed to the cadete
  /// directly by the dueño — there is no invite-email flow.
  ///
  /// Returns the new user's id on success. Throws [CadeteCreationException]
  /// on any failure (validation, duplicate email, unauthorized caller, or
  /// an unexpected server error) with a user-facing message.
  Future<String> createCadete({
    required String email,
    required String password,
    required String nombre,
  });
}

/// Thrown when [CadeteDirectory.createCadete] fails — a duplicate email, a
/// validation error, an unauthorized caller (should not normally happen
/// since the UI entry point is already dueño-gated, but the Edge Function
/// re-checks server-side regardless), or an unexpected server error.
/// [message] is safe to show directly to the dueño.
final class CadeteCreationException implements Exception {
  const CadeteCreationException(this.message);

  final String message;

  @override
  String toString() => 'CadeteCreationException: $message';
}
