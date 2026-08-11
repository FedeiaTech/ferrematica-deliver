import 'package:supabase_flutter/supabase_flutter.dart';

import 'venta_disponible.dart';

/// One row of `venta_order_links` joined against `ventas` — an order can
/// have more than one when the dueño bundles several POS sales into a
/// single delivery (`_pickVenta` in order_form_screen.dart is additive
/// since the multi-venta change, not a single-slot picker).
final class LinkedVenta {
  const LinkedVenta({
    required this.ventaId,
    required this.ventaLocalId,
    required this.installId,
    required this.fecha,
    required this.total,
    required this.estado,
  });

  final String ventaId;
  final int ventaLocalId;

  /// Needed (together with [ventaLocalId]) to look up this venta's product
  /// detail via [VentasRemote.fetchDetalleVenta] — `detalle_ventas` has no
  /// direct `venta_id` uuid, only the composite FK
  /// `(install_id, venta_local_id)` back to `ventas` (see
  /// `0011_ventas_mirror.sql`).
  final String installId;
  final DateTime fecha;
  final double total;
  final String estado;
}

/// Port over the read-only `ventas_disponibles()` RPC and the write-only
/// `venta_order_links` claim (spec domains `venta-order-link` and
/// `order-prefill-from-venta`). Wraps only the vendor [SupabaseClient] calls
/// this feature needs, mirroring `OrdersRemote`'s port-not-vendor precedent
/// so callers mock this interface with `mocktail` instead of the vendor SDK.
abstract interface class VentasRemote {
  /// Lists ventas eligible for the "desde venta" picker: `estado ==
  /// 'completada'`, within the last [dias] days, and not yet linked in
  /// `venta_order_links` — all enforced server-side by the RPC (design
  /// decision D7).
  Future<List<VentaDisponible>> fetchDisponibles({int dias = 7});

  /// Inserts the venta↔pedido link. MUST be called only when the dueño
  /// confirms the pedido (never at mere selection time — spec scenario
  /// "Cancelar antes de confirmar no crea link"), and BEFORE the order is
  /// saved locally (design decision D4 — claim-before-create). [orderId] is
  /// the client-generated `Order.id`; there is no FK to `orders` server-side
  /// since the order row may not exist in Supabase yet.
  ///
  /// Throws [VentaYaVinculadaException] when [ventaId] was already claimed
  /// by another device/session (a `23505` unique violation on
  /// `venta_order_links.venta_id`) — the UNIQUE constraint IS the
  /// anti-double-use mutex, not application-level locking.
  Future<void> claimVenta({
    required String ventaId,
    required String orderId,
    required String createdBy,
  });

  /// Returns every venta linked to [orderId] via `venta_order_links` —
  /// empty when this order has no linked venta, one entry for the common
  /// case, or several when multiple POS sales were bundled into this
  /// delivery. The link itself is never broken/deleted once written
  /// (design decision D8), so this is how `order_detail_screen.dart` learns
  /// that a previously-linked venta was later anulada in the POS and
  /// surfaces a warning to the dueño instead of failing silently.
  Future<List<LinkedVenta>> fetchLinkedVentas(String orderId);

  /// Fetches the product line items of one already-linked venta. Callers
  /// (`order_detail_screen.dart`) invoke this lazily — only when a given
  /// venta's expansion tile is opened for the first time, not eagerly for
  /// every [LinkedVenta] up front — since `detalle_ventas` has no direct
  /// `venta_id` uuid, the lookup is keyed by the composite
  /// `(installId, ventaLocalId)` from [LinkedVenta] instead.
  Future<List<VentaDetalleDisponible>> fetchDetalleVenta({
    required String installId,
    required int ventaLocalId,
  });
}

/// Raised by [VentasRemote.claimVenta] when [ventaId] is already linked to
/// another order. Callers surface this as "Esa venta ya fue usada en otro
/// pedido" and MUST NOT create the local order (design decision D4).
final class VentaYaVinculadaException implements Exception {
  const VentaYaVinculadaException(this.ventaId);

  final String ventaId;

  @override
  String toString() => 'Esa venta ya fue usada en otro pedido';
}

/// [VentasRemote] backed by the real `supabase_flutter` client.
///
/// Like `SupabaseCadeteDirectory`, takes injectable [disponiblesFetcher]/
/// [claimInserter] functions so tests never exercise the real Postgrest
/// fluent builder / `rpc()` chain (`mocktail` cannot cleanly stub it). The
/// defaults are what production wiring uses.
class SupabaseVentasRemote implements VentasRemote {
  SupabaseVentasRemote(
    this._client, {
    Future<List<Map<String, dynamic>>> Function(int dias)? disponiblesFetcher,
    Future<void> Function({
      required String ventaId,
      required String orderId,
      required String createdBy,
    })?
    claimInserter,
    Future<List<LinkedVenta>> Function(String orderId)? linkedVentasFetcher,
    Future<List<Map<String, dynamic>>> Function({
      required String installId,
      required int ventaLocalId,
    })?
    detalleVentaFetcher,
  }) {
    _disponiblesFetcher = disponiblesFetcher ?? _fetchDisponiblesRows;
    _claimInserter = claimInserter ?? _insertClaim;
    _linkedVentasFetcher = linkedVentasFetcher ?? _fetchLinkedVentas;
    _detalleVentaFetcher = detalleVentaFetcher ?? _fetchDetalleVentaRows;
  }

  final SupabaseClient _client;
  late final Future<List<Map<String, dynamic>>> Function(int dias) _disponiblesFetcher;
  late final Future<void> Function({
    required String ventaId,
    required String orderId,
    required String createdBy,
  })
  _claimInserter;
  late final Future<List<LinkedVenta>> Function(String orderId) _linkedVentasFetcher;
  late final Future<List<Map<String, dynamic>>> Function({
    required String installId,
    required int ventaLocalId,
  })
  _detalleVentaFetcher;

  static const String _rpcName = 'ventas_disponibles';
  static const String _linksTable = 'venta_order_links';
  static const String _ventasTable = 'ventas';
  static const String _detalleVentasTable = 'detalle_ventas';

  @override
  Future<List<VentaDisponible>> fetchDisponibles({int dias = 7}) async {
    final rows = await _disponiblesFetcher(dias);
    return rows.map(VentaDisponible.fromRow).toList(growable: false);
  }

  @override
  Future<void> claimVenta({
    required String ventaId,
    required String orderId,
    required String createdBy,
  }) async {
    try {
      await _claimInserter(ventaId: ventaId, orderId: orderId, createdBy: createdBy);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw VentaYaVinculadaException(ventaId);
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDisponiblesRows(int dias) async {
    final rows = await _client.rpc(_rpcName, params: <String, dynamic>{'p_dias': dias});
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> _insertClaim({
    required String ventaId,
    required String orderId,
    required String createdBy,
  }) async {
    await _client.from(_linksTable).insert(<String, dynamic>{
      'venta_id': ventaId,
      'order_id': orderId,
      'created_by': createdBy,
    });
  }

  @override
  Future<List<LinkedVenta>> fetchLinkedVentas(String orderId) => _linkedVentasFetcher(orderId);

  /// Two round trips (links, then ventas), both permitted by the dueño's
  /// own RLS select policies — no RPC needed, unlike [fetchDisponibles]'s
  /// anti-join. An order can have more than one link (multi-venta bundling
  /// in `_pickVenta`), so this returns every match instead of assuming one.
  Future<List<LinkedVenta>> _fetchLinkedVentas(String orderId) async {
    final links = await _client
        .from(_linksTable)
        .select('venta_id')
        .eq('order_id', orderId);
    if (links.isEmpty) return const <LinkedVenta>[];
    final ventaIds = links.map((row) => row['venta_id'] as String).toList(growable: false);
    final ventas = await _client
        .from(_ventasTable)
        .select('id, venta_local_id, install_id, fecha, total, estado')
        .inFilter('id', ventaIds);
    return ventas
        .map(
          (row) => LinkedVenta(
            ventaId: row['id'] as String,
            ventaLocalId: row['venta_local_id'] as int,
            installId: row['install_id'] as String,
            fecha: DateTime.parse(row['fecha'] as String),
            total: (row['total'] as num).toDouble(),
            estado: row['estado'] as String,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<VentaDetalleDisponible>> fetchDetalleVenta({
    required String installId,
    required int ventaLocalId,
  }) async {
    final rows = await _detalleVentaFetcher(installId: installId, ventaLocalId: ventaLocalId);
    return rows.map(VentaDetalleDisponible.fromRow).toList(growable: false);
  }

  /// `detalle_ventas` has no `venta_id` uuid — only the composite FK
  /// `(install_id, venta_local_id)` back to `ventas` (design decision D2,
  /// see `0011_ventas_mirror.sql`), so both are required to scope this
  /// select. Covered by the existing `detalle_ventas_select_owner` RLS
  /// policy — same access the RPC in [fetchDisponibles] relies on.
  Future<List<Map<String, dynamic>>> _fetchDetalleVentaRows({
    required String installId,
    required int ventaLocalId,
  }) async {
    final rows = await _client
        .from(_detalleVentasTable)
        .select('producto_codigo, combo_id, descripcion, cantidad, precio_unitario, subtotal')
        .eq('install_id', installId)
        .eq('venta_local_id', ventaLocalId);
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
