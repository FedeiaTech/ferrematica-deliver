import 'package:ferrematica_express/features/orders/domain/order.dart';
import 'package:ferrematica_express/features/orders/presentation/widgets/order_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('orderStatusLabel', () {
    test('enCamino has a distinct Spanish label', () {
      expect(orderStatusLabel(OrderStatus.enCamino), 'En camino');
    });

    test('every status has a non-empty, unique label', () {
      final labels = OrderStatus.values.map(orderStatusLabel).toList();
      expect(labels.every((label) => label.isNotEmpty), isTrue);
      expect(labels.toSet(), hasLength(OrderStatus.values.length));
    });
  });

  group('orderStatusColor', () {
    test('enCamino has its own color, distinct from the other four statuses', () {
      final enCaminoColor = orderStatusColor(OrderStatus.enCamino);
      final otherColors = OrderStatus.values
          .where((status) => status != OrderStatus.enCamino)
          .map(orderStatusColor);

      expect(otherColors, isNot(contains(enCaminoColor)));
    });

    test('every status maps to a distinct color', () {
      final colors = OrderStatus.values.map(orderStatusColor).toSet();
      expect(colors, hasLength(OrderStatus.values.length));
    });
  });

  group('orderStatusIcon', () {
    test('enCamino has its own icon', () {
      expect(orderStatusIcon(OrderStatus.enCamino), isNotNull);
    });

    test('every status maps to a distinct icon', () {
      final icons = OrderStatus.values.map(orderStatusIcon).toSet();
      expect(icons, hasLength(OrderStatus.values.length));
    });
  });
}
