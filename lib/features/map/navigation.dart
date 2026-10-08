import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../data/database.dart';
import 'geo.dart';
import 'location.dart';

/// Allure moyenne en forêt (m/s) : plus lente que sur route (≈ 4 km/h).
const forestWalkingSpeed = 1.1;

/// Rayon (m) en dessous duquel on considère être arrivé au coin.
const arrivalRadius = 20.0;

/// Guidage « à vol d'oiseau » vers un coin.
///
/// En forêt il n'y a ni rue ni chemin cartographié : on ne calcule donc pas
/// d'itinéraire, on indique la direction (cap), la distance en ligne droite et
/// une durée estimée, recalculés à chaque position GPS. Fonctionne sans réseau.
class NavState {
  const NavState({
    this.target,
    this.user,
    this.heading,
    this.arrived = false,
    this.startVersion = 0,
  });

  final Spot? target;
  final LatLng? user;

  /// Direction de marche (°, 0 = nord), connue seulement quand on avance.
  final double? heading;
  final bool arrived;

  /// Incrémenté à chaque nouveau guidage : la carte se recadre dessus.
  final int startVersion;

  bool get active => target != null;
  bool get waitingForPosition => active && user == null;

  LatLng? get destination =>
      target == null ? null : LatLng(target!.latitude, target!.longitude);

  /// Distance en ligne droite (m).
  double? get distance {
    final u = user;
    final d = destination;
    if (u == null || d == null) return null;
    return metersBetween(u, d);
  }

  /// Cap absolu vers le coin (°, 0 = nord).
  double? get bearing {
    final u = user;
    final d = destination;
    if (u == null || d == null) return null;
    return bearingBetween(u, d);
  }

  /// Angle (−180…180°) entre la direction de marche et le coin :
  /// négatif = à gauche, positif = à droite. Nul si on ne bouge pas.
  double? get relativeAngle {
    final b = bearing;
    final h = heading;
    if (b == null || h == null) return null;
    var diff = (b - h) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return diff;
  }

  /// Durée estimée (s) à l'allure de marche en forêt.
  double? get seconds {
    final d = distance;
    return d == null ? null : d / forestWalkingSpeed;
  }

  /// Segment à tracer sur la carte : de vous au coin.
  List<LatLng> get line {
    final u = user;
    final d = destination;
    return (u == null || d == null) ? const [] : [u, d];
  }

  NavState copyWith({
    LatLng? user,
    double? heading,
    bool clearHeading = false,
    bool? arrived,
  }) =>
      NavState(
        target: target,
        user: user ?? this.user,
        heading: clearHeading ? null : (heading ?? this.heading),
        arrived: arrived ?? this.arrived,
        startVersion: startVersion,
      );
}

class NavigationController extends Notifier<NavState> {
  @override
  NavState build() {
    ref.listen<AsyncValue<LocationState>>(locationProvider, (_, next) {
      final value = next.value;
      if (value?.position != null) _onPosition(value!.position!);
    });
    return const NavState();
  }

  void start(Spot spot) {
    final position = ref.read(locationProvider).value?.position;
    state = NavState(target: spot, startVersion: state.startVersion + 1);
    if (position != null) _onPosition(position);
  }

  void stop() => state = NavState(startVersion: state.startVersion);

  void _onPosition(Position position) {
    if (!state.active) return;
    final here = LatLng(position.latitude, position.longitude);

    // Le cap GPS n'a de sens qu'en mouvement.
    final moving = position.speed >= 0.6 && position.heading >= 0;

    var next = state.copyWith(
      user: here,
      heading: moving ? position.heading : null,
      clearHeading: !moving,
    );
    final d = next.distance;
    if (d != null) next = next.copyWith(arrived: d <= arrivalRadius);
    state = next;
  }
}

final navigationProvider =
    NotifierProvider<NavigationController, NavState>(NavigationController.new);
