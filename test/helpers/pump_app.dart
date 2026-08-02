import 'package:ferrematica_express/core/config/app_config.dart';
import 'package:ferrematica_express/core/config/providers.dart';
import 'package:ferrematica_express/core/database/providers.dart';
import 'package:ferrematica_express/core/supabase/providers.dart';
import 'package:ferrematica_express/features/auth/data/providers.dart';
import 'package:ferrematica_express/features/auth/domain/app_session.dart';
import 'package:ferrematica_express/features/auth/domain/auth_repository.dart';
import 'package:ferrematica_express/features/auth/presentation/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_auth_repository.dart';
import 'test_isar.dart';

/// Fake [AppConfig] used by [pumpApp]. Values are non-empty so
/// [AppConfig.isValid] is true, matching a healthy boot.
const AppConfig fakeAppConfig = AppConfig(
  supabaseUrl: 'https://fake.supabase.test',
  supabaseAnonKey: 'fake-anon-key',
);

/// Mocktail double for [SupabaseClient]. Per design decision #7, vendor
/// surfaces (Supabase, generated Isar code) are not exercised with real
/// network/native calls in widget tests — only our own port interfaces are
/// mocked directly. [SupabaseClient] has no real port wrapper yet, so it is
/// mocked here instead of using a real client.
class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Widget-test harness that pumps [widget] inside a [ProviderScope] with
/// fake bootstrap dependencies (`AppConfig`, Isar, Supabase), so widget
/// tests never touch real infrastructure or the network.
///
/// Isar is a **real** instance backed by a fresh temp directory (per design
/// decision #7 — generated Isar code is not mocked), opened via
/// [openTestIsar] and closed automatically via [addTearDown]. This requires
/// `flutter test -j 1` (see `test_isar.dart`).
///
/// Opening/closing Isar does real native FFI + file I/O, so both calls are
/// wrapped in [WidgetTester.runAsync]: `testWidgets`'s automated test zone
/// fakes the clock and won't drive real OS-level async completions (e.g. the
/// isar loader isolate's callback), which otherwise hangs indefinitely
/// instead of throwing.
///
/// Default authenticated session used unless a test overrides
/// `authRepositoryProvider` itself (e.g. to test the login/logged-out
/// router path). Most widget tests exercise screens that assume an
/// authenticated dueño, matching pre-auth test behavior.
const AppSession fakeDuenoSession = AppSession(userId: 'fake-owner', rol: UserRole.dueno);

/// Extra [overrides] are appended last, so callers can replace any of the
/// default overrides above (e.g. a feature-specific fake repository). Auth
/// is deliberately **not** part of [overrides] — pass [authRepository]
/// instead (e.g. a [FakeAuthRepository] with a different session, or one
/// signed out) — `ProviderContainer` throws if the same provider is
/// overridden twice, which would happen if both this helper's default and a
/// caller-supplied override targeted `authRepositoryProvider`.
///
/// Builds an explicit [ProviderContainer] (via [UncontrolledProviderScope])
/// instead of a plain [ProviderScope] so the same container instance is
/// reachable for [_SessionWarmup] below, which establishes the **one**
/// canonical widget-tree subscription to [sessionProvider] before [widget]
/// itself mounts. Without this, a screen that reads
/// `ref.read(sessionProvider)` synchronously in an event handler (e.g.
/// `OrdersController.createOrder`) could race the fake session stream's
/// first (asynchronous) emission and see a still-loading `AsyncValue`,
/// which doesn't happen in the real app since the router guard already
/// resolves the session before any authenticated screen mounts.
///
/// Deliberately does **not** warm up via `container.read(sessionProvider.
/// future)` before pumping — that path was observed to hang intermittently
/// under `flutter test -j 1` when run alongside the rest of the suite
/// (reproduced both isolated and in the full run; root cause not fully
/// isolated, but consistently avoided by subscribing through the widget
/// tree and a single extra [WidgetTester.pump] instead of awaiting the
/// provider's `Future` outside of it).
Future<void> pumpApp(
  WidgetTester tester,
  Widget widget, {
  List<Override> overrides = const <Override>[],
  AuthRepository? authRepository,
}) async {
  final isar = await tester.runAsync(openTestIsar);
  if (isar == null) {
    throw StateError('tester.runAsync returned null while opening test Isar');
  }
  addTearDown(() => tester.runAsync(() => closeTestIsar(isar)));

  final resolvedAuthRepository =
      authRepository ?? FakeAuthRepository(initialSession: fakeDuenoSession);
  if (authRepository == null) {
    addTearDown((resolvedAuthRepository as FakeAuthRepository).dispose);
  }

  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(fakeAppConfig),
      isarProvider.overrideWithValue(isar),
      supabaseProvider.overrideWithValue(MockSupabaseClient()),
      authRepositoryProvider.overrideWithValue(resolvedAuthRepository),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: _SessionWarmup(child: widget)),
  );
  // Flushes the fake session stream's first (microtask-async) emission so
  // sessionProvider is already `AsyncData` by the time a caller interacts
  // with the widget tree (e.g. taps a button that synchronously reads it).
  await tester.pump();
}

/// Subscribes to [sessionProvider] at the root of the pumped tree so it is
/// never read cold — see [pumpApp]'s doc comment.
class _SessionWarmup extends ConsumerWidget {
  const _SessionWarmup({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionProvider);
    return child;
  }
}
