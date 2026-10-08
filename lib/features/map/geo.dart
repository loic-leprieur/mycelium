import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const _distance = Distance();

double metersBetween(LatLng a, LatLng b) =>
    _distance.as(LengthUnit.Meter, a, b);

/// Cap (0–360°, 0 = nord) pour aller de [a] à [b].
double bearingBetween(LatLng a, LatLng b) =>
    (_distance.bearing(a, b) + 360) % 360;

String cardinal(double bearing) {
  const names = ['nord', 'nord-est', 'est', 'sud-est', 'sud', 'sud-ouest', 'ouest', 'nord-ouest'];
  return names[((bearing + 22.5) % 360 ~/ 45)];
}

String formatDistance(double meters) {
  if (meters < 1000) return '${(meters / 10).round() * 10} m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km < 10 ? 1 : 0).replaceAll('.', ',')} km';
}

String formatDuration(double seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 1) return '< 1 min';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

/// Position de l'utilisateur projetée sur un itinéraire.
class RouteProjection {
  const RouteProjection({required this.offRoute, required this.along});

  /// Distance (m) entre l'utilisateur et le tracé.
  final double offRoute;

  /// Distance (m) parcourue le long du tracé jusqu'au point le plus proche.
  final double along;
}

/// Distances cumulées le long d'une polyligne (cum[0] = 0).
List<double> cumulativeDistances(List<LatLng> points) {
  final cum = <double>[0];
  for (var i = 1; i < points.length; i++) {
    cum.add(cum.last + metersBetween(points[i - 1], points[i]));
  }
  return cum;
}

/// Projette [p] sur la polyligne (approximation plane locale, suffisante à
/// l'échelle d'un itinéraire à pied).
RouteProjection projectOnRoute(LatLng p, List<LatLng> pts, List<double> cum) {
  if (pts.length < 2) {
    return RouteProjection(offRoute: pts.isEmpty ? 0 : metersBetween(p, pts.first), along: 0);
  }
  final cosLat = math.cos(p.latitudeInRad);
  double best = double.infinity;
  double bestAlong = 0;
  for (var i = 0; i < pts.length - 1; i++) {
    final ax = (pts[i].longitude - p.longitude) * cosLat * 111320;
    final ay = (pts[i].latitude - p.latitude) * 110540;
    final bx = (pts[i + 1].longitude - p.longitude) * cosLat * 111320;
    final by = (pts[i + 1].latitude - p.latitude) * 110540;
    final dx = bx - ax;
    final dy = by - ay;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0 ? 0.0 : ((-ax * dx - ay * dy) / len2).clamp(0.0, 1.0);
    final cx = ax + t * dx;
    final cy = ay + t * dy;
    final d = math.sqrt(cx * cx + cy * cy);
    if (d < best) {
      best = d;
      bestAlong = cum[i] + t * (cum[i + 1] - cum[i]);
    }
  }
  return RouteProjection(offRoute: best, along: bestAlong);
}
