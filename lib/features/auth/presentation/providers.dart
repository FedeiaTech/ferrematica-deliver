import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/last_email_store.dart';
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
    if (!state.hasError) unawaited(LastEmailStore.save(email));
  }
}

final NotifierProvider<LoginController, AsyncValue<void>> loginControllerProvider =
    NotifierProvider<LoginController, AsyncValue<void>>(LoginController.new);

/// One-shot fetch of every ACTIVE available cadete account, consumed by
/// the dueño-facing "assign cadete" sheet (`assign_cadete_sheet.dart`). A
/// plain [FutureProvider] (not a stream) is enough — the picker is opened
/// fresh each time from a modal bottom sheet, so there is no long-lived UI
/// to keep in sync with cadete roster changes mid-session.
final FutureProvider<List<CadeteProfile>> cadeteListProvider =
    FutureProvider<List<CadeteProfile>>((ref) {
      return ref.watch(cadeteDirectoryProvider).listCadetes();
    });

/// One-shot fetch of EVERY cadete account (active and inactive), consumed
/// by the manage-cadetes screen and the stats screen's cadete filter — see
/// [CadeteDirectory.listAllCadetes]'s doc comment for why both need
/// inactive rows visible too. Kept as a separate provider (rather than
/// widening [cadeteListProvider] itself) so the assignment picker's
/// active-only contract stays simple and doesn't need a filter re-applied
/// at every call site.
final FutureProvider<List<CadeteProfile>> allCadetesProvider =
    FutureProvider<List<CadeteProfile>>((ref) {
      return ref.watch(cadeteDirectoryProvider).listAllCadetes();
    });

/// Owner of the "create cadete" form's submit action (`CreateCadeteScreen`).
/// Mirrors [LoginController]'s loading/error exposure shape so the screen
/// can disable its submit button and surface [CadeteDirectoryException]
/// messages the same way the rest of the app's forms do.
class CreateCadeteController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> create({
    required String email,
    required String password,
    required String nombre,
    int? nro,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(cadeteDirectoryProvider)
          .createCadete(email: email, password: password, nombre: nombre, nro: nro),
    );
    if (!state.hasError) ref.invalidate(allCadetesProvider);
  }
}

final NotifierProvider<CreateCadeteController, AsyncValue<void>>
createCadeteControllerProvider =
    NotifierProvider<CreateCadeteController, AsyncValue<void>>(
      CreateCadeteController.new,
    );

/// Owner of the manage-cadetes screen's edit-sheet submit action (nombre +
/// nro). Same loading/error shape as [CreateCadeteController]; invalidates
/// [allCadetesProvider] on success so the roster list reflects the edit
/// immediately without the dueño needing to pull-to-refresh.
class UpdateCadeteController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> update({required String id, required String nombre, int? nro}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(cadeteDirectoryProvider).updateCadete(id: id, nombre: nombre, nro: nro),
    );
    if (!state.hasError) ref.invalidate(allCadetesProvider);
  }
}

final NotifierProvider<UpdateCadeteController, AsyncValue<void>>
updateCadeteControllerProvider =
    NotifierProvider<UpdateCadeteController, AsyncValue<void>>(
      UpdateCadeteController.new,
    );

/// Owner of the manage-cadetes screen's baja/reactivar toggle. Same
/// loading/error shape as [CreateCadeteController]; invalidates both
/// roster providers on success — [allCadetesProvider] (management screen)
/// AND [cadeteListProvider] (assignment picker), since deactivating a
/// cadete must immediately stop them appearing as an assignment option.
class SetCadeteActiveController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> setActive({required String id, required bool active}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(cadeteDirectoryProvider).setCadeteActive(id: id, active: active),
    );
    if (!state.hasError) {
      ref.invalidate(allCadetesProvider);
      ref.invalidate(cadeteListProvider);
    }
  }
}

final NotifierProvider<SetCadeteActiveController, AsyncValue<void>>
setCadeteActiveControllerProvider =
    NotifierProvider<SetCadeteActiveController, AsyncValue<void>>(
      SetCadeteActiveController.new,
    );
