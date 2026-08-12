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

  group('createCadete', () {
    test('returns the new user id from the injected cadeteCreator', () async {
      final directory = SupabaseCadeteDirectory(
        MockSupabaseClient(),
        cadeteCreator: ({required email, required password, required nombre}) async => {
          'id': 'new-cadete-id',
        },
      );

      final id = await directory.createCadete(
        email: 'cadete@example.com',
        password: 'secret123',
        nombre: 'Juan Pérez',
      );

      expect(id, 'new-cadete-id');
    });

    test('passes email/password/nombre through to the cadeteCreator', () async {
      String? capturedEmail;
      String? capturedPassword;
      String? capturedNombre;
      final directory = SupabaseCadeteDirectory(
        MockSupabaseClient(),
        cadeteCreator: ({required email, required password, required nombre}) async {
          capturedEmail = email;
          capturedPassword = password;
          capturedNombre = nombre;
          return {'id': 'new-cadete-id'};
        },
      );

      await directory.createCadete(
        email: 'cadete@example.com',
        password: 'secret123',
        nombre: 'Juan Pérez',
      );

      expect(capturedEmail, 'cadete@example.com');
      expect(capturedPassword, 'secret123');
      expect(capturedNombre, 'Juan Pérez');
    });

    test('throws CadeteCreationException when no id is returned', () async {
      final directory = SupabaseCadeteDirectory(
        MockSupabaseClient(),
        cadeteCreator: ({required email, required password, required nombre}) async => {},
      );

      expect(
        () => directory.createCadete(
          email: 'cadete@example.com',
          password: 'secret123',
          nombre: 'Juan Pérez',
        ),
        throwsA(isA<CadeteCreationException>()),
      );
    });

    test('propagates CadeteCreationException thrown by the cadeteCreator', () async {
      final directory = SupabaseCadeteDirectory(
        MockSupabaseClient(),
        cadeteCreator: ({required email, required password, required nombre}) async {
          throw const CadeteCreationException('Ya existe una cuenta con ese email.');
        },
      );

      expect(
        () => directory.createCadete(
          email: 'cadete@example.com',
          password: 'secret123',
          nombre: 'Juan Pérez',
        ),
        throwsA(
          isA<CadeteCreationException>().having(
            (error) => error.message,
            'message',
            'Ya existe una cuenta con ese email.',
          ),
        ),
      );
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
