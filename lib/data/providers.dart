import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/species/data/species_seed.dart';
import '../features/species/domain/species.dart';
import '../features/species/domain/species_groups.dart';
import 'database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final spotsProvider = StreamProvider<List<Spot>>(
  (ref) => ref.watch(databaseProvider).watchSpots(),
);

final outingsProvider = StreamProvider<List<Outing>>(
  (ref) => ref.watch(databaseProvider).watchOutings(),
);

final harvestsProvider = StreamProvider.family<List<Harvest>, String>(
  (ref, outingId) => ref.watch(databaseProvider).watchHarvests(outingId),
);

final outingProvider = StreamProvider.family<Outing?, String>(
  (ref, id) => ref.watch(databaseProvider).watchOuting(id),
);

/// Catalogue intégré + espèces ajoutées par l'utilisateur.
final allSpeciesProvider = StreamProvider<List<Species>>((ref) {
  return ref.watch(databaseProvider).watchCustomSpecies().map((rows) {
    final custom = rows.map(
      (r) => Species(
        id: r.id,
        commonName: r.commonName,
        description: r.description,
        photoPath: r.photoPath,
        // Statut de sécurité non vérifié : jamais présenté comme comestible.
        edibility: Edibility.inedible,
        isCustom: true,
      ),
    );
    return [...speciesSeed, ...custom];
  });
});

/// Recherche une espèce par identifiant (catalogue ou personnalisée).
final speciesByIdProvider = Provider.family<Species?, String>((ref, id) {
  final all = ref.watch(allSpeciesProvider).value;
  if (all == null) {
    for (final s in speciesSeed) {
      if (s.id == id) return s;
    }
    return null;
  }
  for (final s in all) {
    if (s.id == id) return s;
  }
  return null;
});

/// Total des récoltes d'une sortie (pièces et poids), pour la liste du carnet.
class OutingTotals {
  const OutingTotals({this.pieces = 0, this.grams = 0});

  final int pieces;
  final int grams;
}

final outingTotalsProvider = StreamProvider<Map<String, OutingTotals>>(
  (ref) => ref.watch(databaseProvider).watchAllHarvests().map((all) {
    final totals = <String, OutingTotals>{};
    for (final h in all) {
      final t = totals[h.outingId] ?? const OutingTotals();
      totals[h.outingId] = OutingTotals(
        pieces: t.pieces + (h.quantityCount ?? 0),
        grams: t.grams + (h.weightGrams ?? 0),
      );
    }
    return totals;
  }),
);

/// Historique des identifications par photo, de la plus récente à la plus ancienne.
final identificationsProvider = StreamProvider<List<Identification>>(
  (ref) => ref.watch(databaseProvider).watchIdentifications(),
);

/// Toutes les observations « espèce vue dans un coin » (SPOT-4).
final spotSpeciesProvider = StreamProvider<List<SpotSpeciesRow>>(
  (ref) => ref.watch(databaseProvider).watchSpotSpecies(),
);

/// Espèces observées par coin : identifiant du coin -> identifiants d'espèces.
final speciesBySpotProvider = Provider<Map<String, Set<String>>>((ref) {
  final map = <String, Set<String>>{};
  for (final row in ref.watch(spotSpeciesProvider).value ?? const <SpotSpeciesRow>[]) {
    (map[row.spotId] ??= {}).add(row.speciesId);
  }
  return map;
});

/// Types de champignons observés par coin : base du filtre « coins à cèpes ».
final groupsBySpotProvider = Provider<Map<String, Set<MushroomGroup>>>((ref) => {
      for (final e in ref.watch(speciesBySpotProvider).entries)
        e.key: groupsOfSpecies(e.value),
    });
