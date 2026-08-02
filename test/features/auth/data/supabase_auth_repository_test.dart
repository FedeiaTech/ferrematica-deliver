import 'dart:async';

import 'package:ferrematica_express/features/auth/data/supabase_auth_repository.dart';
import 'package:ferrematica_express/features/auth/domain/app_session.dart';
import 'package:ferrematica_express/features/auth/domain/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

User _fakeUser(String id) => User(
  id: id,
  appMetadata: const <String, dynamic>{},
  userMetadata: const <String, dynamic>{},
  aud: 'authenticated',
  createdAt: DateTime(2026, 1, 1).toIso8601String(),
);

Session _fakeSession(String userId) =>
    Session(accessToken: 'fake-token', tokenType: 'bearer', user: _fakeUser(userId));

void main() {
  late MockSupabaseClient client;
  late MockGoTrueClient goTrue;

  setUp(() {
    client = MockSupabaseClient();
    goTrue = MockGoTrueClient();
    when(() => client.auth).thenReturn(goTrue);
  });

  group('signIn', () {
    test('resolves an AppSession with the role read via roleFetcher', () async {
      when(
        () => goTrue.signInWithPassword(email: 'owner@ferrematica.test', password: 'secret123'),
      ).thenAnswer((_) async => AuthResponse(session: _fakeSession('user-1')));

      final repository = SupabaseAuthRepository(
        client,
        roleFetcher: (userId) async {
          expect(userId, 'user-1');
          return 'dueno';
        },
      );

      final session = await repository.signIn(
        email: 'owner@ferrematica.test',
        password: 'secret123',
      );

      expect(session, const AppSession(userId: 'user-1', rol: UserRole.dueno));
    });

    test('resolves cadete role from roleFetcher', () async {
      when(
        () => goTrue.signInWithPassword(email: 'cadete@ferrematica.test', password: 'secret123'),
      ).thenAnswer((_) async => AuthResponse(session: _fakeSession('user-2')));

      final repository = SupabaseAuthRepository(
        client,
        roleFetcher: (_) async => 'cadete',
      );

      final session = await repository.signIn(
        email: 'cadete@ferrematica.test',
        password: 'secret123',
      );

      expect(session.rol, UserRole.cadete);
    });

    test('propagates invalid-credentials failures without creating a session', () async {
      when(
        () => goTrue.signInWithPassword(email: 'owner@ferrematica.test', password: 'wrong'),
      ).thenThrow(const AuthApiException('Invalid login credentials'));

      final repository = SupabaseAuthRepository(client, roleFetcher: (_) async => 'dueno');

      expect(
        () => repository.signIn(email: 'owner@ferrematica.test', password: 'wrong'),
        throwsA(isA<AuthApiException>()),
      );
    });

    test('throws AuthSessionException when no profiles row resolves a role', () async {
      when(
        () => goTrue.signInWithPassword(email: 'orphan@ferrematica.test', password: 'secret123'),
      ).thenAnswer((_) async => AuthResponse(session: _fakeSession('user-3')));

      final repository = SupabaseAuthRepository(
        client,
        roleFetcher: (_) async => throw const AuthSessionException('No profiles row found'),
      );

      expect(
        () => repository.signIn(email: 'orphan@ferrematica.test', password: 'secret123'),
        throwsA(isA<AuthSessionException>()),
      );
    });
  });

  group('signOut', () {
    test('delegates to GoTrueClient.signOut', () async {
      when(() => goTrue.signOut()).thenAnswer((_) async {});

      final repository = SupabaseAuthRepository(client, roleFetcher: (_) async => 'dueno');
      await repository.signOut();

      verify(() => goTrue.signOut()).called(1);
    });
  });

  group('watchSession', () {
    test('emits null when signed out, then a resolved session on sign-in', () async {
      final controller = StreamController<AuthState>();
      when(() => goTrue.onAuthStateChange).thenAnswer((_) => controller.stream);

      final repository = SupabaseAuthRepository(client, roleFetcher: (_) async => 'dueno');

      final emissions = <AppSession?>[];
      final subscription = repository.watchSession().listen(emissions.add);
      addTearDown(subscription.cancel);

      controller.add(const AuthState(AuthChangeEvent.signedOut, null));
      await pumpEventQueue();
      controller.add(AuthState(AuthChangeEvent.signedIn, _fakeSession('user-1')));
      await pumpEventQueue();

      expect(emissions, [null, const AppSession(userId: 'user-1', rol: UserRole.dueno)]);

      await controller.close();
    });
  });
}
