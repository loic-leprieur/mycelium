import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Un « coin à champignons ». Reste uniquement sur l'appareil (RM-7).
class Spots extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get forestType => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Outings extends Table {
  TextColumn get id => text()();
  TextColumn get spotId => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationMin => integer().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Harvests extends Table {
  TextColumn get id => text()();
  TextColumn get outingId => text()();
  // Identifiant d'une espèce du catalogue ou d'une espèce personnalisée.
  TextColumn get speciesId => text()();
  IntColumn get quantityCount => integer().nullable()();
  // Poids total de la récolte, en grammes.
  IntColumn get weightGrams => integer().nullable()();
  // Photo de la récolte (fichier copié dans le dossier de l'application).
  TextColumn get photoPath => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Espèces ajoutées par l'utilisateur (ENC-7). Sans statut de sécurité vérifié.
@DataClassName('CustomSpeciesRow')
class CustomSpecies extends Table {
  TextColumn get id => text()();
  TextColumn get commonName => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Résultat d'une identification par photo (cahier des charges §8). Conservé
/// séparément de l'espèce que l'utilisateur retient (RM-3 : traçabilité).
class Identifications extends Table {
  TextColumn get id => text()();
  // Photo copiée dans le dossier de l'application.
  TextColumn get photoPath => text()();
  // Version du modèle et des classes qui ont produit le résultat.
  TextColumn get modelVersion => text()();
  // Top 5 du modèle : [{"id": "girolle", "score": 0.81}, ...].
  TextColumn get top5Json => text()();
  // Probabilité d'une espèce absente de la base (0–1).
  RealColumn get unknownScore => real().withDefault(const Constant(0))();
  // Espèce retenue par l'utilisateur ; null = « Je ne sais pas ».
  TextColumn get chosenSpeciesId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  // Position où la photo a été prise (appareil photo) ; null si inconnue.
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  // Coin auquel l'identification est rattachée (null = aucun).
  TextColumn get spotId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Espèces observées dans un coin (SPOT-4). Alimentée par les identifications
/// confirmées et les récoltes des sorties rattachées au coin, ou saisie à la main.
/// C'est elle qu'on filtre pour retrouver « les coins à cèpes ».
@DataClassName('SpotSpeciesRow')
class SpotSpecies extends Table {
  TextColumn get spotId => text()();
  TextColumn get speciesId => text()();
  DateTimeColumn get lastSeenAt => dateTime()();

  @override
  Set<Column> get primaryKey => {spotId, speciesId};
}

/// Petites valeurs persistantes : consentement, versions… (cahier des charges §8).
@DataClassName('AppMetaRow')
class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [Spots, Outings, Harvests, CustomSpecies, Identifications, SpotSpecies, AppMeta],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'mycelium'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // V2 : poids et photo des récoltes.
            await m.addColumn(harvests, harvests.weightGrams);
            await m.addColumn(harvests, harvests.photoPath);
          }
          if (from < 3) {
            // V3 : historique des identifications par photo. createTable crée
            // déjà la dernière définition (avec les colonnes de la V4).
            await m.createTable(identifications);
          }
          if (from == 3) {
            // V4 : position et coin des identifications.
            await m.addColumn(identifications, identifications.latitude);
            await m.addColumn(identifications, identifications.longitude);
            await m.addColumn(identifications, identifications.spotId);
          }
          if (from < 4) {
            // V4 : espèces observées par coin, et valeurs persistantes.
            await m.createTable(spotSpecies);
            await m.createTable(appMeta);
            // Reprend les récoltes déjà saisies : un coin « à cèpes » le reste
            // après la mise à jour.
            await customStatement('''
              INSERT OR REPLACE INTO spot_species (spot_id, species_id, last_seen_at)
              SELECT o.spot_id, h.species_id, MAX(o.started_at)
              FROM harvests h JOIN outings o ON o.id = h.outing_id
              WHERE o.spot_id IS NOT NULL
              GROUP BY o.spot_id, h.species_id
            ''');
          }
        },
      );

  // --- Coins ---
  Stream<List<Spot>> watchSpots() => (select(spots)
        ..orderBy([
          (t) => OrderingTerm.desc(t.isFavorite),
          (t) => OrderingTerm.asc(t.name),
        ]))
      .watch();

  Future<Spot?> spotById(String id) =>
      (select(spots)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertSpot(SpotsCompanion spot) =>
      into(spots).insertOnConflictUpdate(spot);

  Future<void> deleteSpot(String id) => transaction(() async {
        await (update(outings)..where((t) => t.spotId.equals(id)))
            .write(const OutingsCompanion(spotId: Value(null)));
        await (update(identifications)..where((t) => t.spotId.equals(id)))
            .write(const IdentificationsCompanion(spotId: Value(null)));
        await (delete(spotSpecies)..where((t) => t.spotId.equals(id))).go();
        await (delete(spots)..where((t) => t.id.equals(id))).go();
      });

  // --- Sorties ---
  Stream<List<Outing>> watchOutings() => (select(outings)
        ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
      .watch();

  Stream<Outing?> watchOuting(String id) =>
      (select(outings)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<void> upsertOuting(OutingsCompanion outing) =>
      into(outings).insertOnConflictUpdate(outing);

  Future<void> deleteOuting(String id) => transaction(() async {
        await (delete(harvests)..where((t) => t.outingId.equals(id))).go();
        await (delete(outings)..where((t) => t.id.equals(id))).go();
      });

  // --- Récoltes ---
  Stream<List<Harvest>> watchHarvests(String outingId) =>
      (select(harvests)..where((t) => t.outingId.equals(outingId))).watch();

  Stream<List<Harvest>> watchAllHarvests() => select(harvests).watch();

  /// Ajoute une récolte. Si la sortie est rattachée à un coin, l'espèce y est
  /// aussi marquée comme observée (SPOT-4).
  Future<void> addHarvest(HarvestsCompanion harvest) => transaction(() async {
        await into(harvests).insert(harvest);
        final outing = await (select(outings)
              ..where((t) => t.id.equals(harvest.outingId.value)))
            .getSingleOrNull();
        final spotId = outing?.spotId;
        if (outing != null && spotId != null) {
          await markSpeciesSeen(spotId, harvest.speciesId.value, outing.startedAt);
        }
      });

  Future<void> deleteHarvest(String id) =>
      (delete(harvests)..where((t) => t.id.equals(id))).go();

  // --- Espèces observées par coin (SPOT-4) ---
  Stream<List<SpotSpeciesRow>> watchSpotSpecies() => select(spotSpecies).watch();

  /// Marque [speciesId] comme observée dans le coin [spotId] à la date [at].
  /// Ne recule jamais la date de dernière observation.
  Future<void> markSpeciesSeen(String spotId, String speciesId, DateTime at) =>
      transaction(() async {
        final existing = await (select(spotSpecies)
              ..where((t) => t.spotId.equals(spotId) & t.speciesId.equals(speciesId)))
            .getSingleOrNull();
        if (existing != null && !at.isAfter(existing.lastSeenAt)) return;
        await into(spotSpecies).insertOnConflictUpdate(
          SpotSpeciesCompanion.insert(spotId: spotId, speciesId: speciesId, lastSeenAt: at),
        );
      });

  Future<void> unmarkSpecies(String spotId, String speciesId) =>
      (delete(spotSpecies)
            ..where((t) => t.spotId.equals(spotId) & t.speciesId.equals(speciesId)))
          .go();

  // --- Valeurs persistantes ---
  Future<String?> metaValue(String key) async => (await (select(appMeta)
            ..where((t) => t.key.equals(key)))
          .getSingleOrNull())
      ?.value;

  Future<void> setMeta(String key, String value) => into(appMeta)
      .insertOnConflictUpdate(AppMetaCompanion.insert(key: key, value: value));

  // --- Identifications ---
  Future<void> addIdentification(IdentificationsCompanion row) =>
      into(identifications).insert(row);

  Future<Identification?> identificationById(String id) =>
      (select(identifications)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Corrige l'espèce retenue par l'utilisateur (null = « Je ne sais pas »).
  Future<void> setIdentificationSpecies(String id, String? speciesId) =>
      (update(identifications)..where((t) => t.id.equals(id)))
          .write(IdentificationsCompanion(chosenSpeciesId: Value(speciesId)));

  Future<void> deleteIdentification(String id) =>
      (delete(identifications)..where((t) => t.id.equals(id))).go();

  Stream<List<Identification>> watchIdentifications() => (select(identifications)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  // --- Espèces personnalisées ---
  Stream<List<CustomSpeciesRow>> watchCustomSpecies() => (select(customSpecies)
        ..orderBy([(t) => OrderingTerm.asc(t.commonName)]))
      .watch();

  Future<void> upsertCustomSpecies(CustomSpeciesCompanion species) =>
      into(customSpecies).insertOnConflictUpdate(species);

  /// Supprime une espèce perso et ses observations dans les coins.
  Future<void> deleteCustomSpecies(String id) => transaction(() async {
        await (delete(spotSpecies)..where((t) => t.speciesId.equals(id))).go();
        await (delete(customSpecies)..where((t) => t.id.equals(id))).go();
      });
}
