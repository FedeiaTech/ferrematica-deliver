import 'package:flutter/material.dart';

import '../../domain/order.dart';

/// Plain (non-interactive) indicator of an order's local↔remote sync
/// state — just an icon and text, no button/chip background, since there
/// is no tap action behind it. Hidden entirely once `synced`, so a healthy
/// order shows nothing at all here.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({required this.status, super.key});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == SyncStatus.synced) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final isFailed = status == SyncStatus.failed;
    final color = isFailed ? colors.error : colors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isFailed ? Icons.sync_problem : Icons.sync, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          isFailed ? 'Error de sincronización' : 'Pendiente de sincronizar',
          style: TextStyle(color: color),
        ),
      ],
    );
  }
}
