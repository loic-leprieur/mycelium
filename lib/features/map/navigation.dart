import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/database.dart';
import 'geo.dart';
import 'location.dart';
import 'routing.dart';

/// État du guidage vers un coin.
class NavState {
  const NavState({
    this.target,
    this.route,
    this.loading = false,
    this.arrived = false,
    this.remaining,
    this.nextStep,
    this.distanceToNext,
    this.rerouting = false,
    this.routeVersion = 0,
  });

  final Spot? target;
  final WalkingRoute? route;
  final bool loading;
  final bool arrived;

  /// Distance restante (m) jusqu'au coin.
  final double? remaining;
  final RouteStep? nextStep;
  final double? distanceToNext;
  final bool rerouting;

  /// Incrémenté à chaque nouveau tracé : la carte s'y recadre.
  final int routeVersion;

  bool get active => target != null;

  double? get remainingSeconds {
    final r = route;
    final rem = remaining;
    if (r == null || rem == null || r.distance == 0) return null;
    return r.duration * (rem / r.distance);
  }

  NavState copyWith({
    WalkingRoute? route,
    bool? loading,
    bool? arrived,
    double? remaining,
    RouteStep? nextStep,
    double? distanceToNext,
    bool? rerouting,
    int? routeVersion,
  }) =>
      NavState(
        target: target,
        route: route ?? this.route,
        loading: loading ?? this.loading,
        arrived: arrived ?? this.arrived,
        remaining: remaining ?? this.remaining,
        nextStep: nextStep ?? this.nextStep,
        distanceToNext: distanceToNext ?? this.distanceToNext,
        rerouting: rerouting ?? this.rerouting,
        routeVersion: routeVersion ?? this.routeVersion,
      );
}

final routingServiceProvider = Provider<RoutingService>((ref) => RoutingService());

/// Guidage à pied : calcule l'itinéraire, le suit avec le GPS et recalcule si
/// l'utilisateur s'écarte du tracé.
class NavigationController extends Notifier<NavState> {
  static const _arrivalRadius = 25.0;
  static const _offRouteRadius = 45.0;
  static const _rerouteCooldown = Duration(seconds: 20);

  int _token = 0;
  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  NavState build() {
    ref.listen<AsyncValue<LocationState>>(locationProvider, (_, next) {
      final here = next.value?.latLng;
      if (here != null) _onPosition(here);
    });
    return const NavState();
  }

  Future<void> start(Spot spot) async {
    _token++;
    _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);
    state = NavState(target: spot, loading: true);
    final here = ref.read(locationProvider).value?.latLng;
    if (here != null) {
      await _fetch(here);
    }
  }

  void stop() {
    _token++;
    state = const NavState();
  }

  Future<void> _fetch(LatLng here) async {
    final target = state.target;
    if (target == null) return;
    final token = ++_token;
    _lastFetch = DateTime.now();
    final wasRoute = state.route != null;
    state = state.copyWith(loading: !wasRoute, rerouting: wasRoute);

    final route = await ref
        .read(routingServiceProvider)
        .walkingRoute(here, LatLng(target.latitude, target.longitude));
    if (token != _token || state.target?.id != target.id) return;

    // La carte ne se recadre que pour un premier tracé ou un changement de type
    // (direct <-> réel), pas à chaque recalcul.
    final previous = state.route;
    final reframe = previous == null || previous.isStraightLine != route.isStraightLine;
    state = state.copyWith(
      route: route,
      loading: false,
      rerouting: false,
      arrived: false,
      routeVersion: reframe ? state.routeVersion + 1 : state.routeVersion,
    );
    _onPosition(here);
  }

  void _onPosition(LatLng here) {
    final target = state.target;
    if (target == null) return;

    final destination = LatLng(target.latitude, target.longitude);
    final route = state.route;

    if (route == null) {
      if (!state.loading || DateTime.now().difference(_lastFetch) > _rerouteCooldown) {
        // Première position obtenue après le démarrage, ou nouvel essai.
        _fetch(here);
      }
      return;
    }

    if (metersBetween(here, destination) <= _arrivalRadius) {
      state = state.copyWith(arrived: true, remaining: 0);
      return;
    }

    final projection = projectOnRoute(here, route.points, route.cumulative);
    final remaining = (route.distance - projection.along).clamp(0.0, double.infinity);

    // Prochaine manœuvre : première étape dont le départ est devant nous.
    var cumulative = 0.0;
    RouteStep? next;
    double? distanceToNext;
    for (var i = 0; i < route.steps.length; i++) {
      if (i > 0 && cumulative > projection.along + 5) {
        next = route.steps[i];
        distanceToNext = cumulative - projection.along;
        break;
      }
      cumulative += route.steps[i].distance;
    }
    next ??= route.steps.isEmpty ? null : route.steps.last;
    distanceToNext ??= remaining;

    state = state.copyWith(
      arrived: false,
      remaining: remaining,
      nextStep: next,
      distanceToNext: distanceToNext,
    );

    final offRoute = projection.offRoute > _offRouteRadius;
    if (offRoute &&
        !route.isStraightLine &&
        DateTime.now().difference(_lastFetch) > _rerouteCooldown) {
      _fetch(here);
    } else if (route.isStraightLine &&
        DateTime.now().difference(_lastFetch) > const Duration(seconds: 60)) {
      // Réessaie régulièrement d'obtenir un vrai itinéraire.
      _fetch(here);
    }
  }
}

final navigationProvider =
    NotifierProvider<NavigationController, NavState>(NavigationController.new);
