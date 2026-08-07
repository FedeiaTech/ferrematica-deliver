import 'package:ferrematica_express/features/catalog/data/supabase_catalog_remote.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _baseRow({
  Object? stock,
  Object? price,
  Object? category,
  Object? productImages,
}) => <String, dynamic>{
  'id': 'product-1',
  'sku': 'SKU-1',
  'name': 'Tornillo',
  'description': null,
  'price': price ?? 10,
  'stock': stock ?? 5,
  'unit': 'u',
  'category': category,
  'is_service': false,
  'product_images': productImages ?? const <Map<String, dynamic>>[],
};

void main() {
  group('SupabaseCatalogRemote.productFromRow', () {
    test('integral stock JSON number maps to a double, not truncated', () {
      final product = SupabaseCatalogRemote.productFromRow(_baseRow(stock: 3));
      expect(product.stock, 3.0);
      expect(product.stock, isA<double>());
    });

    test('fractional stock is preserved', () {
      final product = SupabaseCatalogRemote.productFromRow(
        _baseRow(stock: 2.5),
      );
      expect(product.stock, 2.5);
    });

    test('integral price JSON number maps to a double', () {
      final product = SupabaseCatalogRemote.productFromRow(
        _baseRow(price: 100),
      );
      expect(product.price, 100.0);
    });

    test('null category falls back to General', () {
      final product = SupabaseCatalogRemote.productFromRow(
        _baseRow(category: null),
      );
      expect(product.category, 'General');
    });

    test('blank/whitespace-only category falls back to General', () {
      final product = SupabaseCatalogRemote.productFromRow(
        _baseRow(category: '   '),
      );
      expect(product.category, 'General');
    });

    test('non-blank category is preserved unmodified', () {
      final product = SupabaseCatalogRemote.productFromRow(
        _baseRow(category: 'Tornillería '),
      );
      expect(product.category, 'Tornillería ');
    });

    test('no product_images rows means hasImage is false', () {
      final product = SupabaseCatalogRemote.productFromRow(
        _baseRow(productImages: const <Map<String, dynamic>>[]),
      );
      expect(product.hasImage, isFalse);
      expect(product.imageUrl, isNull);
    });

    test('single product_images row is used as the thumbnail', () {
      final product = SupabaseCatalogRemote.productFromRow(
        _baseRow(
          productImages: [
            {
              'url': 'https://example.com/x.png',
              'is_primary': false,
              'sort_order': 0,
            },
          ],
        ),
      );
      expect(product.hasImage, isTrue);
      expect(product.imageUrl, 'https://example.com/x.png');
    });

    test('is_primary row wins over sort_order when multiple images exist', () {
      final product = SupabaseCatalogRemote.productFromRow(
        _baseRow(
          productImages: [
            {
              'url': 'https://example.com/first-by-order.png',
              'is_primary': false,
              'sort_order': 0,
            },
            {
              'url': 'https://example.com/primary.png',
              'is_primary': true,
              'sort_order': 2,
            },
          ],
        ),
      );
      expect(product.imageUrl, 'https://example.com/primary.png');
    });

    test('no primary flag falls back to the lowest sort_order', () {
      final product = SupabaseCatalogRemote.productFromRow(
        _baseRow(
          productImages: [
            {
              'url': 'https://example.com/second.png',
              'is_primary': false,
              'sort_order': 2,
            },
            {
              'url': 'https://example.com/first.png',
              'is_primary': false,
              'sort_order': 0,
            },
          ],
        ),
      );
      expect(product.imageUrl, 'https://example.com/first.png');
    });
  });
}
