import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/cadete_directory.dart';
import '../../../auth/presentation/providers.dart' show cadeteListProvider, sessionProvider;

/// Dueño-facing picker listing every active `rol = 'cadete'` account
/// (`profiles_select_cadetes` RLS policy, migration 0003), opened as a
/// modal bottom sheet from `OrderDetailScreen`'s "Asignar cadete" action —
/// same interaction shape as the existing "Marcar entregado" sheet.
///
/// Returns the selected [CadeteProfile.id], or `null` if the sheet was
/// dismissed without a selection.
Future<String?> showAssignCadeteSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const _AssignCadeteSheetContent(),
  );
}

class _AssignCadeteSheetContent extends ConsumerWidget {
  const _AssignCadeteSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cadetesAsync = ref.watch(cadeteListProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('¿A qué cadete asignás este pedido?'),
            ),
            Flexible(
              child: cadetesAsync.when(
                data: (cadetes) {
                  if (cadetes.isEmpty) {
                    final session = ref.watch(sessionProvider).value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('Todavía no hay cadetes disponibles.'),
                          ),
                          if (session != null)
                            ListTile(
                              leading: const Icon(Icons.storefront_outlined),
                              title: const Text('Base'),
                              onTap: () => Navigator.of(context).pop(session.userId),
                            ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: cadetes.length,
                    itemBuilder: (context, index) {
                      final cadete = cadetes[index];
                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(cadete.displayName),
                        onTap: () => Navigator.of(context).pop(cadete.id),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Text('No se pudo cargar la lista de cadetes: $error'),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
