import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/features/identify/identifier.dart';
import 'package:mycelium/features/species/data/species_seed.dart';
import 'package:mycelium/features/species/domain/species.dart';

IdentificationOutcome run(DemoScenario s) => applySafetyRules(
      s.candidates,
      edibilityOf: seedEdibilityOf,
      isDemo: true,
    );

void main() {
  group('Règles de sécurité de l\'identification', () {
    test('RM-5 : un candidat net n\'est pas insuffisant', () {
      final outcome = run(FakeIdentifier.scenarios[0]);
      expect(outcome.isInsufficient, isFalse);
      expect(outcome.candidates.first.speciesId, 'bolet-bai');
    });

    test('RM-5 : deux candidats proches => identification insuffisante', () {
      final outcome = run(FakeIdentifier.scenarios[1]);
      expect(outcome.isInsufficient, isTrue);
    });

    test('RM-5 : liste vide => identification insuffisante', () {
      final outcome = applySafetyRules(const [], edibilityOf: seedEdibilityOf);
      expect(outcome.isInsufficient, isTrue);
    });

    test('RM-6 : une espèce mortelle est signalée quel que soit son rang', () {
      final outcome = run(FakeIdentifier.scenarios[2]);
      expect(outcome.dangerousSpeciesIds, contains('amanite-phalloide'));
      expect(outcome.dangerousSpeciesIds, contains('galere-marginee'));
    });

    test('RM-6 : aucun signalement si aucune espèce dangereuse', () {
      final outcome = run(FakeIdentifier.scenarios[0]);
      // Le bolet amer n'est ni toxique ni mortel : pas d'alerte.
      expect(outcome.dangerousSpeciesIds, isEmpty);
    });

    test('Le top 5 est trié et limité à 5', () {
      final outcome = applySafetyRules(
        [
          for (var i = 0; i < 8; i++)
            Candidate(speciesId: 'cepe-de-bordeaux', score: i / 10),
        ],
        edibilityOf: seedEdibilityOf,
      );
      expect(outcome.candidates, hasLength(5));
      expect(outcome.candidates.first.score, 0.7);
    });
  });

  group('Catalogue d\'espèces', () {
    test('les identifiants sont uniques', () {
      final ids = speciesSeed.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('toutes les confusions référencées existent', () {
      final ids = speciesSeed.map((s) => s.id).toSet();
      for (final s in speciesSeed) {
        for (final c in s.confusions) {
          if (c.speciesId != null) {
            expect(ids, contains(c.speciesId), reason: '${s.id} -> ${c.speciesId}');
          }
        }
      }
    });

    test('tous les scénarios de démonstration pointent vers des espèces connues', () {
      final ids = speciesSeed.map((s) => s.id).toSet();
      for (final scenario in FakeIdentifier.scenarios) {
        for (final c in scenario.candidates) {
          expect(ids, contains(c.speciesId));
        }
      }
    });

    test('les espèces mortelles du cahier des charges sont présentes', () {
      final deadly = speciesSeed
          .where((s) => s.edibility == Edibility.deadly)
          .map((s) => s.id)
          .toSet();
      expect(deadly, containsAll(['amanite-phalloide', 'galere-marginee']));
    });
  });
}
