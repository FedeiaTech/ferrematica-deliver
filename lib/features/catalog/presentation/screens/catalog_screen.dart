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
    final hasSearchQuery = ref.watch(productSearchQueryProvider).trim().isNotEmpty;

    Future<void> refresh() {
      ref.invalidate(catalogProvider);
      return ref.read(catalogProvider.future);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: _ProductSearchField(
            onChanged: (value) =>
                ref.read(productSearchQueryProvider.notifier).state = value,
          ),
        ),
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
                      allProducts.isNotEmpty &&
                      (effectiveKey != null || hasSearchQuery);
                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _CatalogEmpty(
                          filtered: isFilteredEmpty,
                          onShowAll: isFilteredEmpty
                              ? () {
                                  ref
                                          .read(selectedCategoryKeyProvider.notifier)
                                          .state =
                                      null;
                                  ref.read(productSearchQueryProvider.notifier).state =
                                      '';
                                }
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
                  ? 'No hay productos que coincidan con el filtro.'
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

/// Real-time search field for the catalog grid, filtering by name/SKU as
/// the user types (see [productSearchQueryProvider] and
/// [visibleProductsProvider]). A `ConsumerStatefulWidget` — not a plain
/// `TextField` fed straight from the provider — so the controller can be
/// reset externally (e.g. the empty state's "Ver todos" button clearing
/// [productSearchQueryProvider]) without fighting the user's own typing.
class _ProductSearchField extends ConsumerStatefulWidget {
  const _ProductSearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  ConsumerState<_ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends ConsumerState<_ProductSearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the field in sync when the query is cleared elsewhere (e.g. the
    // "Ver todos" button) without clobbering the caret mid-typing — only
    // overwrite when the provider's value actually diverges from what's
    // shown.
    final query = ref.watch(productSearchQueryProvider);
    if (query != _controller.text) {
      _controller.value = _controller.value.copyWith(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: 'Buscar productos...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Limpiar búsqueda',
                onPressed: () => widget.onChanged(''),
              ),
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
