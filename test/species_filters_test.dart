import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/features/species/data/species_seed.dart';
import 'package:mycelium/features/species/domain/species.dart';
import 'package:mycelium/features/species/domain/species_groups.dart';
import 'package:mycelium/features/species/ui/filters/habitat_families.dart';
import 'package:mycelium/features/species/ui/filters/species_filters.dart';

Set<String> ids(SpeciesFilters filters, [Iterable<Species>? all]) =>
    applyFilters(all ?? speciesSeed, filters).shown.map((s) => s.id).toSet();

const personal = Species(id: 'perso', commonName: 'Cèpe perso', edibility: Edibility.inedible, isCustom: true);
const winter = Species(
  id: 'hiver',
  commonName: 'Pleurote d\'hiver',
  edibility: Edibility.good,
  habitat: 'Feuillus',
  seasonStart: 11,
  seasonEnd: 2,
);

void main() {
  test('aucun critère : tout passe', () {
    expect(ids(const SpeciesFilters()), speciesSeed.map((s) => s.id).toSet());
  });

  test('OU à l\'intérieur d\'un critère', () {
    expect(ids(const SpeciesFilters(edibilities: {Edibility.deadly})),
        {'amanite-phalloide', 'galere-marginee', 'cortinaire-des-montagnes', 'gyromitre'});
    expect(ids(const SpeciesFilters(edibilities: {Edibility.deadly, Edibility.toxic})),
        hasLength(7));
  });

  test('ET entre critères : conifères + bon comestible + type', () {
    const base = SpeciesFilters(
      edibilities: {Edibility.good},
      habitats: {HabitatFamily.coniferes},
    );
    expect(ids(base), {
      'cepe-de-bordeaux', 'cepe-des-pins', 'bolet-bai', 'bolet-granule', 'girolle',
      'chanterelle-en-tube', 'pied-de-mouton',
    });
    expect(ids(base.copyWith(groups: {MushroomGroup.chanterelles})),
        {'girolle', 'chanterelle-en-tube'});
    expect(ids(base.copyWith(groups: {MushroomGroup.chanterelles}, month: 12)),
        {'chanterelle-en-tube'});
  });

  test('recherche : accents ignorés et combinable', () {
    expect(ids(const SpeciesFilters(query: 'cepe')),
        {'cepe-de-bordeaux', 'cepe-d-ete', 'cepe-des-pins'});
    expect(ids(const SpeciesFilters(query: 'BOLETUS')), isNotEmpty);
    expect(ids(const SpeciesFilters(query: 'cèpe', habitats: {HabitatFamily.coniferes})),
        {'cepe-de-bordeaux', 'cepe-des-pins'});
  });

  test('fiche sans habitat ni saison : écartée mais comptée, jamais perdue en silence', () {
    final all = [...speciesSeed, personal, winter];
    const filters = SpeciesFilters(habitats: {HabitatFamily.coniferes}, month: 10);
    var out = applyFilters(all, filters);
    expect(out.shown.map((s) => s.id), isNot(contains('perso')));
    expect(out.unknown, 1);

    out = applyFilters(all, filters.copyWith(includeUnknown: true));
    expect(out.shown.map((s) => s.id), contains('perso'));
    expect(out.unknown, 1);

    // Habitat qui ne correspond pas : écartée définitivement, même avec l'option.
    out = applyFilters(all, const SpeciesFilters(habitats: {HabitatFamily.boisMort}, includeUnknown: true));
    expect(out.shown.map((s) => s.id), contains('perso'));
    // Sans critère d'habitat ni de saison, l'option est neutralisée.
    expect(const SpeciesFilters().copyWith(includeUnknown: true).includeUnknown, isFalse);
  });

  test('saison à cheval sur l\'année dans les filtres', () {
    final all = [winter];
    expect(ids(const SpeciesFilters(month: 1), all), {'hiver'});
    expect(ids(const SpeciesFilters(month: 6), all), isEmpty);
  });

  test('critères, résumé et tri alphabétique français', () {
    const f = SpeciesFilters(
      edibilities: {Edibility.toxic, Edibility.deadly},
      month: 10,
      query: 'x',
    );
    expect(f.criteriaCount, 2);
    expect(f.summary, ['Toxique ou Mortel', 'En octobre']);
    expect(const SpeciesFilters(query: 'x').hasCriteria, isFalse);
    expect(const SpeciesFilters(query: 'x').isNarrowed, isTrue);

    final names = sortedByName(speciesSeed).map((s) => s.commonName).toList();
    expect(names.indexOf('Cèpe de Bordeaux'), lessThan(names.indexOf('Chanterelle cendrée')));
  });
}
