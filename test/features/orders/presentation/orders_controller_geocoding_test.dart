import 'package:ferrematica_express/features/auth/data/providers.dart';
import 'package:ferrematica_express/features/auth/domain/app_session.dart';
import 'package:ferrematica_express/features/auth/presentation/providers.dart';
import 'package:ferrematica_express/features/delivery/data/providers.dart';
import 'package:ferrematica_express/features/delivery/domain/geocoding_client.dart';
import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:ferrematica_express/features/orders/presentation/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import 'fake_orders_repository.dart';

/// In-memory [GeocodingClient] double. Configurable per test to succeed,
/// return null (unresolvable address / bad key), or throw (defensive case:
/// [OrdersController] must swallow this too, even though the port contract
/// says implementations never throw).
class _FakeGeocodingClient implements GeocodingClient {
  _FakeGeocodingClient({this.result, this.throws = false});

  final GeocodeResult? result;
  final bool throws;
  final List<String> requestedAddresses = <String>[];

  @override
  Future<GeocodeResult?> geocode(String address) async {
    requestedAddresses.add(address);
    if (throws) throw StateError('geocoding blew up');
    return result;
  }
}

void main() {
  group('OrdersController geocoding (PR5)', () {
    late FakeOrdersRepository repository;
    late FakeAuthRepository authRepository;

    late ProviderContainer Function(GeocodingClient) buildContainer;

    setUp(() {
      repository = FakeOrdersRepository();
      authRepository = FakeAuthRepository(
        initialSession: const AppSession(userId: 'owner-1', rol: UserRole.dueno),
      );
      addTearDown(repository.dispose);
      addTearDown(authRepository.dispose);

      buildContainer = (geocodingClient) {
        final container = ProviderContainer(
          overrides: [
            ordersRepositoryProvider.overrideWithValue(repository),
            authRepositoryProvider.overrideWithValue(authRepository),
            geocodingClientProvider.overrideWithValue(geocodingClient),
          ],
        );
        addTearDown(container.dispose);
        return container;
      };
    });

    /// Subscribes to [sessionProvider] and pumps the microtask queue so its
    /// first emission lands before `createOrder`/`updateOrder` run — same
    /// workaround documented in `cadete_orders_provider_test.dart` for
    /// `sessionProvider.future` hanging intermittently under `-j 1`.
    Future<void> warmUpSession(ProviderContainer container) async {
      final sub = container.listen(sessionProvider, (_, _) {});
      await pumpEventQueue();
      sub.close();
    }

    test('order creation succeeds even when geocoding fails (returns null)', () async {
      final geocoding = _FakeGeocodingClient(result: null);
      final container = buildContainer(geocoding);
      await warmUpSession(container);

      await container
          .read(ordersControllerProvider.notifier)
          .createOrder(deliveryAddress: 'dirección imposible de ubicar');
      await pumpEventQueue();

      final orders = await repository.watchOrders().first;
      expect(orders, hasLength(1));
      expect(orders.single.latitude, isNull);
      expect(orders.single.longitude, isNull);
    });

    test('order creation succeeds even when the geocoding client throws', () async {
      final geocoding = _FakeGeocodingClient(throws: true);
      final container = buildContainer(geocoding);
      await warmUpSession(container);

      // Must not throw/propagate — order creation is unaffected.
      await container
          .read(ordersControllerProvider.notifier)
          .createOrder(deliveryAddress: 'Calle Falsa 123');
      await pumpEventQueue();

      final orders = await repository.watchOrders().first;
      expect(orders, hasLength(1));
      expect(orders.single.latitude, isNull);
      expect(orders.single.longitude, isNull);
    });

    test('successful geocode populates coordinates on the saved order', () async {
      final geocoding = _FakeGeocodingClient(
        result: const GeocodeResult(latitude: -34.6037, longitude: -58.3816),
      );
      final container = buildContainer(geocoding);
      await warmUpSession(container);

      await container
          .read(ordersControllerProvider.notifier)
          .createOrder(deliveryAddress: 'Av. Siempre Viva 742');
      // Let the fire-and-forget background geocode + follow-up save run.
      await pumpEventQueue();

      final orders = await repository.watchOrders().first;
      expect(orders, hasLength(1));
      expect(orders.single.latitude, -34.6037);
      expect(orders.single.longitude, -58.3816);
      expect(geocoding.requestedAddresses, ['Av. Siempre Viva 742']);
    });

    test('editing an order with an unchanged address does not re-geocode', () async {
      final geocoding = _FakeGeocodingClient(
        result: const GeocodeResult(latitude: 1, longitude: 2),
      );
      final container = buildContainer(geocoding);
      await warmUpSession(container);

      final existing = buildTestOrder(id: 'order-1', deliveryAddress: 'Calle Falsa 123');
      await repository.save(existing);

      await container
          .read(ordersControllerProvider.notifier)
          .updateOrder(existing.copyWith(notes: 'nota nueva'));
      await pumpEventQueue();

      expect(geocoding.requestedAddresses, isEmpty);
      final saved = await repository.getById('order-1');
      expect(saved!.latitude, isNull);
    });

    test('editing an order with a changed address re-geocodes and updates coordinates', () async {
      final geocoding = _FakeGeocodingClient(
        result: const GeocodeResult(latitude: 10, longitude: 20),
      );
      final container = buildContainer(geocoding);
      await warmUpSession(container);

      final existing = buildTestOrder(id: 'order-1', deliveryAddress: 'Calle Falsa 123');
      await repository.save(existing);

      await container
          .read(ordersControllerProvider.notifier)
          .updateOrder(existing.copyWith(deliveryAddress: 'Nueva Dirección 456'));
      await pumpEventQueue();

      expect(geocoding.requestedAddresses, ['Nueva Dirección 456']);
      final saved = await repository.getById('order-1');
      expect(saved!.latitude, 10);
      expect(saved.longitude, 20);
    });
  });
}
