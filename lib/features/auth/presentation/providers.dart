import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../domain/app_session.dart';
import '../domain/cadete_directory.dart';

/// The resolved session (userId + rol), or `null` when signed out, or an
/// [AsyncError] if the `profiles` role lookup failed. This is the single
/// source of truth the router guard (`app_router.dart`) and order-creation
/// flow (`OrdersController.createOrder`) read from — see design decision
/// #1. Backed by [AuthRepository.watchSession], which itself wraps
/// `supabase_flutter`'s `onAuthStateChange` — so a session restored from
/// disk on app start, a fresh sign-in, and a sign-out all flow through this
/// single provider.
final StreamProvider<AppSession?> sessionProvider = StreamProvider<AppSession?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.watchSession();
});

/// Owner of the login form's submit action. Exposes loading/error state so
/// [LoginScreen] can disable the submit button and surface failures,
/// without the screen touching [AuthRepository] directly.
class LoginController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signIn(email: email, password: password),
    );
  }
}

final NotifierProvider<LoginController, AsyncValue<void>> loginControllerProvider =
    NotifierProvider<LoginController, AsyncValue<void>>(LoginController.new);

/// One-shot fetch of every available cadete account, consumed by the
/// dueño-facing "assign cadete" sheet (`assign_cadete_sheet.dart`). A plain
/// [FutureProvider] (not a stream) is enough — the picker is opened fresh
/// each time from a modal bottom sheet, so there is no long-lived UI to
/// keep in sync with cadete roster changes mid-session.
final FutureProvider<List<CadeteProfile>> cadeteListProvider =
    FutureProvider<List<CadeteProfile>>((ref) {
      return ref.watch(cadeteDirectoryProvider).listCadetes();
    });
