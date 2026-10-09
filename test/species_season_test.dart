import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/features/species/data/species_seed.dart';
import 'package:mycelium/features/species/domain/species.dart';
import 'package:mycelium/features/species/ui/filters/season.dart';

Species withSeason(int? start, int? end) => Species(
      id: 'x',
      commonName: 'X',
      edibility: Edibility.good,
      seasonStart: start,
      seasonEnd: end,
    );

void main() {
  test('saison simple : bornes comprises', () {
    for (var m = 1; m <= 12; m++) {
      expect(monthInSeason(m, start: 6, end: 9), m >= 6 && m <= 9, reason: 'mois $m');
    }
  });

  test('saison à cheval sur deux années : novembre -> février', () {
    const inside = {11, 12, 1, 2};
    for (var m = 1; m <= 12; m++) {
      expect(monthInSeason(m, start: 11, end: 2), inside.contains(m), reason: 'mois $m');
    }
  });

  test('un seul mois, et toute l\'année', () {
    expect([for (var m = 1; m <= 12; m++) if (monthInSeason(m, start: 4, end: 4)) m], [4]);
    expect([for (var m = 1; m <= 12; m++) if (monthInSeason(m, start: 1, end: 12)) m], hasLength(12));
    // Avril -> mars : toute l'année en passant par le Nouvel An.
    expect([for (var m = 1; m <= 12; m++) if (monthInSeason(m, start: 4, end: 3)) m], hasLength(12));
  });

  test('espèce sans saison ou à mois invalides : inconnu, jamais « de saison »', () {
    expect(speciesInSeason(withSeason(null, null), 10), isNull);
    expect(speciesInSeason(withSeason(5, null), 10), isNull);
    expect(speciesInSeason(withSeason(0, 5), 3), isNull);
    expect(speciesInSeason(withSeason(5, 13), 6), isNull);
    expect(speciesInSeason(withSeason(11, 2), 1), isTrue);
    expect(speciesInSeason(withSeason(11, 2), 6), isFalse);
  });

  test('catalogue : mois valides, et octobre', () {
    for (final s in speciesSeed) {
      expect(speciesInSeason(s, 1), isNotNull, reason: s.id);
    }
    final october = speciesSeed.where((s) => speciesInSeason(s, 10) == true).map((s) => s.id);
    expect(october, containsAll(['cepe-de-bordeaux', 'girolle', 'amanite-phalloide']));
    expect(october, isNot(contains('morille')));
    expect(october, isNot(contains('cepe-d-ete')));
  });

  test('noms de mois', () {
    expect(monthNames, hasLength(12));
    expect(capitalMonth(8), 'Août');
    expect(capitalMonth(1), 'Janvier');
  });
}
