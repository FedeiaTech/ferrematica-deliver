import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../core/database/providers.dart';
import '../../../core/supabase/providers.dart';
import '../../auth/data/providers.dart' show authRepositoryProvider;
import '../domain/orders_repository.dart';
import 'isar_orders_repository.dart';
import 'order_sync_service.dart';
import 'supabase_orders_remote.dart';
import 'venta_disponible.dart';
import 'ventas_remote.dart';

/// Exposes [Connectivity]'s change stream. Overridable in tests with a fake
/// `Stream<List<ConnectivityResult>>` (e.g. a `StreamController`).
final Provider<Stream<List<ConnectivityResult>>> connectivityProvider =
    Provider<Stream<List<ConnectivityResult>>>((ref) => Connectivity().onConnectivityChanged);

/// The app's [OrdersRepository], backed by the local Isar instance.
final Provider<OrdersRepository> ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => IsarOrdersRepository(ref.watch(isarProvider)),
);

/// The [OrdersRemote] port, backed by the real `supabase_flutter` client.
final Provider<OrdersRemote> ordersRemoteProvider = Provider<OrdersRemote>(
  (ref) => SupabaseOrdersRemote(ref.watch(supabaseProvider)),
);

/// Drives push/pull sync between Isar and Supabase for the `orders`
/// feature. A single instance lives for the app's lifetime; wires the
/// repository's post-write hook so a local mutation also triggers a drain
/// attempt (design's "post-write" trigger), alongside connectivity-regained
/// and app-resume triggers started internally by [OrderSyncService.start].
final Provider<OrderSyncService> orderSyncServiceProvider = Provider<OrderSyncService>((ref) {
  final repository = ref.watch(ordersRepositoryProvider);
  final service = OrderSyncService(
    repository: repository,
    remote: ref.watch(ordersRemoteProvider),
    isar: ref.watch(isarProvider),
    connectivityStream: ref.watch(connectivityProvider),
    sessionStream: ref.watch(authRepositoryProvider).watchSession(),
  );

  if (repository is IsarOrdersRepository) {
    repository.onWrite = service.drain;
  }

  service.start();
  ref.onDispose(service.dispose);
  return service;
});

/// The [VentasRemote] port, backed by the real `supabase_flutter` client.
/// Read-only from the UI's perspective (plus the write-only claim) — see
/// `sdd/ventas-sync-envio` design decision D7.
final Provider<VentasRemote> ventasRemoteProvider = Provider<VentasRemote>(
  (ref) => SupabaseVentasRemote(ref.watch(supabaseProvider)),
);

/// The day-window filter selected in `venta_picker_sheet.dart` — "Día"
/// (1), "Semana" (7, the RPC's own default), or "Mes" (30). `autoDispose`
/// so it resets to the default every time the picker is reopened, instead
/// of remembering the last-picked window across separate pedido-creation
/// sessions.
final StateProvider<int> ventaPickerDiasProvider = StateProvider.autoDispose<int>((ref) => 7);

/// Fetches the ventas eligible for the "desde venta" pedido picker
/// (`order-prefill-from-venta` spec domain), scoped to
/// [ventaPickerDiasProvider]'s currently selected window. `autoDispose` so
/// the list is re-fetched fresh every time the picker is opened (or the
/// window filter changes), instead of holding a stale cache between
/// pedido-creation sessions.
final FutureProvider<List<VentaDisponible>> ventasDisponiblesProvider =
    FutureProvider.autoDispose<List<VentaDisponible>>(
      (ref) => ref
          .watch(ventasRemoteProvider)
          .fetchDisponibles(dias: ref.watch(ventaPickerDiasProvider)),
    );

/// Every venta linked to the order [orderId] — `order_detail_screen.dart`
/// watches this to warn the dueño when a linked venta was anulada after the
/// pedido was created (design decision D8), and to list all of them when
/// more than one POS sale was bundled into the same delivery. `autoDispose`
/// so re-opening a detail screen re-checks instead of holding a stale
/// answer across the app's lifetime.
final linkedVentasProvider = FutureProvider.family.autoDispose<List<LinkedVenta>, String>(
  (ref, orderId) => ref.watch(ventasRemoteProvider).fetchLinkedVentas(orderId),
);

/// Same data as [linkedVentasProvider], polled every 30s instead of fetched
/// once — `order_detail_screen.dart`'s auto-cancel-on-venta-anulada check
/// needs to notice a POS annulment "de forma inmediata" (the dueño's own
/// words) even if the cadete never leaves the detail/navigation screens for
/// the whole trip, which a one-shot `FutureProvider` (re-checked only when
/// the screen is torn down and rebuilt) can't do. `autoDispose` stops the
/// polling loop the moment nothing is watching it anymore (screen closed).
///
/// A failed poll (offline cadete, transient network blip) simply doesn't
/// emit that tick — matching this port's usual "degrade, don't throw"
/// posture (the consumer's `AsyncValue` just keeps its last-known data),
/// and critically NOT blocking a cadete who genuinely has no signal from
/// continuing their delivery.
///
/// Built on a manual [StreamController] + [Timer.periodic] (not an
/// `async*` generator looping on `Future.delayed`) specifically so
/// [Timer.periodic] can be cancelled from `ref.onDispose` — an `async*`
/// loop's `Future.delayed` keeps the underlying platform timer alive past
/// disposal (nothing cancels it just because nobody's listening anymore).
final linkedVentasLiveProvider = StreamProvider.family.autoDispose<List<LinkedVenta>, String>((
  ref,
  orderId,
) {
  final remote = ref.watch(ventasRemoteProvider);
  final interval = ref.watch(linkedVentasPollIntervalProvider);
  final controller = StreamController<List<LinkedVenta>>();

  Future<void> poll() async {
    try {
      controller.add(await remote.fetchLinkedVentas(orderId));
    } catch (_) {
      // No emission this tick — see doc comment above.
    }
  }

  unawaited(poll());
  final timer = interval == null ? null : Timer.periodic(interval, (_) => poll());
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

/// The interval [linkedVentasLiveProvider] polls at — `null` means "fetch
/// once, never poll again". Overridden to `null` in widget tests
/// (`pump_app.dart`'s default overrides) so tests never spin up a real
/// [Timer.periodic]: `ref.onDispose` above DOES cancel it correctly, but
/// `flutter_test`'s pending-timer check runs before `addTearDown`
/// callbacks (like `ProviderContainer.dispose()`) get to fire, so a real
/// periodic timer trips "A Timer is still pending even after the widget
/// tree was disposed" regardless — a teardown-ordering quirk in the test
/// framework, not an actual leak in this provider.
final Provider<Duration?> linkedVentasPollIntervalProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: 30),
);
