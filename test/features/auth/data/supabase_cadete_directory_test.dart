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
          {'id': 'cadete-1', 'full_name': 'Juan Pérez', 'nro': 3, 'active': true},
          {'id': 'cadete-2', 'full_name': null, 'nro': null, 'active': true},
        ],
      );

      final cadetes = await directory.listCadetes();

      expect(cadetes, [
        const CadeteProfile(id: 'cadete-1', fullName: 'Juan Pérez', nro: 3),
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

  group('listAllCadetes', () {
    test('maps rows from the injected allCadeteFetcher, including inactive ones', () async {
      final directory = SupabaseCadeteDirectory(
        MockSupabaseClient(),
        allCadeteFetcher: () async => [
          {'id': 'cadete-1', 'full_name': 'Juan Pérez', 'nro': 1, 'active': true},
          {'id': 'cadete-2', 'full_name': 'Ana Gómez', 'nro': 2, 'active': false},
        ],
      );

      final cadetes = await directory.listAllCadetes();

      expect(cadetes, [
        const CadeteProfile(id: 'cadete-1', fullName: 'Juan Pérez', nro: 1),
        const CadeteProfile(id: 'cadete-2', fullName: 'Ana Gómez', nro: 2, active: false),
      ]);
    });
  });

  group('createCadete', () {
    test('returns the new user id from the injected cadeteCreator', () async {
      final directory = SupabaseCadeteDirectory(
        MockSupabaseClient(),
        cadeteCreator: ({required email, required password, required nombre, nro}) async => {
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

    test('passes email/password/nombre/nro through to the cadeteCreator', () async {
      String? capturedEmail;
      String? capturedPassword;
      String? capturedNombre;
      int? capturedNro;
      final directory = SupabaseCadeteDirectory(
        MockSupabaseClient(),
        cadeteCreator: ({required email, required password, required nombre, nro}) async {
          capturedEmail = email;
          capturedPassword = password;
          capturedNombre = nombre;
          capturedNro = nro;
          return {'id': 'new-cadete-id'};
        },
      );

      await directory.createCadete(
        email: 'cadete@example.com',
        password: 'secret123',
        nombre: 'Juan Pérez',
        nro: 7,
      );

      expect(capturedEmail, 'cadete@example.com');
      expect(capturedPassword, 'secret123');
      expect(capturedNombre, 'Juan Pérez');
      expect(capturedNro, 7);
    });

    test('throws CadeteDirectoryException when no id is returned', () async {
      final directory = SupabaseCadeteDirectory(
        MockSupabaseClient(),
        cadeteCreator: ({required email, required password, required nombre, nro}) async => {},
      );

      expect(
        () => directory.createCadete(
          email: 'cadete@example.com',
          password: 'secret123',
          nombre: 'Juan Pérez',
        ),
        throwsA(isA<CadeteDirectoryException>()),
      );
    });

    test('propagates CadeteDirectoryException thrown by the cadeteCreator', () async {
      final directory = SupabaseCadeteDirectory(
        MockSupabaseClient(),
        cadeteCreator: ({required email, required password, required nombre, nro}) async {
          throw const CadeteDirectoryException('Ya existe una cuenta con ese email.');
        },
      );

      expect(
        () => directory.createCadete(
          email: 'cadete@example.com',
          password: 'secret123',
          nombre: 'Juan Pérez',
        ),
        throwsA(
          isA<CadeteDirectoryException>().having(
            (error) => error.message,
            'message',
            'Ya existe una cuenta con ese email.',
          ),
        ),
      );
    });
  });

  group('updateCadete', () {
    test('passes id/nombre/nro through to the cadeteUpdater', () async {
      String? capturedId;
      String? capturedNombre;
      int? capturedNro;
      final directory = SupabaseCadeteDirectory(
        MockSupabaseClient(),
        cadeteUpdater: ({required id, required nombre, nro}) async {
          capturedId = id;
          capturedNombre = nombre;
          capturedNro = nro;
        },
      );

      await directory.updateCadete(id: 'cadete-1', nombre: 'Nuevo nombre', nro: 9);

      expect(capturedId, 'cadete-1');
      expect(capturedNombre, 'Nuevo nombre');
      expect(capturedNro, 9);
    });

    test('propagates CadeteDirectoryException thrown by the cadeteUpdater', () async {
      final directory = SupabaseCadeteDirectory(
        MockSupabaseClient(),
        cadeteUpdater: ({required id, required nombre, nro}) async {
          throw const CadeteDirectoryException('Ya hay un cadete activo con ese número.');
        },
      );

      expect(
        () => directory.updateCadete(id: 'cadete-1', nombre: 'X'),
        throwsA(isA<CadeteDirectoryException>()),
      );
    });
  });

  group('setCadeteActive', () {
    test('passes id/active through to the cadeteActiveSetter', () async {
      String? capturedId;
      bool? capturedActive;
      final directory = SupabaseCadeteDirectory(
        MockSupabaseClient(),
        cadeteActiveSetter: ({required id, required active}) async {
          capturedId = id;
          capturedActive = active;
        },
      );

      await directory.setCadeteActive(id: 'cadete-1', active: false);

      expect(capturedId, 'cadete-1');
      expect(capturedActive, false);
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

  group('CadeteProfile.displayLabel', () {
    test('zero-pads nro and prefixes with #', () {
      const cadete = CadeteProfile(id: 'cadete-1', fullName: 'Carlos', nro: 3);
      expect(cadete.displayLabel, '#03 - Carlos');
    });

    test('does not pad nro already 2+ digits', () {
      const cadete = CadeteProfile(id: 'cadete-1', fullName: 'Carlos', nro: 12);
      expect(cadete.displayLabel, '#12 - Carlos');
    });

    test('falls back to displayName alone when nro is null', () {
      const cadete = CadeteProfile(id: 'cadete-1', fullName: 'Carlos');
      expect(cadete.displayLabel, 'Carlos');
    });
  });
}
