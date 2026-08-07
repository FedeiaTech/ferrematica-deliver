import 'package:flutter/material.dart';

/// Fixed-size image-or-placeholder slot for a product card. Always occupies
/// the same space whether or not there is an image, so cards never jitter
/// or misalign — null, blank, a broken/404 URL, and a still-loading image
/// all resolve to the same placeholder box.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({required this.imageUrl, this.height = 72, super.key});

  final String? imageUrl;
  final double height;

  bool get _hasImage => (imageUrl ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: _hasImage
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(context),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _placeholder(context);
              },
            )
          : _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
