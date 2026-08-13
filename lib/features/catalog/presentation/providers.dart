import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../data/providers.dart';
import '../domain/product.dart';

/// One-shot fetch of the full product catalog. `FutureProvider`, not
/// `StreamProvider`: no Realtime in scope, the data source is a single
/// one-shot query.
final FutureProvider<List<Product>> catalogProvider =
    FutureProvider<List<Product>>(
      (ref) => ref.watch(catalogRemoteProvider).fetchAll(),
    );

/// Currently selected category filter key, or `null` for "Todos". A single
/// nullable `StateProvider`, matching `orderFilterProvider`'s style — no
/// Notifier needed for one nullable String.
final StateProvider<String?> selectedCategoryKeyProvider =
    StateProvider<String?>((ref) => null);

/// A single category chip: [key] is the normalized (trim + case-fold) grouping
/// key, [label] is the first-seen raw variant.
final class CategoryOption {
  const CategoryOption({required this.key, required this.label});

  final String key;
  final String label;
}

/// Groups [products] by [Product.categoryKey], keeping the first-seen raw
/// label per group, then sorts the result alphabetically by label (the spec
/// pins which label wins, not chip order — alphabetical is deterministic
/// and easier to scan than fetch order).
List<CategoryOption> buildCategoryOptions(List<Product> products) {
  final labelsByKey = <String, String>{};
  for (final product in products) {
    labelsByKey.putIfAbsent(product.categoryKey, () => product.category);
  }
  final options = labelsByKey.entries
      .map((entry) => CategoryOption(key: entry.key, label: entry.value))
      .toList();
  options.sort(
    (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
  );
  return options;
}

/// Derived chip list for [catalogProvider]'s current data — empty while
/// loading or on error.
final Provider<List<CategoryOption>> categoryOptionsProvider =
    Provider<List<CategoryOption>>((ref) {
      final products = ref.watch(catalogProvider).value ?? const <Product>[];
      return buildCategoryOptions(products);
    });

/// The category key actually applied to [visibleProductsProvider], derived
/// from [selectedCategoryKeyProvider]: if the stored selection is no longer
/// present among [categoryOptionsProvider]'s keys (e.g. that category
/// vanished on refresh), this falls through to `null` ("Todos") for this
/// build, without writing back to the `StateProvider` — a state write
/// during a provider's own build is a Riverpod anti-pattern this design
/// explicitly avoids. Also drives which chip [CategoryFilterBar] highlights.
final Provider<String?> effectiveSelectedCategoryKeyProvider =
    Provider<String?>((ref) {
      final selectedKey = ref.watch(selectedCategoryKeyProvider);
      final options = ref.watch(categoryOptionsProvider);
      if (selectedKey == null) return null;
      return options.any((option) => option.key == selectedKey)
          ? selectedKey
          : null;
    });

/// Current text typed into the catalog's search field — raw, un-trimmed
/// (trimming/case-folding happens where it's compared, in
/// [visibleProductsProvider]) so the field's own controller stays the
/// single source of truth for what's displayed.
final StateProvider<String> productSearchQueryProvider =
    StateProvider<String>((ref) => '');

/// [catalogProvider]'s data filtered by [effectiveSelectedCategoryKeyProvider]
/// and, in real time, by [productSearchQueryProvider] (matched against name
/// and SKU, case-insensitive).
final Provider<AsyncValue<List<Product>>> visibleProductsProvider =
    Provider<AsyncValue<List<Product>>>((ref) {
      final catalogAsync = ref.watch(catalogProvider);
      final effectiveKey = ref.watch(effectiveSelectedCategoryKeyProvider);
      final query = ref.watch(productSearchQueryProvider).trim().toLowerCase();
      return catalogAsync.whenData((products) {
        Iterable<Product> result = products;
        if (effectiveKey != null) {
          result = result.where((product) => product.categoryKey == effectiveKey);
        }
        if (query.isNotEmpty) {
          result = result.where(
            (product) =>
                product.name.toLowerCase().contains(query) ||
                product.sku.toLowerCase().contains(query),
          );
        }
        return result.toList(growable: false);
      });
    });
