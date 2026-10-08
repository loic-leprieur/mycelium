import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'geo.dart';

/// Une manœuvre de l'itinéraire (« tournez à gauche », « vous êtes arrivé »…).
class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.icon,
    required this.distance,
    required this.location,
  });

  final String instruction;
  final IconData icon;

  /// Longueur (m) du tronçon qui suit cette manœuvre.
  final double distance;
  final LatLng location;
}

class WalkingRoute {
  const WalkingRoute({
    required this.points,
    required this.distance,
    required this.duration,
    required this.steps,
    required this.cumulative,
    this.isStraightLine = false,
  });

  final List<LatLng> points;
  final double distance;
  final double duration;
  final List<RouteStep> steps;
  final List<double> cumulative;

  /// Tracé direct de secours (pas de réseau ou pas de chemin trouvé).
  final bool isStraightLine;
}

/// Itinéraire à pied.
///
/// PROVISOIRE : utilise le serveur public « foot » de routing.openstreetmap.de
/// (données OpenStreetMap, ODbL), prévu pour un usage léger. Avant toute
/// diffusion, le remplacer par un service dont les conditions autorisent un
/// usage commercial, ou par un calcul hors ligne (cahier des charges §10.2).
class RoutingService {
  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _walkingSpeed = 1.3; // m/s, environ 4,7 km/h

  Future<WalkingRoute> walkingRoute(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        'https://routing.openstreetmap.de/routed-foot/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );
      final response = await _client.get(uri, headers: {
        'User-Agent': 'mycelium-app/0.1 (fr.mycelium.mycelium)',
      }).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      return _parse(jsonDecode(response.body) as Map<String, dynamic>, from, to);
    } catch (_) {
      return straightLine(from, to);
    }
  }

  /// Tracé direct avec cap : utilisable sans connexion.
  static WalkingRoute straightLine(LatLng from, LatLng to) {
    final distance = metersBetween(from, to);
    final bearing = bearingBetween(from, to);
    final points = [from, to];
    return WalkingRoute(
      points: points,
      distance: distance,
      duration: distance / _walkingSpeed,
      cumulative: [0, distance],
      isStraightLine: true,
      steps: [
        RouteStep(
          instruction: 'Dirigez-vous vers le ${cardinal(bearing)}',
          icon: Icons.navigation,
          distance: distance,
          location: from,
        ),
        RouteStep(
          instruction: 'Vous êtes arrivé',
          icon: Icons.flag,
          distance: 0,
          location: to,
        ),
      ],
    );
  }

  WalkingRoute _parse(Map<String, dynamic> json, LatLng from, LatLng to) {
    if (json['code'] != 'Ok') throw Exception('no route');
    final route = (json['routes'] as List).first as Map<String, dynamic>;
    final coords = (route['geometry']['coordinates'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    if (coords.length < 2) throw Exception('empty geometry');

    final steps = <RouteStep>[];
    for (final leg in route['legs'] as List) {
      for (final s in (leg['steps'] as List)) {
        final m = s['maneuver'] as Map<String, dynamic>;
        final loc = m['location'] as List;
        final (text, icon) = _describe(
          m['type'] as String,
          m['modifier'] as String?,
          (s['name'] as String?) ?? '',
          m['exit'] as int?,
        );
        steps.add(RouteStep(
          instruction: text,
          icon: icon,
          distance: (s['distance'] as num).toDouble(),
          location: LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
        ));
      }
    }

    return WalkingRoute(
      points: coords,
      distance: (route['distance'] as num).toDouble(),
      duration: (route['duration'] as num).toDouble(),
      steps: steps,
      cumulative: cumulativeDistances(coords),
    );
  }

  static (String, IconData) _describe(String type, String? modifier, String name, int? exit) {
    final on = name.isEmpty ? '' : ' sur $name';
    switch (type) {
      case 'depart':
        return ('Démarrez$on', Icons.directions_walk);
      case 'arrive':
        return ('Vous êtes arrivé', Icons.flag);
      case 'roundabout':
      case 'rotary':
        return (
          exit == null ? 'Prenez le rond-point' : 'Au rond-point, prenez la ${exit}e sortie',
          Icons.roundabout_left,
        );
      case 'fork':
        return (
          modifier != null && modifier.contains('left')
              ? 'À la bifurcation, restez à gauche$on'
              : 'À la bifurcation, restez à droite$on',
          modifier != null && modifier.contains('left') ? Icons.fork_left : Icons.fork_right,
        );
    }
    switch (modifier) {
      case 'left':
        return ('Tournez à gauche$on', Icons.turn_left);
      case 'right':
        return ('Tournez à droite$on', Icons.turn_right);
      case 'slight left':
        return ('Tournez légèrement à gauche$on', Icons.turn_slight_left);
      case 'slight right':
        return ('Tournez légèrement à droite$on', Icons.turn_slight_right);
      case 'sharp left':
        return ('Tournez franchement à gauche$on', Icons.turn_sharp_left);
      case 'sharp right':
        return ('Tournez franchement à droite$on', Icons.turn_sharp_right);
      case 'uturn':
        return ('Faites demi-tour', Icons.u_turn_left);
      default:
        return ('Continuez tout droit$on', Icons.straight);
    }
  }
}
