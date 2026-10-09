import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/features/map/spot_visits.dart';

Outing outing(String id, DateTime at, {String? spotId}) =>
    Outing(id: id, spotId: spotId, startedAt: at);

Harvest harvest(String species, {int? count, int? grams}) => Harvest(
      id: '$species-$count-$grams',
      outingId: 'o',
      speciesId: species,
      quantityCount: count,
      weightGrams: grams,
    );

String nameOf(String id) => switch (id) {
      'cepe-de-bordeaux' => 'Cèpe de Bordeaux',
      'girolle' => 'Girolle',
      _ => id,
    };

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('Dernière visite (SPOT-5)', () {
    test('la sortie la plus récente de chaque coin, quel que soit l\'ordre', () {
      final last = lastVisitBySpot([
        outing('1', DateTime(2026, 9, 1), spotId: 'a'),
        outing('2', DateTime(2026, 10, 5), spotId: 'a'),
        outing('3', DateTime(2026, 9, 20), spotId: 'a'),
        outing('4', DateTime(2026, 8, 2), spotId: 'b'),
      ]);
      expect(last, {'a': DateTime(2026, 10, 5), 'b': DateTime(2026, 8, 2)});
    });

    test('les sorties sans coin sont ignorées', () {
      expect(lastVisitBySpot([outing('1', DateTime(2026, 9, 1))]), isEmpty);
      expect(lastVisitBySpot(const []), isEmpty);
    });

    test('libellés : date en français ou « Jamais visité »', () {
      expect(visitLabel(DateTime(2026, 10, 5)), 'Dernière visite : 5 oct. 2026');
      expect(visitLabel(DateTime(2026, 2, 17, 18, 30)), 'Dernière visite : 17 févr. 2026');
      expect(visitLabel(null), 'Jamais visité');
      expect(shortDate(DateTime(2026, 12, 1)), '1 déc. 2026');
    });
  });

  group('Résumé des récoltes d\'une sortie', () {
    test('sans récolte', () {
      expect(harvestSummary(const [], nameOf), 'Aucune récolte');
    });

    test('espèces, pièces et poids cumulés', () {
      expect(
        harvestSummary([
          harvest('cepe-de-bordeaux', count: 3, grams: 500),
          harvest('girolle', count: 2, grams: 350),
        ], nameOf),
        'Cèpe de Bordeaux, Girolle · 5 pièces · 850 g',
      );
    });

    test('une espèce récoltée deux fois n\'est nommée qu\'une fois', () {
      expect(
        harvestSummary([
          harvest('girolle', count: 1),
          harvest('girolle', count: 1),
        ], nameOf),
        'Girolle · 2 pièces',
      );
    });

    test('quantité et poids facultatifs', () {
      expect(harvestSummary([harvest('girolle')], nameOf), 'Girolle');
      expect(harvestSummary([harvest('girolle', grams: 1250)], nameOf), 'Girolle · 1,25 kg');
      expect(harvestSummary([harvest('girolle', count: 1)], nameOf), 'Girolle · 1 pièce');
    });
  });
}
