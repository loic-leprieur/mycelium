import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/species/data/species_seed.dart';
import '../features/species/domain/species.dart';
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
