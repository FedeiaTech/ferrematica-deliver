import 'dart:async';

import 'package:ferrematica_express/features/auth/domain/app_session.dart';
import 'package:ferrematica_express/features/auth/domain/auth_repository.dart';

/// In-memory [AuthRepository] double for widget tests, per the same
/// pattern as `FakeOrdersRepository` — overrides `authRepositoryProvider`
/// so tests never touch `supabase_flutter`. Starts with [initialSession]
/// (defaults to `null`, i.e. signed out); call [setSession] to simulate a
/// sign-in/sign-out/role change mid-test.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppSession? initialSession}) : _current = initialSession;

  AppSession? _current;
  final StreamController<AppSession?> _controller = StreamController<AppSession?>.broadcast();

  @override
  Stream<AppSession?> watchSession() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<AppSession> signIn({required String email, required String password}) async {
    final session =
        _current ?? const AppSession(userId: 'fake-user', rol: UserRole.dueno);
    setSession(session);
    return session;
  }

  @override
  Future<void> signOut() async => setSession(null);

  /// Pushes a new session (or `null` for signed-out) to every active
  /// [watchSession] listener.
  void setSession(AppSession? session) {
    _current = session;
    _controller.add(session);
  }

  void dispose() => _controller.close();
}
