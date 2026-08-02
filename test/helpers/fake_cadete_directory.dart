import 'package:ferrematica_express/features/auth/domain/cadete_directory.dart';

/// In-memory [CadeteDirectory] double for widget tests, per the same
/// pattern as `FakeOrdersRepository`/`FakeAuthRepository` — overrides
/// `cadeteDirectoryProvider` so tests never touch `supabase_flutter`.
class FakeCadeteDirectory implements CadeteDirectory {
  FakeCadeteDirectory({List<CadeteProfile> cadetes = const <CadeteProfile>[]})
    : _cadetes = cadetes;

  final List<CadeteProfile> _cadetes;

  @override
  Future<List<CadeteProfile>> listCadetes() async => _cadetes;
}
