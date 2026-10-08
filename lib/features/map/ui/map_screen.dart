import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/providers.dart';

/// Centre de l'Alsace : point de départ avant d'avoir la position GPS.
const _defaultCenter = LatLng(48.20, 7.35);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _newSpot(LatLng at) =>
      context.push('/map/spot?lat=${at.latitude}&lon=${at.longitude}');

  @override
  Widget build(BuildContext context) {
    final spots = ref.watch(spotsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes coins'),
        actions: [
          IconButton(
            tooltip: 'Liste des coins',
            icon: const Icon(Icons.list),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => _SpotList(
                onSelect: (lat, lon) {
                  Navigator.pop(context);
                  _controller.move(LatLng(lat, lon), 14);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newSpot(_controller.camera.center),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Nouveau coin'),
      ),
      body: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: _defaultCenter,
          initialZoom: 9,
          onLongPress: (_, point) => _newSpot(point),
        ),
        children: [
          // PROVISOIRE : les tuiles publiques d'OpenStreetMap ne doivent servir
          // qu'au développement. Remplacer par des tuiles hors ligne avant toute
          // diffusion (cahier des charges §10.2).
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'fr.mycelium.mycelium',
          ),
          MarkerLayer(
            markers: [
              for (final spot in spots)
                Marker(
                  point: LatLng(spot.latitude, spot.longitude),
                  width: 56,
                  height: 56,
                  child: GestureDetector(
                    onTap: () => context.push('/map/spot?id=${spot.id}'),
                    child: Tooltip(
                      message: spot.name,
                      child: Icon(
                        spot.isFavorite ? Icons.star : Icons.location_on,
                        size: 44,
                        color: spot.isFavorite
                            ? Colors.amber.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('© contributeurs OpenStreetMap')],
          ),
        ],
      ),
    );
  }
}

class _SpotList extends ConsumerWidget {
  const _SpotList({required this.onSelect});

  final void Function(double lat, double lon) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spots = ref.watch(spotsProvider).value ?? const [];
    if (spots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Aucun coin enregistré. Appuyez longuement sur la carte ou sur '
          '« Nouveau coin » pour en ajouter un.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        for (final s in spots)
          ListTile(
            leading: Icon(s.isFavorite ? Icons.star : Icons.location_on),
            title: Text(s.name),
            subtitle: Text(s.forestType ?? ''),
            onTap: () => onSelect(s.latitude, s.longitude),
          ),
      ],
    );
  }
}
