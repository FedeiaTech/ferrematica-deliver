import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/product.dart';

/// Port over the `products` Supabase table, read-only.
abstract interface class CatalogRemote {
  /// All products the RLS policy `products_select_public` exposes (i.e.
  /// `is_active = true`), ordered by name.
  Future<List<Product>> fetchAll();
}

/// [CatalogRemote] backed by the real `supabase_flutter` client.
class SupabaseCatalogRemote implements CatalogRemote {
  SupabaseCatalogRemote(this._client);

  final SupabaseClient _client;

  static const String _table = 'products';
  // `products.image_url` (0007) is a legacy/fallback column the Web-Shop
  // admin panel never writes to — the real gallery lives in `product_images`
  // (0008), uploaded via ProductImages.tsx, one row per photo with
  // `is_primary`. Embed it via the FK (`product_images(...)`) instead of
  // reading the always-empty column, or every card silently falls back to
  // the placeholder icon regardless of what's actually uploaded.
  static const String _columns =
      'id,sku,name,description,price,stock,unit,category,is_service,'
      'product_images(url,is_primary,sort_order)';

  @override
  Future<List<Product>> fetchAll() async {
    // No `.eq('is_active', true)` and `is_active` is not even selected —
    // `products_select_public` already scopes reads to active rows.
    // Duplicating that predicate here would put the same business rule in
    // two places with nothing keeping them in sync, and would mask an RLS
    // regression instead of surfacing it.
    final rows = await _client.from(_table).select(_columns).order('name');
    return rows.map(productFromRow).toList(growable: false);
  }

  /// Maps a single row from `products` (with embedded `product_images`)
  /// into a [Product]. Public (`@visibleForTesting`) rather than private:
  /// the `stock`/`price` numeric-parsing risk (PostgREST returns `numeric`
  /// as a JSON number that lands as `int` when it has no fractional part)
  /// is this feature's highest correctness risk, so it gets a direct unit
  /// test.
  @visibleForTesting
  static Product productFromRow(Map<String, dynamic> row) => Product(
    id: row['id'] as String,
    sku: row['sku'] as String,
    name: row['name'] as String,
    description: row['description'] as String?,
    price: (row['price'] as num?)?.toDouble() ?? 0,
    stock: (row['stock'] as num?)?.toDouble() ?? 0,
    unit: (row['unit'] as String?) ?? 'u',
    category: _categoryLabelFromRow(row['category'] as String?),
    isService: (row['is_service'] as bool?) ?? false,
    imageUrl: _primaryImageUrlFromRow(row['product_images']),
  );

  /// Picks the thumbnail from the embedded `product_images` list: the row
  /// with `is_primary == true`, else the lowest `sort_order`, else null
  /// (no photos uploaded yet — the card falls back to a placeholder icon).
  static String? _primaryImageUrlFromRow(Object? productImages) {
    if (productImages is! List || productImages.isEmpty) return null;
    final images = productImages.cast<Map<String, dynamic>>();
    final primary = images.where((img) => img['is_primary'] == true);
    if (primary.isNotEmpty) return primary.first['url'] as String?;

    final sorted = [...images]..sort(
      (a, b) =>
          ((a['sort_order'] as num?) ?? 0).compareTo(
            (b['sort_order'] as num?) ?? 0,
          ),
    );
    return sorted.first['url'] as String?;
  }

  /// Null / blank / whitespace-only -> [kDefaultCategoryLabel]; otherwise
  /// the raw string unmodified (preserves casing/spacing for the chip
  /// label — the value in the database is never mutated).
  static String _categoryLabelFromRow(String? raw) {
    final trimmed = raw?.trim() ?? '';
    return trimmed.isEmpty ? kDefaultCategoryLabel : raw!;
  }
}
