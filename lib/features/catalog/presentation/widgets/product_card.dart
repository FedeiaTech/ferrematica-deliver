import 'package:flutter/material.dart';

import '../../domain/product.dart';
import 'product_thumbnail.dart';

/// A single dense inventory card. Read-only — no `onTap`, no detail screen
/// in scope. Visual hierarchy is inventory-check, not e-commerce: thumbnail,
/// name, a prominent price, then the stock line, then a small category
/// badge.
class ProductCard extends StatelessWidget {
  const ProductCard({required this.product, super.key});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockColor = product.stock <= 0 ? theme.colorScheme.error : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ProductThumbnail(imageUrl: product.imageUrl),
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              formatPrice(product.price),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              product.isService
                  ? 'Servicio'
                  : '${formatStock(product.stock)} ${product.unit}',
              style: theme.textTheme.bodySmall?.copyWith(color: stockColor),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                product.category,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if ((product.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                product.description!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
