import 'package:latlong2/latlong.dart';

const _distance = Distance();

double metersBetween(LatLng a, LatLng b) =>
    _distance.as(LengthUnit.Meter, a, b);

/// Cap (0–360°, 0 = nord) pour aller de [a] à [b].
double bearingBetween(LatLng a, LatLng b) =>
    (_distance.bearing(a, b) + 360) % 360;

/// Point cardinal le plus proche d'un cap.
String cardinal(double bearing) {
  const names = [
    'nord',
    'nord-est',
    'est',
    'sud-est',
    'sud',
    'sud-ouest',
    'ouest',
    'nord-ouest',
  ];
  return names[((bearing + 22.5) % 360) ~/ 45];
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
