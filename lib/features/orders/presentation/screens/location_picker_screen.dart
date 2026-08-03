import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../delivery/data/providers.dart' show locationClientProvider;

/// Full-screen manual location picker — the reliable fallback for when
/// geocoding gets it wrong or can't resolve an address at all (e.g. a
/// street corner without a house number; see `HttpGeocodingClient`'s
/// intersection approximation, which is still just that — an
/// approximation). Tap anywhere on the map to place/move a pin, then
/// confirm. Returns the picked [latlong.LatLng], or `null` if dismissed
/// without confirming.
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({required this.initialCenter, super.key});

  /// Where to center the map on open — the order's existing coordinates
  /// if it has any, otherwise a caller-chosen fallback (e.g. the city's
  /// approximate center).
  final latlong.LatLng initialCenter;

  @override
  ConsumerState<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  late latlong.LatLng _selected;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCenter;
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final location = await ref.read(locationClientProvider).getCurrentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener tu ubicación actual.')),
      );
      return;
    }
    setState(() {
      _selected = latlong.LatLng(location.latitude, location.longitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corregir ubicación'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: const Text('Confirmar'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _selected,
              initialZoom: 16,
              onTap: (tapPosition, point) => setState(() => _selected = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ferrematica.express',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selected,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                  ),
                ],
              ),
              RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
          const Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Tocá el mapa para mover el pin a la ubicación correcta.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _locating ? null : _useCurrentLocation,
        icon: _locating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location),
        label: const Text('Mi ubicación'),
      ),
    );
  }
}
