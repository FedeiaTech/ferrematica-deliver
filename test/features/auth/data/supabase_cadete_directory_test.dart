import 'package:ferrematica_express/features/auth/data/supabase_cadete_directory.dart';
import 'package:ferrematica_express/features/auth/domain/cadete_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('listCadetes', () {
    test('maps rows from the injected cadeteFetcher into CadeteProfile', () async {
      final directory = SupabaseCadeteDirectory(
        MockSupabaseClient(),
        cadeteFetcher: () async => [
          {'id': 'cadete-1', 'full_name': 'Juan Pérez'},
          {'id': 'cadete-2', 'full_name': null},
        ],
      );

      final cadetes = await directory.listCadetes();

      expect(cadetes, [
        const CadeteProfile(id: 'cadete-1', fullName: 'Juan Pérez'),
        const CadeteProfile(id: 'cadete-2'),
      ]);
    });

    test('returns an empty list when no cadete rows are visible (RLS-filtered)', () async {
      final directory = SupabaseCadeteDirectory(
        MockSupabaseClient(),
        cadeteFetcher: () async => const [],
      );

      final cadetes = await directory.listCadetes();

      expect(cadetes, isEmpty);
    });
  });

  group('CadeteProfile.displayName', () {
    test('falls back to id when fullName is null', () {
      const cadete = CadeteProfile(id: 'cadete-1');
      expect(cadete.displayName, 'cadete-1');
    });

    test('falls back to id when fullName is blank', () {
      const cadete = CadeteProfile(id: 'cadete-1', fullName: '   ');
      expect(cadete.displayName, 'cadete-1');
    });

    test('uses fullName when present', () {
      const cadete = CadeteProfile(id: 'cadete-1', fullName: 'Juan Pérez');
      expect(cadete.displayName, 'Juan Pérez');
    });
  });
}
