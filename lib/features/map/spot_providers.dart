import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/group_filter.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../species/domain/species_groups.dart';
import 'location.dart';
import 'spot_filter.dart';
import 'spot_visits.dart';

/// Tri choisi pour la liste des coins. Par défaut : les plus proches d'abord.
class SpotSortChoice extends Notifier<SpotSort> {
  @override
  SpotSort build() => SpotSort.distance;

  void choose(SpotSort sort) => state = sort;
}

final spotSortProvider =
    NotifierProvider<SpotSortChoice, SpotSort>(SpotSortChoice.new);

/// Filtre « Favoris » de la liste et de la carte des coins.
class FavoritesOnly extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void reset() => state = false;
}

final spotFavoritesOnlyProvider =
    NotifierProvider<FavoritesOnly, bool>(FavoritesOnly.new);

/// Date de la dernière sortie de chaque coin ; null tant que le carnet se charge
/// (pour ne pas afficher « Jamais visité » à tort).
final lastVisitBySpotProvider = Provider<Map<String, DateTime>?>((ref) {
  final outings = ref.watch(outingsProvider).value;
  return outings == null ? null : lastVisitBySpot(outings);
});

/// Nombre de coins par type de champignon (pastilles du filtre).
final spotGroupCountsProvider = Provider<Map<MushroomGroup, int>>(
  (ref) => spotGroupCounts(
    ref.watch(spotsProvider).value ?? const <Spot>[],
    ref.watch(groupsBySpotProvider),
  ),
);

/// Coins à afficher, dans l'ordre choisi : ce que montrent la liste ET la carte.
final spotEntriesProvider = Provider<List<SpotEntry>>(
  (ref) => filterAndSortSpots(
    spots: ref.watch(spotsProvider).value ?? const <Spot>[],
    groupsBySpot: ref.watch(groupsBySpotProvider),
    lastVisits: ref.watch(lastVisitBySpotProvider) ?? const {},
    here: ref.watch(locationProvider.select((l) => l.value?.latLng)),
    groups: ref.watch(mapGroupFilterProvider),
    favoritesOnly: ref.watch(spotFavoritesOnlyProvider),
    sort: ref.watch(spotSortProvider),
  ),
);
