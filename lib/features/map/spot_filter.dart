import 'package:latlong2/latlong.dart';

import '../../data/database.dart';
import '../species/domain/species_groups.dart';
import 'geo.dart';

/// Critère de tri de la liste des coins (SPOT-6).
enum SpotSort {
  distance('Distance', 'Distance (les plus proches)'),
  name('Nom', 'Nom (de A à Z)'),
  lastVisit('Dernière visite', 'Dernière visite (les plus récentes)');

  const SpotSort(this.label, this.menuLabel);

  /// Libellé court, affiché sur le bouton de tri.
  final String label;

  /// Libellé complet, affiché dans le menu.
  final String menuLabel;
}

/// Un coin avec ce qu'il faut pour l'afficher, le filtrer et le trier.
class SpotEntry {
  const SpotEntry({
    required this.spot,
    this.distance,
    this.groups = const {},
    this.lastVisit,
  });

  final Spot spot;

  /// Distance à vol d'oiseau (m) ; null tant que la position est inconnue.
  final double? distance;

  /// Types de champignons observés dans ce coin.
  final Set<MushroomGroup> groups;

  /// Date de la sortie la plus récente à ce coin ; null = jamais visité.
  final DateTime? lastVisit;
}

/// Nombre de coins où chaque type a été observé. Un coin sans aucune
/// observation n'est compté dans aucun type.
Map<MushroomGroup, int> spotGroupCounts(
  Iterable<Spot> spots,
  Map<String, Set<MushroomGroup>> groupsBySpot,
) {
  final counts = <MushroomGroup, int>{};
  for (final spot in spots) {
    for (final group in groupsBySpot[spot.id] ?? const <MushroomGroup>{}) {
      counts[group] = (counts[group] ?? 0) + 1;
    }
  }
  return counts;
}

/// Tri réellement appliqué : sans position GPS, « Distance » retombe sur le nom.
SpotSort effectiveSort(SpotSort sort, {required bool hasPosition}) =>
    sort == SpotSort.distance && !hasPosition ? SpotSort.name : sort;

/// Applique les filtres puis le tri à la liste des coins.
///
/// - [groups] : types de champignons (vide = tous ; plusieurs = OU) ; un coin
///   sans observation n'appartient à aucun type ;
/// - [favoritesOnly] : ne garde que les favoris, en plus du filtre par type ;
/// - [here] : position actuelle, qui donne les distances.
List<SpotEntry> filterAndSortSpots({
  required Iterable<Spot> spots,
  Map<String, Set<MushroomGroup>> groupsBySpot = const {},
  Map<String, DateTime> lastVisits = const {},
  LatLng? here,
  Set<MushroomGroup> groups = const {},
  bool favoritesOnly = false,
  SpotSort sort = SpotSort.distance,
}) {
  final entries = <SpotEntry>[];
  for (final spot in spots) {
    if (favoritesOnly && !spot.isFavorite) continue;
    final observed = groupsBySpot[spot.id] ?? const <MushroomGroup>{};
    if (groups.isNotEmpty && !observed.any(groups.contains)) continue;
    entries.add(SpotEntry(
      spot: spot,
      distance: here == null
          ? null
          : metersBetween(here, LatLng(spot.latitude, spot.longitude)),
      groups: observed,
      lastVisit: lastVisits[spot.id],
    ));
  }

  // Les égalités se départagent toujours par le nom puis l'identifiant : le
  // tri de Dart n'est pas stable, l'ordre doit pourtant rester reproductible.
  int byName(SpotEntry a, SpotEntry b) {
    final c = foldText(a.spot.name).compareTo(foldText(b.spot.name));
    return c != 0 ? c : a.spot.id.compareTo(b.spot.id);
  }

  int byDistance(SpotEntry a, SpotEntry b) {
    final da = a.distance;
    final db = b.distance;
    if (da == null || db == null) return byName(a, b);
    final c = da.compareTo(db);
    return c != 0 ? c : byName(a, b);
  }

  int byLastVisit(SpotEntry a, SpotEntry b) {
    final va = a.lastVisit;
    final vb = b.lastVisit;
    if (va == null && vb == null) return byName(a, b);
    if (va == null) return 1; // jamais visité : en fin de liste
    if (vb == null) return -1;
    final c = vb.compareTo(va); // les plus récents d'abord
    return c != 0 ? c : byName(a, b);
  }

  entries.sort(switch (effectiveSort(sort, hasPosition: here != null)) {
    SpotSort.distance => byDistance,
    SpotSort.name => byName,
    SpotSort.lastVisit => byLastVisit,
  });
  return entries;
}

/// Titre du panneau des coins : « Mes coins (5) » sans filtre ; avec un filtre,
/// le nombre de coins correspondants et les types, par exemple
/// « Coins à cèpes ou chanterelles (3) » ou « Coins favoris à morilles (1) ».
String spotListTitle({
  required int count,
  Set<MushroomGroup> groups = const {},
  bool favoritesOnly = false,
}) {
  if (groups.isEmpty) {
    return favoritesOnly ? 'Mes coins favoris ($count)' : 'Mes coins ($count)';
  }
  final names = [
    for (final g in MushroomGroup.values)
      if (groups.contains(g)) g.label.toLowerCase(),
  ];
  final types = names.length == 1
      ? names.single
      : '${names.take(names.length - 1).join(', ')} ou ${names.last}';
  return '${favoritesOnly ? 'Coins favoris' : 'Coins'} à $types ($count)';
}

/// Types observés sur une ligne : « Cèpes · Chanterelles » (ordre du filtre).
String groupsLine(Set<MushroomGroup> groups) => [
      for (final g in MushroomGroup.values)
        if (groups.contains(g)) g.label,
    ].join(' · ');

const _accentFolds = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'æ': 'ae', 'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'œ': 'oe',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ÿ': 'y', 'ñ': 'n',
};

/// Minuscules sans accents : « Étang » se range avec les E, et la recherche
/// « cepe » retrouve « Cèpe ».
String foldText(String text) => text
    .trim()
    .toLowerCase()
    .split('')
    .map((c) => _accentFolds[c] ?? c)
    .join();
