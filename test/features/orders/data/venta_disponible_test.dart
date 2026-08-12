import 'package:ferrematica_express/features/orders/data/venta_disponible.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VentaDisponible.fromRow', () {
    test('maps a full row incl. embedded detalles', () {
      final venta = VentaDisponible.fromRow({
        'id': 'venta-uuid-1',
        'venta_local_id': 42,
        'fecha': '2026-08-05T10:00:00Z',
        'total': 1500.5,
        'estado': 'completada',
        'detalles': [
          {
            'producto_codigo': 'SKU-1',
            'combo_id': null,
            'descripcion': 'Tornillo 3/4',
            'cantidad': 10,
            'precio_unitario': 100.0,
            'subtotal': 1000.0,
          },
        ],
      });

      expect(venta.id, 'venta-uuid-1');
      expect(venta.ventaLocalId, 42);
      expect(venta.fecha, DateTime.parse('2026-08-05T10:00:00Z'));
      expect(venta.total, 1500.5);
      expect(venta.estado, 'completada');
      expect(venta.detalles, hasLength(1));
      expect(venta.detalles.single.descripcion, 'Tornillo 3/4');
    });

    test('maps an empty detalles list', () {
      final venta = VentaDisponible.fromRow({
        'id': 'venta-uuid-2',
        'venta_local_id': 1,
        'fecha': '2026-08-05T10:00:00Z',
        'total': 0,
        'estado': 'completada',
        'detalles': <dynamic>[],
      });

      expect(venta.detalles, isEmpty);
    });

    test('defaults detalles to empty when the key is null', () {
      final venta = VentaDisponible.fromRow({
        'id': 'venta-uuid-3',
        'venta_local_id': 2,
        'fecha': '2026-08-05T10:00:00Z',
        'total': 0,
        'estado': 'completada',
        'detalles': null,
      });

      expect(venta.detalles, isEmpty);
    });
  });

  group('VentaDetalleDisponible — fractional quantity label (D6)', () {
    test('whole cantidad: productLabel equals descripcion, not fractional', () {
      final detalle = VentaDetalleDisponible.fromRow({
        'producto_codigo': 'SKU-1',
        'combo_id': null,
        'descripcion': 'Tornillo 3/4',
        'cantidad': 10,
        'precio_unitario': 100.0,
        'subtotal': 1000.0,
      });

      expect(detalle.isFractional, isFalse);
      expect(detalle.quantityForOrder, 10);
      expect(detalle.productLabel, 'Tornillo 3/4');
    });

    test('fractional cantidad: productLabel appends the exact figure', () {
      final detalle = VentaDetalleDisponible.fromRow({
        'producto_codigo': 'SKU-2',
        'combo_id': null,
        'descripcion': 'Cable 2x1,5',
        'cantidad': 3.5,
        'precio_unitario': 200.0,
        'subtotal': 700.0,
      });

      expect(detalle.isFractional, isTrue);
      expect(detalle.quantityForOrder, 4); // rounds
      expect(detalle.productLabel, 'Cable 2x1,5 (x3.5)');
    });

    test('fractional cantidad with three decimals is preserved without trailing zeros', () {
      final detalle = VentaDetalleDisponible.fromRow({
        'producto_codigo': 'SKU-3',
        'combo_id': null,
        'descripcion': 'Pintura',
        'cantidad': 2.125,
        'precio_unitario': 10.0,
        'subtotal': 21.25,
      });

      expect(detalle.productLabel, 'Pintura (x2.125)');
    });

    test('combo_id line: producto_codigo is null, combo_id is set', () {
      final detalle = VentaDetalleDisponible.fromRow({
        'producto_codigo': null,
        'combo_id': 7,
        'descripcion': 'Combo Ferretero',
        'cantidad': 1,
        'precio_unitario': 5000.0,
        'subtotal': 5000.0,
      });

      expect(detalle.productoCodigo, isNull);
      expect(detalle.comboId, 7);
    });
  });
}
