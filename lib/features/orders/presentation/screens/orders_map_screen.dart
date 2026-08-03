import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../domain/order.dart';
import '../providers.dart';

/// Dueño-facing overview map: one destination pin per order that is
/// currently out for delivery (`asignado` or `en_camino`) and has resolved
/// coordinates. Destination-only — no live cadete position (that needs a
/// `cadete_locations` table + background reporting, explicitly out of
/// scope for this slice; see the "pedidos" proposal's Out of Scope list).
///
/// Reuses the same `flutter_map` + OSM tile setup as
/// `NavigationMapScreen` — no API key, no billing card.
class OrdersMapScreen extends ConsumerWidget {
  const OrdersMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de pedidos')),
      body: ordersAsync.when(
        data: (orders) {
          final activeOrders = orders
              .where(
                (order) =>
                    (order.status == OrderStatus.asignado ||
                        order.status == OrderStatus.enCamino) &&
                    order.latitude != null &&
                    order.longitude != null,
              )
              .toList(growable: false);

          if (activeOrders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay pedidos asignados con ubicación para mostrar.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final points = activeOrders
              .map((order) => latlong.LatLng(order.latitude!, order.longitude!))
              .toList(growable: false);
          final center = _centerOf(points);
          final markers = [
            for (final order in activeOrders)
              Marker(
                point: latlong.LatLng(order.latitude!, order.longitude!),
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => context.push('/orders/${order.id}'),
                  child: Icon(
                    Icons.location_pin,
                    color: order.status == OrderStatus.enCamino
                        ? Colors.deepPurple
                        : Colors.blue.shade700,
                    size: 40,
                  ),
                ),
              ),
          ];

          return FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ferrematica.express',
              ),
              MarkerLayer(markers: markers),
              // Required by OpenStreetMap's tile usage policy — see
              // https://operations.osmfoundation.org/policies/tiles/.
              RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error al cargar pedidos: $error')),
      ),
    );
  }

  /// Simple centroid — good enough to frame a handful of delivery pins on
  /// one screen, not a proper bounding-box fit.
  latlong.LatLng _centerOf(List<latlong.LatLng> points) {
    final avgLat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final avgLng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return latlong.LatLng(avgLat, avgLng);
  }
}
