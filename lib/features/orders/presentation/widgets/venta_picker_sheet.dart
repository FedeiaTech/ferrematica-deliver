import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/venta_disponible.dart';

/// Dueño-facing picker listing ventas eligible for the "desde venta" pedido
/// prefill (spec domain `order-prefill-from-venta`) — opened as a modal
/// bottom sheet from `order_form_screen.dart`'s "Usar venta del POS"
/// button, mirroring `assign_cadete_sheet.dart`'s interaction shape.
///
/// Selecting a row only returns the [VentaDisponible] to the caller; it
/// does NOT write `venta_order_links` — that happens only when the dueño
/// confirms the pedido (design decision D4, claim-before-create), never at
/// mere selection time.
///
/// [excludedVentaIds] are ventas already added to the order form in this
/// same session (multi-venta bundling) — filtered out client-side so the
/// dueño can't pick the same venta twice into one pedido. They're still
/// "disponibles" server-side (not yet claimed until submit), so this can't
/// be pushed into the `ventas_disponibles()` RPC itself.
Future<VentaDisponible?> showVentaPickerSheet(
  BuildContext context, {
  Set<String> excludedVentaIds = const <String>{},
}) {
  return showModalBottomSheet<VentaDisponible>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _VentaPickerSheetContent(excludedVentaIds: excludedVentaIds),
  );
}

class _VentaPickerSheetContent extends ConsumerWidget {
  const _VentaPickerSheetContent({required this.excludedVentaIds});

  final Set<String> excludedVentaIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventasAsync = ref.watch(ventasDisponiblesProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Elegí una venta del POS'),
            ),
            Flexible(
              child: ventasAsync.when(
                data: (allVentas) {
                  final ventas = excludedVentaIds.isEmpty
                      ? allVentas
                      : allVentas
                            .where((venta) => !excludedVentaIds.contains(venta.id))
                            .toList(growable: false);
                  if (ventas.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Text('No hay ventas recientes disponibles para vincular.'),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: ventas.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final venta = ventas[index];
                      final lines = venta.detalles
                          .map((detalle) => detalle.productLabel)
                          .join(', ');
                      return ListTile(
                        title: Text(
                          'Venta #${venta.ventaLocalId} — ${_formatFecha(venta.fecha)}',
                        ),
                        subtitle: Text(
                          lines.isEmpty ? 'Sin líneas' : lines,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text('\$${venta.total.toStringAsFixed(2)}'),
                        onTap: () => Navigator.of(context).pop(venta),
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
                  child: Text('No se pudieron cargar las ventas: $error'),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _formatFecha(DateTime fecha) {
    final local = fecha.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}
