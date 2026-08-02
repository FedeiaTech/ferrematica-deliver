import 'package:ferrematica_express/features/auth/data/providers.dart';
import 'package:ferrematica_express/features/auth/domain/app_session.dart';
import 'package:ferrematica_express/features/auth/presentation/providers.dart';
import 'package:ferrematica_express/features/delivery/presentation/providers.dart';
import 'package:ferrematica_express/features/orders/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../orders/presentation/fake_orders_repository.dart';

/// Subscribes to [sessionProvider] and pumps a microtask so its first
/// (synchronously-yielded-but-stream-wrapped) emission lands before
/// [cadeteOrdersProvider] is read — mirrors `test/helpers/pump_app.dart`'s
/// documented workaround for `sessionProvider.future` hanging
/// intermittently under `flutter test -j 1`; reading through a `listen`
/// subscription instead avoids that hang.
Future<void> _warmUpSession(ProviderContainer container) async {
  final sessionSub = container.listen(sessionProvider, (_, _) {});
  final ordersSub = container.listen(cadeteOrdersProvider, (_, _) {});
  await pumpEventQueue();
  sessionSub.close();
  ordersSub.close();
}

void main() {
  group('cadeteOrdersProvider', () {
    test('only returns orders assigned to the signed-in cadete', () async {
      final ordersRepository = FakeOrdersRepository(
        seed: [
          buildTestOrder(id: 'order-1', assignedCadeteId: 'cadete-1'),
          buildTestOrder(id: 'order-2', assignedCadeteId: 'cadete-2'),
          buildTestOrder(id: 'order-3', assignedCadeteId: null),
        ],
      );
      addTearDown(ordersRepository.dispose);
      final authRepository = FakeAuthRepository(
        initialSession: const AppSession(userId: 'cadete-1', rol: UserRole.cadete),
      );
      addTearDown(authRepository.dispose);

      final container = ProviderContainer(
        overrides: [
          ordersRepositoryProvider.overrideWithValue(ordersRepository),
          authRepositoryProvider.overrideWithValue(authRepository),
        ],
      );
      addTearDown(container.dispose);

      await _warmUpSession(container);

      final result = container.read(cadeteOrdersProvider);
      final orders = result.value!;
      expect(orders.map((o) => o.id), ['order-1']);
    });

    test('reassigning an order moves it out of a cadete\'s list', () async {
      final ordersRepository = FakeOrdersRepository(
        seed: [buildTestOrder(id: 'order-1', assignedCadeteId: 'cadete-1')],
      );
      addTearDown(ordersRepository.dispose);
      final authRepository = FakeAuthRepository(
        initialSession: const AppSession(userId: 'cadete-1', rol: UserRole.cadete),
      );
      addTearDown(authRepository.dispose);

      final container = ProviderContainer(
        overrides: [
          ordersRepositoryProvider.overrideWithValue(ordersRepository),
          authRepositoryProvider.overrideWithValue(authRepository),
        ],
      );
      addTearDown(container.dispose);

      await _warmUpSession(container);
      final subscription = container.listen(cadeteOrdersProvider, (_, _) {});
      expect(subscription.read().value!.map((o) => o.id), ['order-1']);

      final order = await ordersRepository.getById('order-1');
      await ordersRepository.save(order!.copyWith(assignedCadeteId: 'cadete-2'));
      await Future<void>.delayed(Duration.zero);

      expect(subscription.read().value!, isEmpty);
    });

    test('returns an empty list, not an error, with no session', () async {
      final ordersRepository = FakeOrdersRepository(
        seed: [buildTestOrder(id: 'order-1', assignedCadeteId: 'cadete-1')],
      );
      addTearDown(ordersRepository.dispose);
      final authRepository = FakeAuthRepository();
      addTearDown(authRepository.dispose);

      final container = ProviderContainer(
        overrides: [
          ordersRepositoryProvider.overrideWithValue(ordersRepository),
          authRepositoryProvider.overrideWithValue(authRepository),
        ],
      );
      addTearDown(container.dispose);

      await _warmUpSession(container);

      final result = container.read(cadeteOrdersProvider);
      expect(result.value, isEmpty);
      expect(result.hasError, isFalse);
    });
  });
}
