import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/features/species/data/species_seed.dart';
import 'package:mycelium/features/species/ui/filters/french_text.dart';
import 'package:mycelium/features/species/ui/filters/habitat_families.dart';

const f = HabitatFamily.feuillus;
const c = HabitatFamily.coniferes;
const m = HabitatFamily.mixte;

void main() {
  test('accents et majuscules sont ignorés', () {
    expect(foldAccents('Cèpe d\'Été ŒUF'), 'cepe d\'ete oeuf');
  });

  test('catalogue réel : familles de chaque espèce', () {
    const expected = <String, Set<HabitatFamily>>{
      'cepe-de-bordeaux': {f, c, m},
      'cepe-d-ete': {f},
      'cepe-des-pins': {f, c, m},
      'bolet-bai': {f, c, m},
      'bolet-a-pied-rouge': {f, c, m},
      'bolet-granule': {c},
      'girolle': {f, c, m},
      'chanterelle-en-tube': {c},
      'chanterelle-cendree': {f},
      'trompette-de-la-mort': {f},
      'pied-de-mouton': {f, c, m},
      'morille': {f, HabitatFamily.lisieres},
      'amanite-phalloide': {f},
      'amanite-panthere': {f, c, m},
      'amanite-tue-mouches': {f, c, m},
      'galere-marginee': {f, c, m, HabitatFamily.boisMort},
      'cortinaire-des-montagnes': {c},
      'gyromitre': {c},
      'bolet-de-satan': {f},
      'bolet-amer': {c},
      'fausse-girolle': {c},
    };
    for (final s in speciesSeed) {
      expect(habitatFamilies(s.habitat), expected[s.id], reason: '${s.id} : ${s.habitat}');
    }
    expect(expected.keys.toSet(), speciesSeed.map((s) => s.id).toSet());
  });

  test('habitat non renseigné : aucune famille ; renseigné mais inconnu : « autre »', () {
    expect(habitatFamilies(null), isEmpty);
    expect(habitatFamilies('   '), isEmpty);
    expect(habitatFamilies('Tourbières'), {HabitatFamily.autre});
  });

  test('variantes d\'écriture', () {
    expect(habitatFamilies('HÊTRAIE'), {f});
    expect(habitatFamilies('Pessière et pinède'), {c});
    expect(habitatFamilies('Sous les bouleaux'), {f});
    expect(habitatFamilies('Forêts mixtes'), {m});
    expect(habitatFamilies('Clairières, bords de chemin'), {HabitatFamily.lisieres});
    expect(habitatFamilies('Souches de sapin'), {c, HabitatFamily.boisMort});
  });
}
