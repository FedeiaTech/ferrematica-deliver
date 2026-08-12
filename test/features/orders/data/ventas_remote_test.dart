import 'package:ferrematica_express/features/orders/data/ventas_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockSupabaseClient client;

  setUp(() {
    client = MockSupabaseClient();
  });

  group('fetchDisponibles', () {
    test('maps rows from the injected disponiblesFetcher into VentaDisponible', () async {
      final remote = SupabaseVentasRemote(
        client,
        disponiblesFetcher: (dias) async => [
          {
            'id': 'venta-1',
            'venta_local_id': 1,
            'fecha': '2026-08-05T10:00:00Z',
            'total': 100.0,
            'estado': 'completada',
            'detalles': <dynamic>[],
          },
        ],
      );

      final ventas = await remote.fetchDisponibles();

      expect(ventas, hasLength(1));
      expect(ventas.single.id, 'venta-1');
    });

    test('forwards the dias argument to the fetcher', () async {
      int? receivedDias;
      final remote = SupabaseVentasRemote(
        client,
        disponiblesFetcher: (dias) async {
          receivedDias = dias;
          return <Map<String, dynamic>>[];
        },
      );

      await remote.fetchDisponibles(dias: 14);

      expect(receivedDias, 14);
    });

    test('defaults dias to 7 when not provided', () async {
      int? receivedDias;
      final remote = SupabaseVentasRemote(
        client,
        disponiblesFetcher: (dias) async {
          receivedDias = dias;
          return <Map<String, dynamic>>[];
        },
      );

      await remote.fetchDisponibles();

      expect(receivedDias, 7);
    });

    test('returns an empty list when no ventas are available', () async {
      final remote = SupabaseVentasRemote(
        client,
        disponiblesFetcher: (dias) async => <Map<String, dynamic>>[],
      );

      final ventas = await remote.fetchDisponibles();

      expect(ventas, isEmpty);
    });
  });

  group('claimVenta', () {
    test('delegates to the injected claimInserter with the given ids', () async {
      String? insertedVentaId;
      String? insertedOrderId;
      String? insertedCreatedBy;
      final remote = SupabaseVentasRemote(
        client,
        claimInserter:
            ({required ventaId, required orderId, required createdBy}) async {
              insertedVentaId = ventaId;
              insertedOrderId = orderId;
              insertedCreatedBy = createdBy;
            },
      );

      await remote.claimVenta(
        ventaId: 'venta-1',
        orderId: 'order-1',
        createdBy: 'dueno-1',
      );

      expect(insertedVentaId, 'venta-1');
      expect(insertedOrderId, 'order-1');
      expect(insertedCreatedBy, 'dueno-1');
    });

    test(
      'throws VentaYaVinculadaException on a 23505 unique violation (double claim)',
      () async {
        final remote = SupabaseVentasRemote(
          client,
          claimInserter: ({required ventaId, required orderId, required createdBy}) async {
            throw const PostgrestException(
              message: 'duplicate key value violates unique constraint',
              code: '23505',
            );
          },
        );

        await expectLater(
          remote.claimVenta(ventaId: 'venta-1', orderId: 'order-1', createdBy: 'dueno-1'),
          throwsA(isA<VentaYaVinculadaException>()),
        );
      },
    );

    test('rethrows any other PostgrestException unchanged (not a 23505)', () async {
      final remote = SupabaseVentasRemote(
        client,
        claimInserter: ({required ventaId, required orderId, required createdBy}) async {
          throw const PostgrestException(message: 'permission denied', code: '42501');
        },
      );

      await expectLater(
        remote.claimVenta(ventaId: 'venta-1', orderId: 'order-1', createdBy: 'dueno-1'),
        throwsA(
          isA<PostgrestException>().having((error) => error.code, 'code', '42501'),
        ),
      );
    });
  });

  group('fetchLinkedVentas', () {
    test('delegates to the injected fetcher with the given orderId', () async {
      String? receivedOrderId;
      final remote = SupabaseVentasRemote(
        client,
        linkedVentasFetcher: (orderId) async {
          receivedOrderId = orderId;
          return [
            LinkedVenta(
              ventaId: 'venta-1',
              ventaLocalId: 1,
              installId: 'install-1',
              fecha: DateTime(2026, 8, 1, 10),
              total: 100.0,
              estado: 'anulada',
            ),
          ];
        },
      );

      final ventas = await remote.fetchLinkedVentas('order-1');

      expect(receivedOrderId, 'order-1');
      expect(ventas, hasLength(1));
      expect(ventas.single.estado, 'anulada');
    });

    test('returns an empty list when the fetcher finds no linked ventas', () async {
      final remote = SupabaseVentasRemote(
        client,
        linkedVentasFetcher: (orderId) async => const [],
      );

      final ventas = await remote.fetchLinkedVentas('order-1');

      expect(ventas, isEmpty);
    });

    test('returns every linked venta when more than one is bundled into the order', () async {
      final remote = SupabaseVentasRemote(
        client,
        linkedVentasFetcher: (orderId) async => [
          LinkedVenta(
            ventaId: 'venta-1',
            ventaLocalId: 1,
            installId: 'install-1',
            fecha: DateTime(2026, 8, 1, 10),
            total: 100.0,
            estado: 'completada',
          ),
          LinkedVenta(
            ventaId: 'venta-2',
            ventaLocalId: 2,
            installId: 'install-1',
            fecha: DateTime(2026, 8, 2, 11),
            total: 200.0,
            estado: 'completada',
          ),
        ],
      );

      final ventas = await remote.fetchLinkedVentas('order-1');

      expect(ventas, hasLength(2));
    });
  });

  group('fetchDetalleVenta', () {
    test('delegates to the injected fetcher with installId and ventaLocalId', () async {
      String? receivedInstallId;
      int? receivedVentaLocalId;
      final remote = SupabaseVentasRemote(
        client,
        detalleVentaFetcher: ({required installId, required ventaLocalId}) async {
          receivedInstallId = installId;
          receivedVentaLocalId = ventaLocalId;
          return <Map<String, dynamic>>[];
        },
      );

      await remote.fetchDetalleVenta(installId: 'install-1', ventaLocalId: 1);

      expect(receivedInstallId, 'install-1');
      expect(receivedVentaLocalId, 1);
    });

    test('maps rows from the injected fetcher into VentaDetalleDisponible', () async {
      final remote = SupabaseVentasRemote(
        client,
        detalleVentaFetcher: ({required installId, required ventaLocalId}) async => [
          {
            'producto_codigo': 'P1',
            'combo_id': null,
            'descripcion': 'Disco de corte',
            'cantidad': 2,
            'precio_unitario': 50.0,
            'subtotal': 100.0,
          },
        ],
      );

      final detalles = await remote.fetchDetalleVenta(installId: 'install-1', ventaLocalId: 1);

      expect(detalles, hasLength(1));
      expect(detalles.single.descripcion, 'Disco de corte');
      expect(detalles.single.subtotal, 100.0);
    });

    test('returns an empty list when there is no detail', () async {
      final remote = SupabaseVentasRemote(
        client,
        detalleVentaFetcher: ({required installId, required ventaLocalId}) async => [],
      );

      final detalles = await remote.fetchDetalleVenta(installId: 'install-1', ventaLocalId: 1);

      expect(detalles, isEmpty);
    });
  });
}
