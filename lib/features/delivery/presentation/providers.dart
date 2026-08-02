import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/providers.dart' show ordersStreamProvider;

/// [ordersStreamProvider] filtered client-side to only the orders assigned
/// to the currently signed-in cadete (spec's `cadete-orders` domain:
/// "MUST show a cadete only orders where `assigned_cadete_id` equals their
/// own user id, enforced both client-side and via RLS"). The `cadete_select`
/// RLS policy already scopes what the Supabase query returns server-side —
/// this filter is the client-side half of that same requirement, and also
/// protects against a stale/cached row for a since-reassigned order
/// lingering in the shared [ordersStreamProvider] cache.
///
/// Returns an empty list (never an error) while the session is still
/// resolving or if there is no session, matching [OrdersController
/// .createOrder]'s treatment of "no session" as a state the router guard
/// should make unreachable in practice rather than a screen-level error.
final Provider<AsyncValue<List<Order>>> cadeteOrdersProvider =
    Provider<AsyncValue<List<Order>>>((ref) {
      final session = ref.watch(sessionProvider).value;
      final ordersAsync = ref.watch(ordersStreamProvider);
      if (session == null) {
        return const AsyncValue<List<Order>>.data(<Order>[]);
      }
      return ordersAsync.whenData(
        (orders) => orders
            .where((order) => order.assignedCadeteId == session.userId)
            .toList(growable: false),
      );
    });
