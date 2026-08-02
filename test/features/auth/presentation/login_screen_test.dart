import 'package:ferrematica_express/features/auth/domain/app_session.dart';
import 'package:ferrematica_express/features/auth/domain/auth_repository.dart';
import 'package:ferrematica_express/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('empty submit shows validation errors and never signs in', (tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);

    await pumpApp(
      tester,
      const MaterialApp(home: LoginScreen()),
      authRepository: repository,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('Ingresá tu email'), findsOneWidget);
    expect(find.text('Ingresá tu contraseña'), findsOneWidget);
  });

  testWidgets('valid submit calls signIn and the session resolves', (tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);

    await pumpApp(
      tester,
      const MaterialApp(home: LoginScreen()),
      authRepository: repository,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'owner@ferrematica.test',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'secret123');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final session = await repository.watchSession().first;
    expect(session, isNotNull);
    expect(session!.rol, UserRole.dueno);
  });

  testWidgets('failed sign-in surfaces an error snackbar', (tester) async {
    final repository = _FailingAuthRepository();
    addTearDown(repository.dispose);

    await pumpApp(
      tester,
      const MaterialApp(home: LoginScreen()),
      authRepository: repository,
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'owner@ferrematica.test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'wrong');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('Email o contraseña incorrectos.'), findsOneWidget);
  });
}

/// [FakeAuthRepository] variant whose `signIn` always rejects, for the
/// error-path widget test above.
class _FailingAuthRepository extends FakeAuthRepository {
  @override
  Future<AppSession> signIn({required String email, required String password}) {
    throw const AuthSessionException('invalid credentials');
  }
}
