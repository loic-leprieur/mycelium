import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/data/database.dart';

// Schémas des versions précédentes, tels que Drift les créait.
const _v1 = '''
CREATE TABLE "spots" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "latitude" REAL NOT NULL, "longitude" REAL NOT NULL, "forest_type" TEXT NULL, "notes" TEXT NULL, "is_favorite" INTEGER NOT NULL DEFAULT 0 CHECK ("is_favorite" IN (0, 1)), "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "outings" ("id" TEXT NOT NULL, "spot_id" TEXT NULL, "started_at" INTEGER NOT NULL, "duration_min" INTEGER NULL, "notes" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "harvests" ("id" TEXT NOT NULL, "outing_id" TEXT NOT NULL, "species_id" TEXT NOT NULL, "quantity_count" INTEGER NULL, "notes" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "custom_species" ("id" TEXT NOT NULL, "common_name" TEXT NOT NULL, "description" TEXT NOT NULL DEFAULT '', "photo_path" TEXT NULL, "created_at" INTEGER NOT NULL, PRIMARY KEY ("id"));
''';

const _v2 = '''
CREATE TABLE "spots" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "latitude" REAL NOT NULL, "longitude" REAL NOT NULL, "forest_type" TEXT NULL, "notes" TEXT NULL, "is_favorite" INTEGER NOT NULL DEFAULT 0 CHECK ("is_favorite" IN (0, 1)), "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "outings" ("id" TEXT NOT NULL, "spot_id" TEXT NULL, "started_at" INTEGER NOT NULL, "duration_min" INTEGER NULL, "notes" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "harvests" ("id" TEXT NOT NULL, "outing_id" TEXT NOT NULL, "species_id" TEXT NOT NULL, "quantity_count" INTEGER NULL, "weight_grams" INTEGER NULL, "photo_path" TEXT NULL, "notes" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "custom_species" ("id" TEXT NOT NULL, "common_name" TEXT NOT NULL, "description" TEXT NOT NULL DEFAULT '', "photo_path" TEXT NULL, "created_at" INTEGER NOT NULL, PRIMARY KEY ("id"));
''';

const _v3Identifications = '''
CREATE TABLE "identifications" ("id" TEXT NOT NULL, "photo_path" TEXT NOT NULL, "model_version" TEXT NOT NULL, "top5_json" TEXT NOT NULL, "unknown_score" REAL NOT NULL DEFAULT 0.0, "chosen_species_id" TEXT NULL, "created_at" INTEGER NOT NULL, PRIMARY KEY ("id"));
''';

/// Données d'un utilisateur existant : un coin, deux sorties, des récoltes.
const _userData = '''
INSERT INTO spots VALUES ('s1', 'Coin des cèpes', 48.2, 7.3, 'Conifères', NULL, 1, 1760000000, 1760000000);
INSERT INTO spots VALUES ('s2', 'Sans sortie', 48.3, 7.4, NULL, NULL, 0, 1760000000, 1760000000);
INSERT INTO outings VALUES ('o1', 's1', 1761000000, 120, NULL);
INSERT INTO outings VALUES ('o2', 's1', 1762000000, 90, NULL);
INSERT INTO outings VALUES ('o3', NULL, 1763000000, 60, NULL);
''';

Future<List<String>> columns(AppDatabase db, String table) async => [
      for (final r in await db.customSelect('PRAGMA table_info("$table")').get())
        r.read<String>('name'),
    ];

DateTime at(int seconds) => DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

void main() {
  group('Migrations : les données existantes survivent', () {
    test('V2 -> V4 : récoltes déjà saisies => espèces observées dans le coin', () async {
      // Les récoltes existent AVANT la mise à jour.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
        raw.execute(_v2);
        raw.execute(_userData);
        raw.execute("INSERT INTO harvests VALUES ('h1', 'o1', 'cepe-de-bordeaux', 3, 800, NULL, NULL);");
        raw.execute("INSERT INTO harvests VALUES ('h2', 'o2', 'cepe-de-bordeaux', 2, NULL, NULL, NULL);");
        raw.execute("INSERT INTO harvests VALUES ('h3', 'o2', 'girolle', 5, NULL, NULL, NULL);");
        raw.execute("INSERT INTO harvests VALUES ('h4', 'o3', 'morille', 1, NULL, NULL, NULL);"); // sortie sans coin
        raw.execute('PRAGMA user_version = 2;');
      }));

      // Les données d'origine sont intactes.
      expect((await db.select(db.spots).get()).map((s) => s.name),
          containsAll(['Coin des cèpes', 'Sans sortie']));
      expect(await db.select(db.harvests).get(), hasLength(4));

      // Les récoltes de sorties rattachées à un coin alimentent ses espèces ;
      // la date retenue est celle de la dernière sortie.
      final seen = await db.select(db.spotSpecies).get();
      expect(seen.map((r) => '${r.spotId}/${r.speciesId}').toSet(),
          {'s1/cepe-de-bordeaux', 's1/girolle'});
      expect(
        seen.firstWhere((r) => r.speciesId == 'cepe-de-bordeaux').lastSeenAt,
        at(1762000000),
      );

      // Les nouvelles tables et colonnes sont utilisables.
      expect(await columns(db, 'identifications'),
          containsAll(['latitude', 'longitude', 'spot_id']));
      await db.setMeta('consent', 'oui');
      expect(await db.metaValue('consent'), 'oui');
      await db.close();
    });

    test('V1 -> V4 : même résultat depuis la toute première version', () async {
      final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
        raw.execute(_v1);
        raw.execute(_userData);
        raw.execute("INSERT INTO harvests VALUES ('h1', 'o1', 'girolle', 2, NULL);");
        raw.execute('PRAGMA user_version = 1;');
      }));
      final harvest = (await db.select(db.harvests).get()).single;
      expect(harvest.speciesId, 'girolle');
      expect(harvest.weightGrams, isNull);
      expect(await columns(db, 'harvests'), containsAll(['weight_grams', 'photo_path']));
      expect((await db.select(db.spotSpecies).get()).single.speciesId, 'girolle');
      await db.close();
    });

    test('V3 -> V4 : les identifications gardent leurs données, nouvelles colonnes vides', () async {
      final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
        raw.execute(_v2);
        raw.execute(_v3Identifications);
        raw.execute(_userData);
        raw.execute("INSERT INTO identifications VALUES ('i1', '/p/i1.jpg', 'v1', '[]', 0.4, 'girolle', 1764000000);");
        raw.execute('PRAGMA user_version = 3;');
      }));
      final row = (await db.select(db.identifications).get()).single;
      expect(row.id, 'i1');
      expect(row.chosenSpeciesId, 'girolle');
      expect(row.unknownScore, 0.4);
      expect(row.latitude, isNull);
      expect(row.longitude, isNull);
      expect(row.spotId, isNull);
      await db.close();
    });

    test('base neuve : toutes les tables sont créées', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = AppDatabase(NativeDatabase.memory());
      final tables = {
        for (final r in await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get())
          r.read<String>('name'),
      };
      expect(tables, containsAll([
        'spots', 'outings', 'harvests', 'custom_species',
        'identifications', 'spot_species', 'app_meta',
      ]));
      await db.close();
    });
  });

  group('Espèces observées par coin', () {
    late AppDatabase db;

    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    Future<void> spot(String id) => db.upsertSpot(SpotsCompanion.insert(
          id: id,
          name: 'Coin $id',
          latitude: 48,
          longitude: 7,
          createdAt: at(1760000000),
          updatedAt: at(1760000000),
        ));

    test('markSpeciesSeen garde la date la plus récente et ne recule jamais', () async {
      await spot('s1');
      await db.markSpeciesSeen('s1', 'girolle', at(1762000000));
      await db.markSpeciesSeen('s1', 'girolle', at(1761000000)); // plus ancienne
      var rows = await db.select(db.spotSpecies).get();
      expect(rows.single.lastSeenAt, at(1762000000));

      await db.markSpeciesSeen('s1', 'girolle', at(1763000000)); // plus récente
      rows = await db.select(db.spotSpecies).get();
      expect(rows, hasLength(1));
      expect(rows.single.lastSeenAt, at(1763000000));
    });

    test('unmarkSpecies retire une espèce du coin', () async {
      await spot('s1');
      await db.markSpeciesSeen('s1', 'girolle', at(1762000000));
      await db.markSpeciesSeen('s1', 'morille', at(1762000000));
      await db.unmarkSpecies('s1', 'girolle');
      expect((await db.select(db.spotSpecies).get()).single.speciesId, 'morille');
    });

    test('une récolte dans une sortie rattachée à un coin marque l\'espèce', () async {
      await spot('s1');
      await db.upsertOuting(OutingsCompanion.insert(
          id: 'o1', spotId: const Value('s1'), startedAt: at(1762000000)));
      await db.upsertOuting(OutingsCompanion.insert(id: 'o2', startedAt: at(1763000000)));

      await db.addHarvest(HarvestsCompanion.insert(
          id: 'h1', outingId: 'o1', speciesId: 'cepe-de-bordeaux'));
      await db.addHarvest(HarvestsCompanion.insert(
          id: 'h2', outingId: 'o2', speciesId: 'morille')); // pas de coin

      final rows = await db.select(db.spotSpecies).get();
      expect(rows.single.spotId, 's1');
      expect(rows.single.speciesId, 'cepe-de-bordeaux');
      expect(rows.single.lastSeenAt, at(1762000000));
    });

    test('supprimer un coin supprime ses espèces et détache ses identifications', () async {
      await spot('s1');
      await db.markSpeciesSeen('s1', 'girolle', at(1762000000));
      await db.addIdentification(IdentificationsCompanion.insert(
        id: 'i1',
        photoPath: 'identification_photos/i1.jpg',
        modelVersion: 'v1',
        top5Json: '[]',
        createdAt: at(1762000000),
        spotId: const Value('s1'),
        latitude: const Value(48.2),
        longitude: const Value(7.3),
      ));

      await db.deleteSpot('s1');

      expect(await db.select(db.spotSpecies).get(), isEmpty);
      final ident = await db.identificationById('i1');
      expect(ident, isNotNull, reason: 'l\'identification et sa photo sont conservées');
      expect(ident!.spotId, isNull);
      expect(ident.latitude, 48.2, reason: 'la position de la trouvaille est conservée');
    });
  });

  group('Identifications et valeurs persistantes', () {
    late AppDatabase db;

    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('corriger l\'espèce retenue ne touche pas au résultat du modèle (RM-3)', () async {
      await db.addIdentification(IdentificationsCompanion.insert(
        id: 'i1',
        photoPath: 'identification_photos/i1.jpg',
        modelVersion: 'v1',
        top5Json: '[{"id":"girolle","score":0.7}]',
        createdAt: at(1762000000),
        chosenSpeciesId: const Value('girolle'),
      ));
      await db.setIdentificationSpecies('i1', 'fausse-girolle');
      var row = (await db.identificationById('i1'))!;
      expect(row.chosenSpeciesId, 'fausse-girolle');
      expect(row.top5Json, '[{"id":"girolle","score":0.7}]');

      await db.setIdentificationSpecies('i1', null); // « Je ne sais pas »
      row = (await db.identificationById('i1'))!;
      expect(row.chosenSpeciesId, isNull);
    });

    test('suppression d\'une identification', () async {
      await db.addIdentification(IdentificationsCompanion.insert(
        id: 'i1',
        photoPath: 'p.jpg',
        modelVersion: 'v1',
        top5Json: '[]',
        createdAt: at(1762000000),
      ));
      await db.deleteIdentification('i1');
      expect(await db.identificationById('i1'), isNull);
    });

    test('valeurs persistantes : lecture, écriture, remplacement', () async {
      expect(await db.metaValue('consent_version'), isNull);
      await db.setMeta('consent_version', '1');
      await db.setMeta('consent_version', '2');
      expect(await db.metaValue('consent_version'), '2');
    });
  });
}
