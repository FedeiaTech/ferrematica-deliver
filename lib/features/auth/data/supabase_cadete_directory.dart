import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/cadete_directory.dart';

/// [CadeteDirectory] backed by a `profiles` read filtered to `rol =
/// 'cadete'` and `active = true`. Relies on the `profiles_select_cadetes`
/// RLS policy (migration 0003) — an authenticated non-dueño (or inactive
/// dueño) session simply gets an empty result, not an error, since RLS
/// filters rows rather than rejecting the query.
///
/// Like `SupabaseAuthRepository`'s `roleFetcher`, this class takes an
/// injectable [cadeteFetcher] so tests never exercise the real Postgrest
/// fluent builder chain (`mocktail` cannot cleanly stub it) — see that
/// class's doc comment for the full rationale. The default [cadeteFetcher]
/// is what production wiring uses.
class SupabaseCadeteDirectory implements CadeteDirectory {
  SupabaseCadeteDirectory(
    this._client, {
    Future<List<Map<String, dynamic>>> Function()? cadeteFetcher,
  }) {
    _cadeteFetcher = cadeteFetcher ?? _fetchCadeteRows;
  }

  final SupabaseClient _client;
  late final Future<List<Map<String, dynamic>>> Function() _cadeteFetcher;

  @override
  Future<List<CadeteProfile>> listCadetes() async {
    final rows = await _cadeteFetcher();
    return rows
        .map(
          (row) => CadeteProfile(
            id: row['id'] as String,
            fullName: row['full_name'] as String?,
          ),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _fetchCadeteRows() async {
    final rows = await _client
        .from('profiles')
        .select('id, full_name')
        .eq('rol', 'cadete')
        .eq('active', true)
        .order('full_name');
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
