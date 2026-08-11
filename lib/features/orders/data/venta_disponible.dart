/// Pure-Dart read models for the `ventas_disponibles()` RPC result — the
/// "desde venta" pedido picker's data source (spec domain
/// `order-prefill-from-venta`). No Isar or Supabase imports here, mirroring
/// `domain/order.dart`'s separation: [VentasRemote] (in `ventas_remote.dart`)
/// maps the wire jsonb into these types.
library;

/// A single sale eligible for the "desde venta" picker: `estado ==
/// 'completada'`, within the RPC's `p_dias` window, and not yet linked in
/// `venta_order_links` (the server-side anti-join in `ventas_disponibles()`,
/// design decision D7).
final class VentaDisponible {
  const VentaDisponible({
    required this.id,
    required this.ventaLocalId,
    required this.fecha,
    required this.total,
    required this.estado,
    this.detalles = const <VentaDetalleDisponible>[],
  });

  /// Server-generated `ventas.id` (uuid) — this, not [ventaLocalId], is what
  /// [VentasRemote.claimVenta] writes into `venta_order_links.venta_id`.
  final String id;

  /// The POS-local autoincrement id, kept only for display/debugging — not
  /// globally unique across installs (design decision D1).
  final int ventaLocalId;
  final DateTime fecha;
  final double total;
  final String estado;
  final List<VentaDetalleDisponible> detalles;

  /// Builds a [VentaDisponible] from one row of the `ventas_disponibles()`
  /// RPC response (already JSON-decoded by `supabase_flutter`).
  factory VentaDisponible.fromRow(Map<String, dynamic> row) {
    final rawDetalles = (row['detalles'] as List<dynamic>?) ?? const <dynamic>[];
    return VentaDisponible(
      id: row['id'] as String,
      ventaLocalId: row['venta_local_id'] as int,
      fecha: DateTime.parse(row['fecha'] as String),
      total: (row['total'] as num).toDouble(),
      estado: row['estado'] as String,
      detalles: rawDetalles
          .map(
            (dynamic detalle) =>
                VentaDetalleDisponible.fromRow(detalle as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

/// One line item of a [VentaDisponible], embedded as jsonb by the RPC (see
/// `detalle_ventas` in `0011_ventas_mirror.sql`).
final class VentaDetalleDisponible {
  const VentaDetalleDisponible({
    this.productoCodigo,
    this.comboId,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  final String? productoCodigo;
  final int? comboId;
  final String descripcion;

  /// `numeric(12,3)` on the wire — fractional kg/lt sales are valid (same
  /// rationale as `detalle_ventas.cantidad`'s column comment). `OrderItem.
  /// quantity` is an `int`, so callers prefilling from this value use
  /// [quantityForOrder] (rounded) and [productLabel] (which keeps the exact
  /// figure visible when it doesn't round cleanly) — design decision D6.
  final double cantidad;
  final double precioUnitario;
  final double subtotal;

  factory VentaDetalleDisponible.fromRow(Map<String, dynamic> row) =>
      VentaDetalleDisponible(
        productoCodigo: row['producto_codigo'] as String?,
        comboId: row['combo_id'] as int?,
        descripcion: row['descripcion'] as String,
        cantidad: (row['cantidad'] as num).toDouble(),
        precioUnitario: (row['precio_unitario'] as num).toDouble(),
        subtotal: (row['subtotal'] as num).toDouble(),
      );

  /// `true` when [cantidad] does not round cleanly to a whole unit — the
  /// case `OrderItem.quantity` (an `int`) cannot represent exactly.
  bool get isFractional => cantidad != cantidad.roundToDouble();

  /// The value to prefill into `OrderItem.quantity`. Rounds [cantidad] —
  /// see [productLabel] for how the exact figure is preserved when
  /// [isFractional] is `true`.
  int get quantityForOrder => cantidad.round();

  /// The value to prefill into `OrderItem.productName`. When [isFractional],
  /// appends the exact [cantidad] so the fraction isn't silently lost to
  /// [quantityForOrder]'s rounding — the dueño sees it and can correct the
  /// prefilled quantity/notes before confirming (design decision D6).
  String get productLabel =>
      isFractional ? '$descripcion (x${_formatCantidad(cantidad)})' : descripcion;

  static String _formatCantidad(double value) {
    var text = value.toStringAsFixed(3);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    if (text.endsWith('.')) {
      text = '${text}0';
    }
    return text;
  }
}
