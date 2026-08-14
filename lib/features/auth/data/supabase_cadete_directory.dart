import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/cadete_directory.dart';

/// [CadeteDirectory] backed by `profiles` reads/writes filtered to `rol =
/// 'cadete'`, and a `create-cadete` Edge Function call for account
/// creation. Relies on the `profiles_select_cadetes` RLS policy (migration
/// 0003) for reads and `profiles_update_cadetes_by_dueno` (migration 0021)
/// for [updateCadete]/[setCadeteActive] — an authenticated non-dueño (or
/// inactive dueño) session simply gets an empty result / a silently
/// no-op'd write, not an error, since RLS filters rows rather than
/// rejecting the query.
///
/// Like `SupabaseAuthRepository`'s `roleFetcher`, this class takes
/// injectable fetchers/writers so tests never exercise the real Postgrest
/// fluent builder chain or `FunctionsClient` directly (`mocktail` cannot
/// cleanly stub either) — see `SupabaseAuthRepository`'s doc comment for
/// the full rationale. The defaults are what production wiring uses.
class SupabaseCadeteDirectory implements CadeteDirectory {
  SupabaseCadeteDirectory(
    this._client, {
    Future<List<Map<String, dynamic>>> Function()? cadeteFetcher,
    Future<List<Map<String, dynamic>>> Function()? allCadeteFetcher,
    Future<Map<String, dynamic>> Function({
      required String email,
      required String password,
      required String nombre,
      int? nro,
    })?
    cadeteCreator,
    Future<void> Function({required String id, required String nombre, int? nro})?
    cadeteUpdater,
    Future<void> Function({required String id, required bool active})? cadeteActiveSetter,
  }) {
    _cadeteFetcher = cadeteFetcher ?? _fetchCadeteRows;
    _allCadeteFetcher = allCadeteFetcher ?? _fetchAllCadeteRows;
    _cadeteCreator = cadeteCreator ?? _invokeCreateCadete;
    _cadeteUpdater = cadeteUpdater ?? _updateCadeteRow;
    _cadeteActiveSetter = cadeteActiveSetter ?? _updateCadeteActive;
  }

  final SupabaseClient _client;
  late final Future<List<Map<String, dynamic>>> Function() _cadeteFetcher;
  late final Future<List<Map<String, dynamic>>> Function() _allCadeteFetcher;
  late final Future<Map<String, dynamic>> Function({
    required String email,
    required String password,
    required String nombre,
    int? nro,
  })
  _cadeteCreator;
  late final Future<void> Function({required String id, required String nombre, int? nro})
  _cadeteUpdater;
  late final Future<void> Function({required String id, required bool active})
  _cadeteActiveSetter;

  @override
  Future<List<CadeteProfile>> listCadetes() async {
    final rows = await _cadeteFetcher();
    return rows.map(_toCadeteProfile).toList(growable: false);
  }

  @override
  Future<List<CadeteProfile>> listAllCadetes() async {
    final rows = await _allCadeteFetcher();
    return rows.map(_toCadeteProfile).toList(growable: false);
  }

  CadeteProfile _toCadeteProfile(Map<String, dynamic> row) => CadeteProfile(
    id: row['id'] as String,
    fullName: row['full_name'] as String?,
    nro: row['nro'] as int?,
    active: row['active'] as bool? ?? true,
  );

  Future<List<Map<String, dynamic>>> _fetchCadeteRows() async {
    final rows = await _client
        .from('profiles')
        .select('id, full_name, nro, active')
        .eq('rol', 'cadete')
        .eq('active', true)
        .order('full_name');
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Ordered by `nro` first (nulls last — see `nullsFirst: false`) so a
  /// numbered roster reads as a tidy "#01, #02, #03…" list in the
  /// management screen, with not-yet-numbered cadetes trailing
  /// alphabetically rather than interleaved at the top as Postgres' default
  /// nulls-first-on-ascending would otherwise place them.
  Future<List<Map<String, dynamic>>> _fetchAllCadeteRows() async {
    final rows = await _client
        .from('profiles')
        .select('id, full_name, nro, active')
        .eq('rol', 'cadete')
        .order('nro', nullsFirst: false)
        .order('full_name');
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<String> createCadete({
    required String email,
    required String password,
    required String nombre,
    int? nro,
  }) async {
    final result = await _cadeteCreator(email: email, password: password, nombre: nombre, nro: nro);
    final id = result['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const CadeteDirectoryException('El servidor no devolvió el id del nuevo cadete.');
    }
    return id;
  }

  @override
  Future<void> updateCadete({required String id, required String nombre, int? nro}) async {
    await _cadeteUpdater(id: id, nombre: nombre, nro: nro);
  }

  @override
  Future<void> setCadeteActive({required String id, required bool active}) async {
    await _cadeteActiveSetter(id: id, active: active);
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
    int? nro,
  }) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'create-cadete',
        body: {'email': email, 'password': password, 'nombre': nombre, if (nro != null) 'nro': nro},
      );
    } on FunctionException catch (error) {
      throw CadeteDirectoryException(_messageFromFunctionException(error));
    }
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    throw const CadeteDirectoryException('Respuesta inesperada del servidor al crear el cadete.');
  }

  /// Writes directly to `profiles`, relying on
  /// `profiles_update_cadetes_by_dueno` (migration 0021). Postgrest doesn't
  /// raise an error for an RLS-filtered update that matches zero rows (it's
  /// indistinguishable at the wire level from "no such id"), so this checks
  /// the returned row count itself and surfaces a clear message rather than
  /// silently pretending the edit succeeded.
  Future<void> _updateCadeteRow({required String id, required String nombre, int? nro}) async {
    try {
      final updated = await _client
          .from('profiles')
          .update({'full_name': nombre, 'nro': nro})
          .eq('id', id)
          .eq('rol', 'cadete')
          .select('id');
      if ((updated as List).isEmpty) {
        throw const CadeteDirectoryException(
          'No se pudo actualizar el cadete (¿ya no existe o no tenés permiso?).',
        );
      }
    } on PostgrestException catch (error) {
      throw CadeteDirectoryException(_messageFromPostgrestException(error));
    }
  }

  Future<void> _updateCadeteActive({required String id, required bool active}) async {
    try {
      final updated = await _client
          .from('profiles')
          .update({'active': active})
          .eq('id', id)
          .eq('rol', 'cadete')
          .select('id');
      if ((updated as List).isEmpty) {
        throw const CadeteDirectoryException(
          'No se pudo actualizar el estado del cadete (¿ya no existe o no tenés permiso?).',
        );
      }
    } on PostgrestException catch (error) {
      throw CadeteDirectoryException(_messageFromPostgrestException(error));
    }
  }

  /// Postgres unique-violation is `23505` — `profiles_cadete_nro_active_unique`
  /// (migration 0021) is the only unique index this table's writes can hit,
  /// so any `23505` here means a duplicate active `nro`.
  String _messageFromPostgrestException(PostgrestException error) {
    if (error.code == '23505') return 'Ya hay un cadete activo con ese número.';
    return error.message;
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
      409 => 'Ya existe una cuenta con ese email o ese número de cadete.',
      400 => 'Datos inválidos para crear el cadete.',
      _ => 'No se pudo crear el cadete (error ${error.status}).',
    };
  }
}
