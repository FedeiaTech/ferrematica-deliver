/// Read-only product catalog domain model.
///
/// Deliberately diverges from `features/orders/`: no Isar, no local model
/// (`*_model.dart`/`.g.dart`), no sync service. Products are POS-written and
/// app-read-only, publicly readable via RLS — the orders sync apparatus
/// (`order_sync_service.dart`, `sync_cursor.dart`, last-write-wins triggers)
/// exists solely because orders are dueño-writable and need offline
/// queueing. Replicating it here would buy a marginal offline win at the
/// cost of a second sync engine to maintain. This is an intentional
/// divergence, not an oversight.
library;

/// Fallback category label used when a product's `category` column is
/// null, empty, or whitespace-only — matches the same fallback the POS uses.
const String kDefaultCategoryLabel = 'General';

/// A single product row from the `products` table.
final class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.price,
    required this.stock,
    required this.unit,
    required this.category,
    required this.isService,
    this.description,
    this.imageUrl,
  });

  final String id;
  final String sku;
  final String name;
  final double price;
  final double stock;
  final String unit;
  final String category;
  final bool isService;
  final String? description;
  final String? imageUrl;

  /// Normalized (trimmed, case-folded) grouping key for [category].
  String get categoryKey => categoryKeyOf(category);

  /// Whether [imageUrl] has a non-blank value.
  bool get hasImage => (imageUrl ?? '').trim().isNotEmpty;

  @override
  bool operator ==(Object other) => other is Product && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Normalizes [raw] into a stable grouping key: trims whitespace and
/// case-folds to lowercase. Null or blank/whitespace-only input maps to
/// `'general'` (the key form of [kDefaultCategoryLabel]).
String categoryKeyOf(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return kDefaultCategoryLabel.toLowerCase();
  return trimmed.toLowerCase();
}

/// Formats [value] as a decimal string without trailing zeros, e.g.
/// `2.5 -> "2.5"`, `10.0 -> "10"`, `0.75 -> "0.75"`. Zero and negative
/// values pass through unchanged (never hidden or clamped).
String formatStock(double value) {
  var text = value.toStringAsFixed(3);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}

/// Formats [value] as a price string, e.g. `100.0 -> "\$100.00"`.
String formatPrice(double value) => '\$${value.toStringAsFixed(2)}';
