import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/features/map/geo.dart';
import 'package:mycelium/features/map/location.dart';
import 'package:mycelium/features/map/navigation.dart';

Position position(double lat, double lon, {double speed = 0, double heading = 0}) =>
    Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime(2026, 10, 8),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: heading,
      headingAccuracy: 0,
      speed: speed,
      speedAccuracy: 0,
    );

Spot spotAt(double lat, double lon) => Spot(
      id: 's1',
      name: 'Coin test',
      latitude: lat,
      longitude: lon,
      isFavorite: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('Fonctions géographiques', () {
    test('cap vers le nord, l\'est et le sud', () {
      const origin = LatLng(48.0, 7.0);
      expect(bearingBetween(origin, const LatLng(48.01, 7.0)), closeTo(0, 0.5));
      expect(bearingBetween(origin, const LatLng(48.0, 7.01)), closeTo(90, 0.5));
      expect(bearingBetween(origin, const LatLng(47.99, 7.0)), closeTo(180, 0.5));
    });

    test('points cardinaux', () {
      expect(cardinal(0), 'nord');
      expect(cardinal(44), 'nord-est');
      expect(cardinal(181), 'sud');
      expect(cardinal(359), 'nord');
    });

    test('formats de distance et de durée', () {
      expect(formatDistance(412), '410 m');
      expect(formatDistance(1500), '1,5 km');
      expect(formatDistance(12400), '12 km');
      expect(formatDuration(20), '< 1 min');
      expect(formatDuration(600), '10 min');
      expect(formatDuration(5400), '1 h 30');
    });
  });

  group('Guidage à vol d\'oiseau', () {
    late StreamController<LocationState> gps;
    late ProviderContainer container;

    setUp(() {
      gps = StreamController<LocationState>();
      container = ProviderContainer(overrides: [
        locationProvider.overrideWith((ref) => gps.stream),
      ]);
      container.listen(navigationProvider, (_, _) {});
      container.listen(locationProvider, (_, _) {});
    });

    tearDown(() async {
      container.dispose();
      await gps.close();
    });

    Future<void> emit(Position p) async {
      gps.add(LocationState(LocationStatus.ok, p));
      await Future<void>.delayed(Duration.zero);
    }

    NavState nav() => container.read(navigationProvider);

    test('attend la position GPS si elle est inconnue', () {
      container.read(navigationProvider.notifier).start(spotAt(48.01, 7.0));
      expect(nav().active, isTrue);
      expect(nav().waitingForPosition, isTrue);
      expect(nav().distance, isNull);
    });

    test('calcule distance, cap et durée sans réseau', () async {
      await emit(position(48.0, 7.0));
      container.read(navigationProvider.notifier).start(spotAt(48.01, 7.0));

      expect(nav().waitingForPosition, isFalse);
      expect(nav().distance, closeTo(1112, 15));
      expect(nav().bearing, closeTo(0, 0.5));
      expect(nav().seconds, closeTo(1112 / forestWalkingSpeed, 20));
      expect(nav().line, hasLength(2));
      expect(nav().arrived, isFalse);
    });

    test('se met à jour quand on avance', () async {
      await emit(position(48.0, 7.0));
      container.read(navigationProvider.notifier).start(spotAt(48.01, 7.0));
      final before = nav().distance!;

      await emit(position(48.005, 7.0));
      expect(nav().distance!, lessThan(before / 2 + 10));
    });

    test('détecte l\'arrivée à moins de 20 m', () async {
      await emit(position(48.0, 7.0));
      container.read(navigationProvider.notifier).start(spotAt(48.0001, 7.0));
      expect(nav().arrived, isTrue);
    });

    test('direction relative : coin au nord, on marche vers l\'est => à gauche', () async {
      await emit(position(48.0, 7.0, speed: 1.4, heading: 90));
      container.read(navigationProvider.notifier).start(spotAt(48.01, 7.0));
      expect(nav().relativeAngle, closeTo(-90, 1));
    });

    test('pas de direction relative à l\'arrêt', () async {
      await emit(position(48.0, 7.0, speed: 0, heading: 90));
      container.read(navigationProvider.notifier).start(spotAt(48.01, 7.0));
      expect(nav().relativeAngle, isNull);
    });

    test('stop() termine le guidage', () async {
      await emit(position(48.0, 7.0));
      final controller = container.read(navigationProvider.notifier);
      controller.start(spotAt(48.01, 7.0));
      controller.stop();
      expect(nav().active, isFalse);
    });
  });
}
