import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/features/species/data/species_seed.dart';
import 'package:mycelium/features/species/domain/species_groups.dart';

void main() {
  test('chaque espèce du catalogue a un type explicite', () {
    for (final s in speciesSeed) {
      expect(speciesGroups.containsKey(s.id), isTrue,
          reason: 'ajoutez ${s.id} à speciesGroups');
    }
    // Pas d'identifiant orphelin non plus.
    final ids = speciesSeed.map((s) => s.id).toSet();
    expect(speciesGroups.keys.toSet().difference(ids), isEmpty);
  });

  test('types attendus par un cueilleur', () {
    expect(groupOfSpecies('girolle'), MushroomGroup.chanterelles);
    expect(groupOfSpecies('chanterelle-cendree'), MushroomGroup.chanterelles);
    expect(groupOfSpecies('cepe-d-ete'), MushroomGroup.cepes);
    expect(groupOfSpecies('morille'), MushroomGroup.morilles);
    // La fausse girolle n'est pas une chanterelle : jamais dans « coins à chanterelles ».
    expect(groupOfSpecies('fausse-girolle'), MushroomGroup.autres);
    // Une espèce ajoutée par l'utilisateur est classée « autres ».
    expect(groupOfSpecies('une-espece-perso'), MushroomGroup.autres);
  });

  test('un filtre vide laisse tout passer, sinon il faut une espèce du type', () {
    expect(matchesGroups(const ['girolle'], {}), isTrue);
    expect(matchesGroups(const [], {}), isTrue);
    expect(matchesGroups(const ['girolle', 'morille'], {MushroomGroup.morilles}), isTrue);
    expect(matchesGroups(const ['girolle'], {MushroomGroup.cepes}), isFalse);
    expect(matchesGroups(const [], {MushroomGroup.cepes}), isFalse);
    expect(
      matchesGroups(const ['girolle'], {MushroomGroup.cepes, MushroomGroup.chanterelles}),
      isTrue,
      reason: 'sélection multiple = OU',
    );
  });
}
