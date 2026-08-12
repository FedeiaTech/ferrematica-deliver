import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/cadete_directory.dart';

/// [CadeteDirectory] backed by a `profiles` read filtered to `rol =
/// 'cadete'` and `active = true`, and a `create-cadete` Edge Function call
/// for account creation. Relies on the `profiles_select_cadetes` RLS policy
/// (migration 0003) — an authenticated non-dueño (or inactive dueño)
/// session simply gets an empty result, not an error, since RLS filters
/// rows rather than rejecting the query.
///
/// Like `SupabaseAuthRepository`'s `roleFetcher`, this class takes
/// injectable [cadeteFetcher]/[cadeteCreator] so tests never exercise the
/// real Postgrest fluent builder chain or `FunctionsClient` directly
/// (`mocktail` cannot cleanly stub either) — see `SupabaseAuthRepository`'s
/// doc comment for the full rationale. The defaults are what production
/// wiring uses.
class SupabaseCadeteDirectory implements CadeteDirectory {
  SupabaseCadeteDirectory(
    this._client, {
    Future<List<Map<String, dynamic>>> Function()? cadeteFetcher,
    Future<Map<String, dynamic>> Function({
      required String email,
      required String password,
      required String nombre,
    })?
    cadeteCreator,
  }) {
    _cadeteFetcher = cadeteFetcher ?? _fetchCadeteRows;
    _cadeteCreator = cadeteCreator ?? _invokeCreateCadete;
  }

  final SupabaseClient _client;
  late final Future<List<Map<String, dynamic>>> Function() _cadeteFetcher;
  late final Future<Map<String, dynamic>> Function({
    required String email,
    required String password,
    required String nombre,
  })
  _cadeteCreator;

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

  @override
  Future<String> createCadete({
    required String email,
    required String password,
    required String nombre,
  }) async {
    final result = await _cadeteCreator(
      email: email,
      password: password,
      nombre: nombre,
    );
    final id = result['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const CadeteCreationException(
        'El servidor no devolvió el id del nuevo cadete.',
      );
    }
    return id;
  }

  /// Calls the `create-cadete` Edge Function. `supabase.functions.invoke`
  /// auto-attaches the current session's JWT as the `Authorization` header,
  /// which is what lets the function verify the caller is an active dueño
  /// server-side (see `supabase/functions/create-cadete/index.ts`'s header
  /// comment for the full two-client security pattern).
  Future<Map<String, dynamic>> _invokeCreateCadete({
    required String email,
    required String password,
    required String nombre,
  }) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'create-cadete',
        body: {'email': email, 'password': password, 'nombre': nombre},
      );
    } on FunctionException catch (error) {
      throw CadeteCreationException(_messageFromFunctionException(error));
    }
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    throw const CadeteCreationException(
      'Respuesta inesperada del servidor al crear el cadete.',
    );
  }

  /// Prefers the Edge Function's own `{"error": "..."}` body (set for every
  /// deliberate rejection — validation, unauthorized, duplicate email) over
  /// a generic message keyed off the HTTP status, so the dueño sees the
  /// same specific wording the function already crafted.
  String _messageFromFunctionException(FunctionException error) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (details is String && details.trim().isNotEmpty) return details;
    return switch (error.status) {
      401 || 403 => 'No tenés permisos para crear cuentas de cadete.',
      409 => 'Ya existe una cuenta con ese email.',
      400 => 'Datos inválidos para crear el cadete.',
      _ => 'No se pudo crear el cadete (error ${error.status}).',
    };
  }
}
