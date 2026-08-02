/// A minimal read-only projection of a `rol = 'cadete'` `profiles` row,
/// just enough to render a picker (design: "assign_cadete_sheet.dart").
/// Deliberately not `AppSession` — a cadete's own session additionally
/// carries a `rol`, which is meaningless in a list the *dueño* is
/// browsing.
final class CadeteProfile {
  const CadeteProfile({required this.id, this.fullName});

  final String id;
  final String? fullName;

  /// Falls back to the id when `full_name` is null — accounts are
  /// provisioned out-of-band via the Supabase Dashboard (design decision
  /// #5) and a name is not enforced at that step.
  String get displayName => fullName?.trim().isNotEmpty == true ? fullName! : id;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CadeteProfile && other.id == id && other.fullName == fullName;
  }

  @override
  int get hashCode => Object.hash(id, fullName);
}

/// Port over listing available cadete accounts, so the dueño-facing
/// "assign cadete" sheet never touches Supabase directly. Mirrors the
/// `AuthRepository`/`OrdersRepository` port pattern (design decision #1).
abstract interface class CadeteDirectory {
  /// Returns every active `rol = 'cadete'` profile, ordered for display.
  /// Relies on the `profiles_select_cadetes` RLS policy (migration 0003)
  /// to scope the read to an authenticated, active dueño.
  Future<List<CadeteProfile>> listCadetes();
}
