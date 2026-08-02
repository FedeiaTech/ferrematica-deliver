/// Pure-Dart domain types for the `auth` slice. No Supabase imports here —
/// the data layer maps to/from these types.
library;

/// Domain role, resolved from `profiles.rol` after sign-in — never chosen
/// on the login form (design decision #2).
enum UserRole { dueno, cadete }

/// Maps the Spanish-language `profiles.rol` column value to [UserRole].
/// Deliberately has no silent fallback for unrecognized values — an
/// unrecognized role is a data integrity problem, not a role to guess at,
/// so it throws instead (see `SupabaseAuthRepository._resolveSession`).
extension UserRoleParsing on UserRole {
  static UserRole fromRow(String value) => switch (value) {
    'cadete' => UserRole.cadete,
    'dueno' => UserRole.dueno,
    _ => throw ArgumentError.value(value, 'value', 'Unknown profiles.rol value'),
  };
}

/// The authenticated user's id (matches `auth.users.id` / `profiles.id`)
/// and resolved [rol]. This is the single source of truth the router guard
/// and order-creation flow read from (design decision #1).
final class AppSession {
  const AppSession({required this.userId, required this.rol});

  final String userId;
  final UserRole rol;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSession && other.userId == userId && other.rol == rol;
  }

  @override
  int get hashCode => Object.hash(userId, rol);

  @override
  String toString() => 'AppSession(userId: $userId, rol: $rol)';
}
