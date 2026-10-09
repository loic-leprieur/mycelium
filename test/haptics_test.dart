import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/features/map/haptics.dart';
import 'package:mycelium/features/map/location.dart';
import 'package:mycelium/features/map/navigation.dart';

/// Moteur de vibration factice : enregistre chaque impulsion avec l'heure simulée.
class RecordingHaptics implements Haptics {
  RecordingHaptics(this.now);

  final Duration Function() now;
  final pulses = <({Duration at, double intensity})>[];
  final arrivals = <Duration>[];

  @override
  Future<void> pulse(double intensity) async =>
      pulses.add((at: now(), intensity: intensity));

  @override
  Future<void> arrival() async => arrivals.add(now());
}

void main() {
  group('Cadence des vibrations', () {
    test('aucune vibration au-delà de 50 m', () {
      expect(hapticIntervalFor(50.1), isNull);
      expect(hapticIntervalFor(200), isNull);
    });

    test('lent à 50 m, rapide dans les derniers mètres', () {
      expect(hapticIntervalFor(50), hapticSlowestInterval);
      expect(hapticIntervalFor(hapticFinalDistance), hapticFastestInterval);
      expect(hapticIntervalFor(2), hapticFastestInterval);
      expect(hapticIntervalFor(0), hapticFastestInterval);
    });

    test('de plus en plus rapprochées quand on approche', () {
      var previous = hapticIntervalFor(50)!;
      for (var meters = 49.0; meters >= 5; meters -= 1) {
        final current = hapticIntervalFor(meters)!;
        expect(current, lessThanOrEqualTo(previous), reason: 'à $meters m');
        previous = current;
      }
      // Milieu de la plage : environ la moyenne des deux extrêmes.
      expect(hapticIntervalFor(27.5)!.inMilliseconds, closeTo(1650, 5));
    });

    test('de plus en plus fortes quand on approche', () {
      expect(hapticIntensityFor(50), 0);
      expect(hapticIntensityFor(27.5), closeTo(.5, .01));
      expect(hapticIntensityFor(hapticFinalDistance), 1);
      expect(hapticIntensityFor(1), 1);
      expect(hapticIntensityFor(30), lessThan(hapticIntensityFor(20)));
    });
  });

  group('Vibrations pendant le guidage', () {
    late RecordingHaptics haptics;
    late GuidanceHaptics controller;
    late FakeAsync async;

    /// Exécute [body] dans un temps simulé, avec un contrôleur neuf.
    void simulate(void Function() body) {
      fakeAsync((fake) {
        async = fake;
        haptics = RecordingHaptics(() => fake.elapsed);
        controller = GuidanceHaptics(haptics);
        body();
        controller.dispose();
        expect(fake.pendingTimers, isEmpty, reason: 'minuteur laissé actif');
      });
    }

    void wait(Duration d) => async.elapse(d);

    void at(double meters, {bool active = true, bool enabled = true}) =>
        controller.update(active: active, distance: meters, enabled: enabled);

    test('silence au-delà de 50 m', () {
      simulate(() {
        at(80);
        wait(const Duration(seconds: 30));
        expect(haptics.pulses, isEmpty);
        expect(haptics.arrivals, isEmpty);
        expect(controller.running, isFalse);
      });
    });

    test('première vibration dès l\'entrée dans les 50 m, puis cadence régulière', () {
      simulate(() {
        at(40);
        expect(haptics.pulses, hasLength(1));
        expect(haptics.pulses.first.at, Duration.zero);

        // À 40 m : intervalle ≈ 2,4 s => impulsions à 0, 2,4, 4,8, 7,2 et 9,6 s.
        wait(const Duration(seconds: 10));
        final gaps = [
          for (var i = 1; i < haptics.pulses.length; i++)
            haptics.pulses[i].at - haptics.pulses[i - 1].at,
        ];
        expect(haptics.pulses, hasLength(5));
        for (final gap in gaps) {
          expect(gap.inMilliseconds, closeTo(2400, 100));
        }
      });
    });

    test('les vibrations s\'accélèrent et se renforcent quand on approche', () {
      simulate(() {
        at(48);
        // On avance : une nouvelle distance toutes les 5 s (comme le GPS).
        for (final meters in [44.0, 36.0, 28.0, 20.0, 12.0, 7.0]) {
          wait(const Duration(seconds: 5));
          at(meters);
        }
        wait(const Duration(seconds: 5));

        final gaps = [
          for (var i = 1; i < haptics.pulses.length; i++)
            haptics.pulses[i].at - haptics.pulses[i - 1].at,
        ];
        expect(gaps.first, greaterThan(gaps.last * 3));
        for (var i = 1; i < gaps.length; i++) {
          expect(gaps[i], lessThanOrEqualTo(gaps[i - 1] + const Duration(milliseconds: 100)));
        }
        final intensities = haptics.pulses.map((p) => p.intensity).toList();
        expect(intensities.first, lessThan(.2));
        expect(intensities.last, greaterThan(.9));
      });
    });

    test('la cadence suit la distance même sans nouvelle position GPS', () {
      simulate(() {
        at(30);
        wait(const Duration(seconds: 12));
        // Immobile : les vibrations continuent au même rythme (≈ 1,8 s).
        expect(haptics.pulses.length, greaterThanOrEqualTo(6));
      });
    });

    test('derniers mètres : un seul signal d\'arrivée puis silence', () {
      simulate(() {
        at(20);
        wait(const Duration(seconds: 3));
        final before = haptics.pulses.length;

        at(4);
        expect(haptics.arrivals, hasLength(1));
        expect(controller.running, isFalse);

        wait(const Duration(seconds: 30));
        at(3);
        at(8); // GPS qui oscille autour des derniers mètres
        at(4);
        wait(const Duration(seconds: 10));
        expect(haptics.arrivals, hasLength(1), reason: 'pas de signal en boucle');
        expect(haptics.pulses.length, before, reason: 'silence après l\'arrivée');
      });
    });

    test('si on s\'éloigne puis qu\'on revient, le signal d\'arrivée est réarmé', () {
      simulate(() {
        at(4);
        expect(haptics.arrivals, hasLength(1));

        at(30); // on s'éloigne au-delà de 15 m : les vibrations reprennent
        wait(const Duration(seconds: 3));
        expect(haptics.pulses, isNotEmpty);

        at(4);
        expect(haptics.arrivals, hasLength(2));
      });
    });

    test('guidage démarré dans les derniers mètres : signal d\'arrivée direct', () {
      simulate(() {
        at(3);
        expect(haptics.arrivals, hasLength(1));
        expect(haptics.pulses, isEmpty);
      });
    });

    test('désactiver les vibrations les coupe tout de suite', () {
      simulate(() {
        at(30);
        wait(const Duration(seconds: 4));
        final count = haptics.pulses.length;
        expect(count, greaterThan(0));

        at(30, enabled: false);
        expect(controller.running, isFalse);
        wait(const Duration(seconds: 20));
        expect(haptics.pulses.length, count);

        at(30); // réactivées
        expect(haptics.pulses.length, count + 1);
      });
    });

    test('arrêter le guidage coupe les vibrations', () {
      simulate(() {
        at(25);
        wait(const Duration(seconds: 2));
        controller.update(active: false, distance: null, enabled: true);
        expect(controller.running, isFalse);
        final count = haptics.pulses.length;
        wait(const Duration(seconds: 20));
        expect(haptics.pulses.length, count);
      });
    });

    test('position GPS inconnue : pas de vibration', () {
      simulate(() {
        controller.update(active: true, distance: null, enabled: true);
        wait(const Duration(seconds: 10));
        expect(haptics.pulses, isEmpty);
      });
    });
  });

  group('Lien avec le guidage', () {
    late StreamController<LocationState> gps;
    late ProviderContainer container;
    late RecordingHaptics haptics;

    Position position(double lat, double lon) => Position(
          latitude: lat,
          longitude: lon,
          timestamp: DateTime(2026, 10, 9),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
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

    setUp(() {
      gps = StreamController<LocationState>();
      haptics = RecordingHaptics(() => Duration.zero);
      container = ProviderContainer(overrides: [
        locationProvider.overrideWith((ref) => gps.stream),
        hapticsProvider.overrideWithValue(haptics),
      ]);
      container.listen(locationProvider, (_, _) {});
      container.listen(guidanceHapticsProvider, (_, _) {});
    });

    tearDown(() async {
      container.dispose();
      await gps.close();
    });

    Future<void> emit(double lat, double lon) async {
      gps.add(LocationState(LocationStatus.ok, position(lat, lon)));
      await Future<void>.delayed(Duration.zero);
    }

    test('vibre quand on lance un guidage à moins de 50 m, pas avant', () async {
      await emit(48.0, 7.0);
      // Coin à ≈ 111 m au nord : trop loin.
      container.read(navigationProvider.notifier).start(spotAt(48.001, 7.0));
      expect(haptics.pulses, isEmpty);

      // On avance jusqu'à ≈ 33 m du coin.
      await emit(48.0007, 7.0);
      expect(haptics.pulses, hasLength(1));
    });

    test('arrêter le guidage arrête les vibrations', () async {
      await emit(48.0, 7.0);
      container.read(navigationProvider.notifier).start(spotAt(48.0003, 7.0));
      expect(haptics.pulses, hasLength(1));

      container.read(navigationProvider.notifier).stop();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(haptics.pulses, hasLength(1));
    });

    test('l\'interrupteur coupe les vibrations du guidage', () async {
      container.read(hapticsEnabledProvider.notifier).toggle();
      await emit(48.0, 7.0);
      container.read(navigationProvider.notifier).start(spotAt(48.0003, 7.0));
      expect(haptics.pulses, isEmpty);

      container.read(hapticsEnabledProvider.notifier).toggle();
      expect(haptics.pulses, hasLength(1));
    });

    test('arrivée au coin : signal d\'arrivée', () async {
      await emit(48.0, 7.0);
      container.read(navigationProvider.notifier).start(spotAt(48.00003, 7.0));
      expect(haptics.arrivals, hasLength(1));
    });
  });
}
