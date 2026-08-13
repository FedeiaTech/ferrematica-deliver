import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'background_color_provider.dart';

/// Bottom sheet letting the user pick the app's background from the brand
/// palette (or "Sistema" to clear the override). Opened from the account
/// menu — see `home_shell_helpers.dart`.
void showBackgroundColorPicker(BuildContext context, WidgetRef ref) {
  final current = ref.read(backgroundColorProvider);
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Color de fondo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final option in BrandBackground.values)
                  _ColorSwatch(
                    option: option,
                    selected: option == current,
                    onTap: () {
                      ref.read(backgroundColorProvider.notifier).select(option);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.option, required this.selected, required this.onTap});

  final BrandBackground option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final swatchColor = option.color ?? Theme.of(context).colorScheme.surface;
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outlineVariant;
    // Darker swatches (rojoOscuro/aceroOscuro/naranja) wash out a dark
    // checkmark — flip to white when the color's own luminance is low
    // enough that it'd otherwise disappear.
    final checkColor = swatchColor.computeLuminance() < 0.5
        ? Colors.white
        : Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: selected ? 3 : 1),
              ),
              child: ClipOval(
                child: Stack(
                  alignment: Alignment.center,
                  // Without `expand`, a loose `Stack` gives non-positioned
                  // children their OWN intrinsic size — a childless
                  // `ColoredBox` has none, so it collapses to zero and
                  // paints nothing.
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: swatchColor),
                    if (selected) Icon(Icons.check, color: checkColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              option.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
