import 'package:ferrematica_express/features/auth/domain/cadete_directory.dart';

/// In-memory [CadeteDirectory] double for widget tests, per the same
/// pattern as `FakeOrdersRepository`/`FakeAuthRepository` — overrides
/// `cadeteDirectoryProvider` so tests never touch `supabase_flutter`.
class FakeCadeteDirectory implements CadeteDirectory {
  FakeCadeteDirectory({
    List<CadeteProfile> cadetes = const <CadeteProfile>[],
    this.createCadeteException,
    this.updateCadeteException,
    this.setCadeteActiveException,
  }) : _cadetes = List.of(cadetes);

  final List<CadeteProfile> _cadetes;

  /// When set, [createCadete] throws this instead of succeeding — lets a
  /// test exercise the error path without a real Edge Function.
  final CadeteDirectoryException? createCadeteException;
  final CadeteDirectoryException? updateCadeteException;
  final CadeteDirectoryException? setCadeteActiveException;

  String? lastCreatedEmail;
  String? lastCreatedPassword;
  String? lastCreatedNombre;
  int? lastCreatedNro;

  String? lastUpdatedId;
  String? lastUpdatedNombre;
  int? lastUpdatedNro;

  String? lastActiveToggledId;
  bool? lastActiveToggledValue;

  /// Only active cadetes — same scoping as the real
  /// `SupabaseCadeteDirectory.listCadetes` (`profiles_select_cadetes` +
  /// `active = true`).
  @override
  Future<List<CadeteProfile>> listCadetes() async =>
      _cadetes.where((cadete) => cadete.active).toList(growable: false);

  @override
  Future<List<CadeteProfile>> listAllCadetes() async => List.of(_cadetes);

  @override
  Future<String> createCadete({
    required String email,
    required String password,
    required String nombre,
    int? nro,
  }) async {
    lastCreatedEmail = email;
    lastCreatedPassword = password;
    lastCreatedNombre = nombre;
    lastCreatedNro = nro;
    final exception = createCadeteException;
    if (exception != null) throw exception;
    final id = 'fake-cadete-id';
    _cadetes.add(CadeteProfile(id: id, fullName: nombre, nro: nro));
    return id;
  }

  @override
  Future<void> updateCadete({required String id, required String nombre, int? nro}) async {
    lastUpdatedId = id;
    lastUpdatedNombre = nombre;
    lastUpdatedNro = nro;
    final exception = updateCadeteException;
    if (exception != null) throw exception;
    final index = _cadetes.indexWhere((cadete) => cadete.id == id);
    if (index != -1) {
      final existing = _cadetes[index];
      _cadetes[index] = CadeteProfile(id: id, fullName: nombre, nro: nro, active: existing.active);
    }
  }

  @override
  Future<void> setCadeteActive({required String id, required bool active}) async {
    lastActiveToggledId = id;
    lastActiveToggledValue = active;
    final exception = setCadeteActiveException;
    if (exception != null) throw exception;
    final index = _cadetes.indexWhere((cadete) => cadete.id == id);
    if (index != -1) {
      final existing = _cadetes[index];
      _cadetes[index] = CadeteProfile(
        id: id,
        fullName: existing.fullName,
        nro: existing.nro,
        active: active,
      );
    }
  }
}
