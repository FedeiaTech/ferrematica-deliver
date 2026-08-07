import 'package:ferrematica_express/features/catalog/domain/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('categoryKeyOf', () {
    test('trims and case-folds', () {
      expect(categoryKeyOf('Tornillería '), 'tornillería');
      expect(categoryKeyOf('tornilleria'), 'tornilleria');
      expect(categoryKeyOf('TORNILLERIA'), 'tornilleria');
    });

    test('null or blank falls back to the default category key', () {
      expect(categoryKeyOf(null), 'general');
      expect(categoryKeyOf(''), 'general');
      expect(categoryKeyOf('   '), 'general');
    });
  });

  group('formatStock', () {
    test('fractional value keeps its decimal', () {
      expect(formatStock(2.5), '2.5');
    });

    test('zero is shown as-is', () {
      expect(formatStock(0), '0');
    });

    test('negative value passes through unchanged', () {
      expect(formatStock(-3.5), '-3.5');
    });

    test('whole number drops trailing zeros', () {
      expect(formatStock(10.0), '10');
    });
  });

  group('formatPrice', () {
    test('formats with two decimals and a peso sign', () {
      expect(formatPrice(100), r'$100.00');
      expect(formatPrice(19.9), r'$19.90');
    });
  });
}
