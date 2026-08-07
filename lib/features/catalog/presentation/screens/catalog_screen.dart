import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/product.dart';
import '../providers.dart';
import '../widgets/category_filter_bar.dart';
import '../widgets/product_card.dart';

/// Dueño-only read-only product catalog tab. Own `Scaffold(body: ...)` only
/// (no AppBar) — matches [DuenoHomeScreen]'s tab contract: each tab keeps
/// its own Scaffold for its own content, the home screen only owns the
/// banner and bottom navigation.
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);

    return Scaffold(
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _CatalogError(
          message: 'No se pudo cargar el catálogo.',
          onRetry: () => ref.invalidate(catalogProvider),
        ),
        data: (_) => const _CatalogBody(),
      ),
    );
  }
}

class _CatalogBody extends ConsumerWidget {
  const _CatalogBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(categoryOptionsProvider);
    final effectiveKey = ref.watch(effectiveSelectedCategoryKeyProvider);
    final visibleAsync = ref.watch(visibleProductsProvider);
    final allProducts = ref.watch(catalogProvider).value ?? const <Product>[];

    Future<void> refresh() {
      ref.invalidate(catalogProvider);
      return ref.read(catalogProvider.future);
    }

    return Column(
      children: [
        if (options.length >= 2)
          CategoryFilterBar(
            options: options,
            selectedKey: effectiveKey,
            onSelected: (key) =>
                ref.read(selectedCategoryKeyProvider.notifier).state = key,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: visibleAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _CatalogError(
                message: 'No se pudo cargar el catálogo.',
                onRetry: () => ref.invalidate(catalogProvider),
              ),
              data: (visible) {
                if (visible.isEmpty) {
                  final isFilteredEmpty =
                      allProducts.isNotEmpty && effectiveKey != null;
                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _CatalogEmpty(
                          filtered: isFilteredEmpty,
                          onShowAll: isFilteredEmpty
                              ? () =>
                                    ref
                                            .read(
                                              selectedCategoryKeyProvider
                                                  .notifier,
                                            )
                                            .state =
                                        null
                              : null,
                        ),
                      ),
                    ],
                  );
                }
                return GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.78,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) =>
                      ProductCard(product: visible[index]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _CatalogEmpty extends StatelessWidget {
  const _CatalogEmpty({required this.filtered, this.onShowAll});

  /// Whether this is the "no products in this category" case, distinct
  /// from "no products at all" (all inactive / empty table).
  final bool filtered;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              filtered
                  ? 'No hay productos en esta categoría.'
                  : 'Todavía no hay productos cargados.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (onShowAll != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onShowAll,
                child: const Text('Ver todos'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
