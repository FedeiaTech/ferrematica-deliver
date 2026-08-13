import 'package:flutter/material.dart';

import '../providers.dart' show CategoryOption;

/// Horizontal chip row: a fixed leading "Todos" chip, then one chip per
/// [options]. Tapping the already-selected chip clears the selection back
/// to "Todos". Rendered only by the caller when `options.length >= 2` — a
/// single-category catalog makes this bar pure noise.
class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({
    required this.options,
    required this.selectedKey,
    required this.onSelected,
    super.key,
  });

  final List<CategoryOption> options;
  final String? selectedKey;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: const Text('Todos'),
              selected: selectedKey == null,
              // Semi-transparent aura on unselected chips so the label
              // stays legible against any custom `BrandBackground` (solid
              // or striped) — matches the stats period selector's chips.
              backgroundColor: selectedKey == null
                  ? null
                  : Colors.white.withValues(alpha: 0.5),
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(option.label),
                selected: selectedKey == option.key,
                backgroundColor: selectedKey == option.key
                    ? null
                    : Colors.white.withValues(alpha: 0.5),
                onSelected: (_) =>
                    onSelected(selectedKey == option.key ? null : option.key),
              ),
            ),
        ],
      ),
    );
  }
}
