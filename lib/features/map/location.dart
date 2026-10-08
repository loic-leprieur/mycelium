import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationStatus { ok, serviceOff, denied, deniedForever, unavailable }

class LocationState {
  const LocationState(this.status, [this.position]);

  final LocationStatus status;
  final Position? position;

  LatLng? get latLng =>
      position == null ? null : LatLng(position!.latitude, position!.longitude);
}

/// Position GPS en continu. Gère le service désactivé et les permissions.
final locationProvider = StreamProvider<LocationState>((ref) async* {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      yield const LocationState(LocationStatus.serviceOff);
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      yield const LocationState(LocationStatus.deniedForever);
      return;
    }
    if (permission == LocationPermission.denied) {
      yield const LocationState(LocationStatus.denied);
      return;
    }

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) yield LocationState(LocationStatus.ok, last);
    } catch (_) {
      // Non pris en charge sur toutes les plateformes : on continue.
    }

    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      yield LocationState(LocationStatus.ok, current);
    } catch (_) {
      // Pas encore de fix : le flux ci-dessous prendra le relais.
    }

    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 4,
      ),
    ).map((p) => LocationState(LocationStatus.ok, p));
  } catch (_) {
    yield const LocationState(LocationStatus.unavailable);
  }
});
