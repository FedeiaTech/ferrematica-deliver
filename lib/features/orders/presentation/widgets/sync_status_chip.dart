import 'package:flutter/material.dart';

import '../../domain/order.dart';

/// Compact indicator of an order's local↔remote sync state. Hidden entirely
/// once `synced`, so a healthy list stays visually quiet.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({required this.status, super.key});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == SyncStatus.synced) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final isFailed = status == SyncStatus.failed;
    return Chip(
      label: Text(
        isFailed ? 'Error de sincronización' : 'Pendiente de sincronizar',
      ),
      avatar: Icon(isFailed ? Icons.sync_problem : Icons.sync, size: 16),
      backgroundColor: isFailed
          ? colors.errorContainer
          : colors.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: isFailed ? colors.onErrorContainer : colors.onSurfaceVariant,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
