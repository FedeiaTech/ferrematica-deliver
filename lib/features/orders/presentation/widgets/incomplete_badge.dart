import 'package:flutter/material.dart';

/// Small non-blocking flag rendered on an order card/detail view when
/// [Order.isIncomplete] is true. Purely informational — never disables any
/// action, per spec's "MUST visually flag ... without blocking any action".
class IncompleteBadge extends StatelessWidget {
  const IncompleteBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Chip(
      label: const Text('Sin monto cargado'),
      avatar: const Icon(Icons.info_outline, size: 16),
      backgroundColor: colors.secondaryContainer,
      labelStyle: TextStyle(color: colors.onSecondaryContainer),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
