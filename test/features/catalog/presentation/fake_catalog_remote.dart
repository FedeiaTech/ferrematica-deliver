import 'package:ferrematica_express/features/catalog/data/supabase_catalog_remote.dart';
import 'package:ferrematica_express/features/catalog/domain/product.dart';

/// Builds a valid [Product] with sensible test defaults, overridable per
/// field.
Product buildTestProduct({
  String id = 'product-1',
  String sku = 'SKU-1',
  String name = 'Tornillo',
  double price = 10,
  double stock = 5,
  String unit = 'u',
  String category = 'General',
  bool isService = false,
  String? description,
  String? imageUrl,
}) => Product(
  id: id,
  sku: sku,
  name: name,
  price: price,
  stock: stock,
  unit: unit,
  category: category,
  isService: isService,
  description: description,
  imageUrl: imageUrl,
);

/// In-memory [CatalogRemote] double for provider/widget tests. Either seeds
/// a fixed product list, or (if [error] is set) throws it on [fetchAll].
class FakeCatalogRemote implements CatalogRemote {
  FakeCatalogRemote({List<Product> seed = const <Product>[], this.error})
    : _products = seed;

  final List<Product> _products;
  final Object? error;

  @override
  Future<List<Product>> fetchAll() async {
    if (error != null) throw error!;
    return _products;
  }
}
