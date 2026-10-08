import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../geo.dart';
import '../location.dart';
import '../map_config.dart';
import '../navigation.dart';
import 'map_widgets.dart';

/// Centre de l'Alsace : point de départ avant d'avoir la position GPS.
const _defaultCenter = LatLng(48.20, 7.35);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  final _controller = MapController();
  final _sheet = DraggableScrollableController();
  final _extent = ValueNotifier<double>(.46);
  late final AnimationController _anim;

  bool _mapReady = false;
  bool _centeredOnUser = false;
  LatLng _from = _defaultCenter;
  LatLng _to = _defaultCenter;
  double _zoomFrom = 9;
  double _zoomTo = 9;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..addListener(_onAnimTick);
    _sheet.addListener(() {
      if (_sheet.isAttached) _extent.value = _sheet.size;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _sheet.dispose();
    _extent.dispose();
    _controller.dispose();
    super.dispose();
  }

  // --- Caméra ---------------------------------------------------------------

  void _onAnimTick() {
    final t = Curves.easeInOutCubic.transform(_anim.value);
    _controller.move(
      LatLng(
        _from.latitude + (_to.latitude - _from.latitude) * t,
        _from.longitude + (_to.longitude - _from.longitude) * t,
      ),
      _zoomFrom + (_zoomTo - _zoomFrom) * t,
    );
  }

  void _animateTo(LatLng dest, double zoom) {
    if (!_mapReady) return;
    _from = _controller.camera.center;
    _zoomFrom = _controller.camera.zoom;
    _to = dest;
    _zoomTo = zoom;
    _anim.forward(from: 0);
  }

  void _fitRoute(NavState nav) {
    final route = nav.route;
    if (!_mapReady || route == null) return;
    final user = ref.read(locationProvider).value?.latLng;
    final pts = [...route.points, ?user];
    final size = MediaQuery.sizeOf(context);
    final camera = CameraFit.coordinates(
      coordinates: pts,
      padding: EdgeInsets.fromLTRB(48, 190, 48, size.height * .48),
      maxZoom: 17,
    ).fit(_controller.camera);
    _animateTo(camera.center, camera.zoom);
  }

  void _recenter() {
    final here = ref.read(locationProvider).value?.latLng;
    if (here == null) {
      ref.invalidate(locationProvider);
      return;
    }
    _animateTo(here, math.max(_controller.camera.zoom, 16));
  }

  // --- Actions ----------------------------------------------------------------

  LatLng get _referencePoint =>
      ref.read(locationProvider).value?.latLng ?? _controller.camera.center;

  void _newSpotHere() {
    final p = _referencePoint;
    context.push('/map/spot?lat=${p.latitude}&lon=${p.longitude}');
  }

  void _startNavigation(Spot spot) {
    ref.read(navigationProvider.notifier).start(spot);
    if (_sheet.isAttached) {
      _sheet.animateTo(.46, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
    if (ref.read(locationProvider).value?.latLng == null) {
      _animateTo(LatLng(spot.latitude, spot.longitude), 16);
    }
  }

  Future<void> _addDemoSpots() async {
    final base = _referencePoint;
    final cosLat = math.cos(base.latitudeInRad);
    LatLng shift(double north, double east) => LatLng(
          base.latitude + north / 110540,
          base.longitude + east / (111320 * cosLat),
        );
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final demo = [
      ('Coin des cèpes (démo)', 'Conifères', shift(320, 260), true),
      ('Clairière aux girolles (démo)', 'Feuillus', shift(-480, 380), false),
      ('Lisière des morilles (démo)', 'Mixte', shift(140, -720), false),
    ];
    for (final (name, forest, point, fav) in demo) {
      await db.upsertSpot(SpotsCompanion.insert(
        id: const Uuid().v4(),
        name: name,
        latitude: point.latitude,
        longitude: point.longitude,
        forestType: Value(forest),
        isFavorite: Value(fav),
        createdAt: now,
        updatedAt: now,
      ));
    }
    _animateTo(base, 15);
  }

  // --- Interface ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<LocationState>>(locationProvider, (prev, next) {
      final here = next.value?.latLng;
      if (here != null && !_centeredOnUser && !ref.read(navigationProvider).active) {
        _centeredOnUser = true;
        _animateTo(here, 16);
      }
    });
    ref.listen<NavState>(navigationProvider, (prev, next) {
      if (next.route != null && prev?.routeVersion != next.routeVersion) {
        _fitRoute(next);
      }
    });

    final spots = ref.watch(spotsProvider).value ?? const <Spot>[];
    final location = ref.watch(locationProvider);
    final nav = ref.watch(navigationProvider);
    final here = location.value?.latLng;

    final entries = [
      for (final s in spots)
        (spot: s, distance: here == null ? null : metersBetween(here, LatLng(s.latitude, s.longitude))),
    ];
    if (here != null) {
      entries.sort((a, b) => a.distance!.compareTo(b.distance!));
    }

    final panelChildren = _panelChildren(entries, nav);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes coins'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(
              here == null ? Icons.location_searching : Icons.my_location,
              color: here == null ? Palette.sage : Palette.chanterelle,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final map = _buildMap(spots, nav, location, wide);
          if (wide) {
            return Row(
              children: [
                SizedBox(
                  width: 380,
                  child: ColoredBox(
                    color: Palette.cream,
                    child: ListView(
                      padding: const EdgeInsets.only(top: 12, bottom: 24),
                      children: panelChildren,
                    ),
                  ),
                ),
                Expanded(child: map),
              ],
            );
          }
          return Stack(
            children: [
              map,
              DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: .46,
                minChildSize: .13,
                maxChildSize: .88,
                snap: true,
                snapSizes: const [.13, .46, .88],
                builder: (context, scrollController) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: Palette.cream,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .25),
                        blurRadius: 14,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Palette.bark.withValues(alpha: .35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      ...panelChildren,
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _panelChildren(
    List<({Spot spot, double? distance})> entries,
    NavState nav,
  ) {
    final theme = Theme.of(context);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                nav.active ? 'Guidage en cours' : 'Mes coins (${entries.length})',
                style: theme.textTheme.titleLarge,
              ),
            ),
            if (!nav.active)
              TextButton.icon(
                onPressed: _newSpotHere,
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Ajouter'),
              ),
          ],
        ),
      ),
      if (nav.active)
        NavigationSummary(
          nav: nav,
          onStop: () => ref.read(navigationProvider.notifier).stop(),
          onEdit: () => context.push('/map/spot?id=${nav.target!.id}'),
        ),
      if (entries.isEmpty)
        NoSpots(onAddHere: _newSpotHere, onDemo: _addDemoSpots)
      else ...[
        if (nav.active)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text('Autres coins', style: theme.textTheme.titleMedium),
          ),
        for (var i = 0; i < entries.length; i++)
          if (nav.target?.id != entries[i].spot.id)
            SpotTile(
              spot: entries[i].spot,
              distance: entries[i].distance,
              selected: false,
              onTap: () => _startNavigation(entries[i].spot),
              onEdit: () => context.push('/map/spot?id=${entries[i].spot.id}'),
            ).animate().fadeIn(delay: (i.clamp(0, 8) * 50).ms, duration: 300.ms)
              .slideX(begin: .12, end: 0, delay: (i.clamp(0, 8) * 50).ms),
      ],
    ];
  }

  Widget _buildMap(
    List<Spot> spots,
    NavState nav,
    AsyncValue<LocationState> location,
    bool wide,
  ) {
    final here = location.value?.latLng;
    final accuracy = location.value?.position?.accuracy;
    final route = nav.route;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _defaultCenter,
            initialZoom: 9,
            minZoom: 3,
            maxZoom: 19,
            onMapReady: () {
              _mapReady = true;
              final here = ref.read(locationProvider).value?.latLng;
              if (here != null && !_centeredOnUser) {
                _centeredOnUser = true;
                _animateTo(here, 16);
              }
            },
            onLongPress: (_, point) =>
                context.push('/map/spot?lat=${point.latitude}&lon=${point.longitude}'),
          ),
          children: [
            // PROVISOIRE : les tuiles publiques d'OpenStreetMap ne doivent servir
            // qu'au développement. Remplacer par des tuiles hors ligne avant toute
            // diffusion (cahier des charges §10.2).
            if (ref.watch(tilesEnabledProvider))
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'fr.mycelium.mycelium',
              // Teinte chaude « papier » pour s'accorder au reste de l'application.
              tileBuilder: (context, tile, _) => ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  .92, .10, .04, 0, 6,
                  .04, .96, .04, 0, 4,
                  .02, .08, .78, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: tile,
              ),
            ),
            if (route != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: route.points,
                    strokeWidth: 7,
                    color: route.isStraightLine ? Palette.bark : Palette.forest,
                    borderStrokeWidth: 3,
                    borderColor: Colors.white,
                    pattern: route.isStraightLine
                        ? StrokePattern.dashed(segments: const [12, 9])
                        : const StrokePattern.solid(),
                  ),
                ],
              ),
            if (here != null && accuracy != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: here,
                    radius: accuracy.clamp(5, 200),
                    useRadiusInMeter: true,
                    color: const Color(0xFF2D7DD2).withValues(alpha: .12),
                    borderColor: const Color(0xFF2D7DD2).withValues(alpha: .35),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final s in spots)
                  Marker(
                    point: LatLng(s.latitude, s.longitude),
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _startNavigation(s),
                      child: Tooltip(
                        message: s.name,
                        child: SpotPin(spot: s, selected: nav.target?.id == s.id),
                      ),
                    ),
                  ),
                if (here != null)
                  Marker(
                    point: here,
                    width: 56,
                    height: 56,
                    child: const IgnorePointer(child: UserDot()),
                  ),
              ],
            ),
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution('© contributeurs OpenStreetMap')],
            ),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                LocationBanner(
                  state: location,
                  onRetry: () => ref.invalidate(locationProvider),
                ),
                if (nav.active) ...[
                  const SizedBox(height: 8),
                  InstructionBanner(nav: nav),
                ],
              ],
            ),
          ),
        ),
        // Boutons flottants, au-dessus du panneau.
        ValueListenableBuilder<double>(
          valueListenable: _extent,
          builder: (context, extent, _) {
            final height = MediaQuery.sizeOf(context).height;
            final bottom = wide ? 16.0 : (extent * height * .86).clamp(70.0, height * .62) + 8;
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 120),
              right: 14,
              bottom: bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'recenter',
                    backgroundColor: Palette.paper,
                    foregroundColor: Palette.forest,
                    tooltip: 'Me recentrer',
                    onPressed: _recenter,
                    child: const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.extended(
                    heroTag: 'add-spot',
                    onPressed: _newSpotHere,
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Nouveau coin'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
