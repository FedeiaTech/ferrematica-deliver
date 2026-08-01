import 'package:ferrematica_express/core/config/app_config.dart';
import 'package:ferrematica_express/core/config/providers.dart';
import 'package:ferrematica_express/core/database/providers.dart';
import 'package:ferrematica_express/core/supabase/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_isar.dart';

/// Fake [AppConfig] used by [pumpApp]. Values are non-empty so
/// [AppConfig.isValid] is true, matching a healthy boot.
const AppConfig fakeAppConfig = AppConfig(
  supabaseUrl: 'https://fake.supabase.test',
  supabaseAnonKey: 'fake-anon-key',
  mapsApiKey: 'fake-maps-key',
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
/// Extra [overrides] are appended last, so callers can replace any of the
/// default overrides above (e.g. a feature-specific fake repository).
Future<void> pumpApp(
  WidgetTester tester,
  Widget widget, {
  List<Override> overrides = const <Override>[],
}) async {
  final isar = await tester.runAsync(openTestIsar);
  if (isar == null) {
    throw StateError('tester.runAsync returned null while opening test Isar');
  }
  addTearDown(() => tester.runAsync(() => closeTestIsar(isar)));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(fakeAppConfig),
        isarProvider.overrideWithValue(isar),
        supabaseProvider.overrideWithValue(MockSupabaseClient()),
        ...overrides,
      ],
      child: widget,
    ),
  );
}
