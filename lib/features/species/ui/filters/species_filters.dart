import 'package:flutter/foundation.dart' show immutable;

import '../../domain/species.dart';
import '../../domain/species_groups.dart';
import 'french_text.dart';
import 'habitat_families.dart';
import 'season.dart';

/// Ajoute [value] à [set] s'il n'y est pas, l'en retire sinon (renvoie une copie).
Set<T> toggled<T>(Set<T> set, T value) =>
    set.contains(value) ? ({...set}..remove(value)) : {...set, value};

/// Critères de la liste des espèces. Un critère vide ne filtre rien. Plusieurs
/// valeurs d'un même critère s'additionnent (OU : « feuillus » ou « conifères »),
/// et les critères se cumulent entre eux (ET : « conifères » ET « en octobre »).
@immutable
class SpeciesFilters {
  const SpeciesFilters({
    this.query = '',
    this.edibilities = const {},
    this.month,
    this.habitats = const {},
    this.groups = const {},
    this.includeUnknown = false,
  });

  /// Recherche dans le nom courant et le nom latin (accents et casse ignorés).
  final String query;
  final Set<Edibility> edibilities;

  /// Mois (1–12) où l'espèce doit être « de saison » ; `null` = toute l'année.
  final int? month;
  final Set<HabitatFamily> habitats;
  final Set<MushroomGroup> groups;

  /// Garde les fiches dont l'habitat ou la saison n'est pas renseigné, alors
  /// qu'on ne peut pas les comparer au critère d'habitat ou de saison choisi.
  final bool includeUnknown;

  /// Nombre de critères en cours (comestibilité, saison, habitat, type) ; la
  /// recherche par nom n'en fait pas partie.
  int get criteriaCount =>
      (edibilities.isNotEmpty ? 1 : 0) +
      (month != null ? 1 : 0) +
      (habitats.isNotEmpty ? 1 : 0) +
      (groups.isNotEmpty ? 1 : 0);

  bool get hasCriteria => criteriaCount > 0;

  /// Vrai dès que la liste est restreinte, par un critère ou par la recherche.
  bool get isNarrowed => hasCriteria || query.trim().isNotEmpty;

  /// Copie modifiée. [clearMonth] retire le critère de saison.
  SpeciesFilters copyWith({
    String? query,
    Set<Edibility>? edibilities,
    int? month,
    bool clearMonth = false,
    Set<HabitatFamily>? habitats,
    Set<MushroomGroup>? groups,
    bool? includeUnknown,
  }) {
    final newMonth = clearMonth ? null : (month ?? this.month);
    final newHabitats = habitats ?? this.habitats;
    return SpeciesFilters(
      query: query ?? this.query,
      edibilities: edibilities ?? this.edibilities,
      month: newMonth,
      habitats: newHabitats,
      groups: groups ?? this.groups,
      // Sans critère d'habitat ni de saison, il n'y a plus rien à comparer.
      includeUnknown:
          (newMonth != null || newHabitats.isNotEmpty) && (includeUnknown ?? this.includeUnknown),
    );
  }

  /// Les critères en cours, en clair : « Toxique ou Mortel · En octobre ».
  List<String> get summary => [
        if (edibilities.isNotEmpty)
          [
            for (final e in Edibility.values)
              if (edibilities.contains(e)) e.label,
          ].join(' ou '),
        if (month case final m?) 'En ${monthNames[m - 1]}',
        if (habitats.isNotEmpty)
          [
            for (final h in HabitatFamily.values)
              if (habitats.contains(h)) h.label,
          ].join(' ou '),
        if (groups.isNotEmpty)
          [
            for (final g in MushroomGroup.values)
              if (groups.contains(g)) g.label,
          ].join(' ou '),
      ];
}

/// Résultat de [applyFilters].
class FilterOutcome {
  const FilterOutcome({required this.shown, required this.unknown});

  /// Espèces à afficher, dans l'ordre de la liste d'origine.
  final List<Species> shown;

  /// Fiches qui répondent aux autres critères mais dont l'habitat ou la saison
  /// n'est pas renseigné : écartées tant que [SpeciesFilters.includeUnknown] est
  /// faux, affichées (et comptées ici) quand il est vrai.
  final int unknown;
}

enum _Verdict { no, yes, unknownOnly }

_Verdict _verdict(Species species, SpeciesFilters filters) {
  if (!matchesQuery(species, filters.query)) return _Verdict.no;
  if (filters.edibilities.isNotEmpty && !filters.edibilities.contains(species.edibility)) {
    return _Verdict.no;
  }
  if (filters.groups.isNotEmpty && !filters.groups.contains(groupOfSpecies(species.id))) {
    return _Verdict.no;
  }

  var relyOnUnknown = false;
  final month = filters.month;
  if (month != null) {
    final inSeason = speciesInSeason(species, month);
    if (inSeason == false) return _Verdict.no;
    if (inSeason == null) relyOnUnknown = true;
  }
  if (filters.habitats.isNotEmpty) {
    final families = habitatFamilies(species.habitat);
    if (families.isEmpty) {
      relyOnUnknown = true;
    } else if (!families.any(filters.habitats.contains)) {
      return _Verdict.no;
    }
  }
  return relyOnUnknown ? _Verdict.unknownOnly : _Verdict.yes;
}

/// Espèces de [all] qui passent [filters].
FilterOutcome applyFilters(Iterable<Species> all, SpeciesFilters filters) {
  final shown = <Species>[];
  var unknown = 0;
  for (final species in all) {
    final verdict = _verdict(species, filters);
    if (verdict == _Verdict.yes) {
      shown.add(species);
    } else if (verdict == _Verdict.unknownOnly) {
      unknown++;
      if (filters.includeUnknown) shown.add(species);
    }
  }
  return FilterOutcome(shown: shown, unknown: unknown);
}

/// Vrai si [query] figure dans le nom courant ou le nom latin de [species].
/// Une recherche vide laisse tout passer ; accents et majuscules sont ignorés.
bool matchesQuery(Species species, String query) {
  final wanted = foldAccents(query.trim());
  if (wanted.isEmpty) return true;
  final latin = species.scientificName;
  return foldAccents(species.commonName).contains(wanted) ||
      (latin != null && foldAccents(latin).contains(wanted));
}

/// Ordre alphabétique français : « Cèpe » se range avec les C, pas après les Z.
List<Species> sortedByName(Iterable<Species> species) => [...species]
  ..sort((a, b) {
    final byName = foldAccents(a.commonName).compareTo(foldAccents(b.commonName));
    return byName != 0 ? byName : a.id.compareTo(b.id);
  });

/// Nombre d'espèces par type de champignon (les types vides sont absents).
Map<MushroomGroup, int> groupCounts(Iterable<Species> all) {
  final counts = <MushroomGroup, int>{};
  for (final species in all) {
    counts.update(groupOfSpecies(species.id), (n) => n + 1, ifAbsent: () => 1);
  }
  return counts;
}

/// Nombre d'espèces par famille d'habitat (les familles vides sont absentes ;
/// une espèce comptée dans plusieurs familles figure dans chacune).
Map<HabitatFamily, int> habitatCounts(Iterable<Species> all) {
  final counts = <HabitatFamily, int>{};
  for (final species in all) {
    for (final family in habitatFamilies(species.habitat)) {
      counts.update(family, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return counts;
}
