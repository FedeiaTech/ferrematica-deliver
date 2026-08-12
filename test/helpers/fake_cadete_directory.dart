import 'package:ferrematica_express/features/auth/domain/cadete_directory.dart';

/// In-memory [CadeteDirectory] double for widget tests, per the same
/// pattern as `FakeOrdersRepository`/`FakeAuthRepository` — overrides
/// `cadeteDirectoryProvider` so tests never touch `supabase_flutter`.
class FakeCadeteDirectory implements CadeteDirectory {
  FakeCadeteDirectory({
    List<CadeteProfile> cadetes = const <CadeteProfile>[],
    this.createCadeteException,
  }) : _cadetes = cadetes;

  final List<CadeteProfile> _cadetes;

  /// When set, [createCadete] throws this instead of succeeding — lets a
  /// test exercise the error path without a real Edge Function.
  final CadeteCreationException? createCadeteException;

  String? lastCreatedEmail;
  String? lastCreatedPassword;
  String? lastCreatedNombre;

  @override
  Future<List<CadeteProfile>> listCadetes() async => _cadetes;

  @override
  Future<String> createCadete({
    required String email,
    required String password,
    required String nombre,
  }) async {
    lastCreatedEmail = email;
    lastCreatedPassword = password;
    lastCreatedNombre = nombre;
    final exception = createCadeteException;
    if (exception != null) throw exception;
    return 'fake-cadete-id';
  }
}
