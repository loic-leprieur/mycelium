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

@DriftDatabase(tables: [Spots, Outings, Harvests, CustomSpecies])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'mycelium'));

  @override
  int get schemaVersion => 1;

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

  Future<void> addHarvest(HarvestsCompanion harvest) =>
      into(harvests).insert(harvest);

  Future<void> deleteHarvest(String id) =>
      (delete(harvests)..where((t) => t.id.equals(id))).go();

  // --- Espèces personnalisées ---
  Stream<List<CustomSpeciesRow>> watchCustomSpecies() => (select(customSpecies)
        ..orderBy([(t) => OrderingTerm.asc(t.commonName)]))
      .watch();

  Future<void> upsertCustomSpecies(CustomSpeciesCompanion species) =>
      into(customSpecies).insertOnConflictUpdate(species);

  Future<void> deleteCustomSpecies(String id) =>
      (delete(customSpecies)..where((t) => t.id.equals(id))).go();
}
