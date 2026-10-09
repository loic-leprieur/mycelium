import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show ResultSetImplementation;
import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/data/backup/backup_format.dart';
import 'package:mycelium/data/backup/backup_service.dart';
import 'package:mycelium/data/database.dart';
import 'package:path/path.dart' as p;

import 'backup_support.dart';

void main() {
  late Install a; // appareil d'origine
  late Install b; // appareil neuf

  setUp(() async {
    a = await Install.create();
    b = await Install.create();
    a.use();
    await seed(a);
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  final now = DateTime(2026, 10, 9, 14, 30);

  test('aller-retour : archive nommée par date, lignes et photos identiques', () async {
    final archive = await a.service().createArchive(outputDir: a.work, now: now);
    expect(archive.fileName, 'mycelium-sauvegarde-2026-10-09.zip');
    expect(archive.counts.spots, 2);
    expect(archive.counts.photos, 5);
    expect(archive.missingPhotos, 0);

    final entries = {for (final f in ZipDecoder().decodeBytes(archive.file.readAsBytesSync())) f.name};
    expect(entries, containsAll([
      'manifest.json', 'data.json',
      'photos/harvest_photos/h1.jpg', 'photos/harvest_photos/h2.jpg', 'photos/harvest_photos/h3.jpg',
      'photos/species_photos/c1.jpg', 'photos/identification_photos/i1.jpg',
    ]));

    final preview = await b.service().inspect(archive.file);
    expect(preview.counts.describe(), '2 coins, 1 sortie, 3 récoltes, 1 identification, 1 espèce personnelle, 5 photos');
    expect(preview.schemaVersion, a.db.schemaVersion);

    final report = await b.service().restore(archive.file);
    expect(report.added.spots, 2);
    expect(report.photosCopied, 5);

    final fromA = await tables(a.db);
    final fromB = await tables(b.db);
    for (final name in ['spots', 'outings', 'customSpecies', 'identifications', 'spotSpecies']) {
      expect(fromB[name].toString(), fromA[name].toString(), reason: name);
    }
    // Photos : mêmes octets, mêmes chemins relatifs (y compris les anciens chemins absolus).
    final harvests = {for (final h in await b.db.select(b.db.harvests).get()) h.id: h.photoPath};
    expect(harvests, {
      'h1': 'harvest_photos/h1.jpg',
      'h2': 'harvest_photos/h2.jpg',
      'h3': 'harvest_photos/h3.jpg',
    });
    expect(tree(b.docs), tree(a.docs));

    // Le consentement ne voyage pas ; les autres réglages, si.
    final meta = {for (final r in await b.db.select(b.db.appMeta).get()) r.key: r.value};
    expect(meta.keys.where(isConsentKey), isEmpty);
    expect(meta['text_scale'], '1.3');
    expect(await b.service().lastBackupAt(), archive.createdAt);
  });

  test('photo introuvable : exportée sans erreur et signalée', () async {
    a.photo('harvest_photos/h1.jpg').deleteSync();
    final archive = await a.service().createArchive(outputDir: a.work, now: now);
    expect(archive.missingPhotos, 1);
    expect(archive.counts.photos, 4);
    final report = await b.service().restore(archive.file);
    expect(report.photosCopied, 4);
    expect((await b.db.select(b.db.harvests).get()).length, 3);
  });

  test('une nouvelle archive remplace la précédente du dossier de travail', () async {
    await a.service().createArchive(outputDir: a.work, now: now);
    await a.service().createArchive(outputDir: a.work, now: now.add(const Duration(days: 1)));
    expect(a.work.listSync().map((e) => p.basename(e.path)), ['mycelium-sauvegarde-2026-10-10.zip']);
  });

  test('fusion : ne supprime ni ne modifie rien, ajoute le reste', () async {
    final archive = await a.service().createArchive(outputDir: a.work, now: now);

    // L'appareil neuf a déjà son propre coin, une version modifiée de s1, un réglage.
    b.use();
    await b.db.upsertSpot(SpotsCompanion.insert(
        id: 's1', name: 'Renommé ici', latitude: 1, longitude: 2, createdAt: t0, updatedAt: t0));
    await b.db.upsertSpot(SpotsCompanion.insert(
        id: 'local', name: 'Coin local', latitude: 3, longitude: 4, createdAt: t0, updatedAt: t0));
    b.writePhoto('harvest_photos/local.jpg', bytesOf(9));
    b.writePhoto('harvest_photos/h1.jpg', bytesOf(77)); // existe déjà : jamais écrasée
    await b.db.markSpeciesSeen('s2', 'morille', DateTime.utc(2026, 11, 1)); // plus récent que l'archive
    await b.db.setMeta('text_scale', '2.0');
    await b.db.setMeta('consent_version', '9');
    await b.db.setMeta(lastBackupKey, '2026-09-01T00:00:00.000Z');

    final report = await b.service().restore(archive.file);
    expect(report.added.spots, 1); // s2
    expect(report.alreadyPresent.spots, 1); // s1
    expect(report.photosCopied, 4);

    final spots = {for (final s in await b.db.select(b.db.spots).get()) s.id: s.name};
    expect(spots, {'s1': 'Renommé ici', 's2': 'Sans sortie', 'local': 'Coin local'});
    expect(b.photo('harvest_photos/h1.jpg').readAsBytesSync(), bytesOf(77));
    expect(b.photo('harvest_photos/local.jpg').existsSync(), isTrue);
    expect(b.photo('harvest_photos/h2.jpg').readAsBytesSync(), bytesOf(2));

    // Date d'observation la plus récente conservée.
    final seen = (await b.db.select(b.db.spotSpecies).get())
        .singleWhere((r) => r.spotId == 's2' && r.speciesId == 'morille');
    expect(seen.lastSeenAt.toUtc(), DateTime.utc(2026, 11, 1));
    final meta = {for (final r in await b.db.select(b.db.appMeta).get()) r.key: r.value};
    expect(meta['text_scale'], '2.0');
    expect(meta['consent_version'], '9');
    // La base n'était pas vide : l'archive n'est pas « la dernière sauvegarde ».
    expect(meta[lastBackupKey], '2026-09-01T00:00:00.000Z');

    // Deuxième fusion identique : plus rien à ajouter.
    final again = await b.service().restore(archive.file);
    expect(again.added.userItems, 0);
    expect(again.photosCopied, 0);
  });

  test('remplacement : efface données et photos actuelles, garde le consentement', () async {
    final archive = await a.service().createArchive(outputDir: a.work, now: now);
    b.use();
    await b.db.upsertSpot(SpotsCompanion.insert(
        id: 'local', name: 'Coin local', latitude: 3, longitude: 4, createdAt: t0, updatedAt: t0));
    b.writePhoto('harvest_photos/local.jpg', bytesOf(9));
    await b.db.setMeta('consent_version', '9');
    await b.db.setMeta('autre', 'x');

    final report = await b.service().restore(archive.file, mode: RestoreMode.replace);
    expect(report.added.spots, 2);

    expect((await b.db.select(b.db.spots).get()).map((s) => s.id).toSet(), {'s1', 's2'});
    expect(b.photo('harvest_photos/local.jpg').existsSync(), isFalse);
    expect(tree(b.docs), tree(a.docs));
    expect(b.docs.listSync().map((e) => p.basename(e.path)).where((n) => n.startsWith('.')), isEmpty);
    final meta = {for (final r in await b.db.select(b.db.appMeta).get()) r.key: r.value};
    expect(meta['consent_version'], '9');
    expect(meta.containsKey('autre'), isFalse);
    expect(await b.service().lastBackupAt(), archive.createdAt);
  });

  test('un consentement glissé dans l\'archive est ignoré', () async {
    final archive = await a.service().createArchive(outputDir: a.work, now: now);
    final forged = rewrite(archive.file, (e) {
      final data = jsonEntry(e, 'data.json');
      (data['appMeta']! as Map<String, Object?>)['consent_accepted_at'] = 'faux';
      final manifest = jsonEntry(e, 'manifest.json');
      (manifest['counts']! as Map<String, Object?>)['appMeta'] = (data['appMeta']! as Map).length - 1;
      return {...e, 'data.json': jsonBytes(data), 'manifest.json': jsonBytes(manifest)};
    });
    await b.service().restore(forged);
    expect(await b.db.metaValue('consent_accepted_at'), isNull);
  });

  test('un échec en base annule tout : base et photos inchangées', () async {
    final archive = await a.service().createArchive(outputDir: a.work, now: now);
    b.use();
    await b.db.upsertSpot(SpotsCompanion.insert(
        id: 'local', name: 'Coin local', latitude: 3, longitude: 4, createdAt: t0, updatedAt: t0));
    b.writePhoto('harvest_photos/local.jpg', bytesOf(9));
    // Une table manquante fait échouer l'écriture, après la mise en place des photos.
    await b.db.customStatement('DROP TABLE identifications');
    final dbBefore = {
      'spots': await b.db.select(b.db.spots).get(),
    };
    final filesBefore = tree(b.docs);

    for (final mode in RestoreMode.values) {
      await expectLater(
        b.service().restore(archive.file, mode: mode),
        throwsA(isA<BackupException>().having((e) => e.kind, 'kind', BackupErrorKind.failed)),
      );
      expect((await b.db.select(b.db.spots).get()).toString(), dbBefore['spots'].toString());
      final after = tree(b.docs);
      expect(after.keys.toSet(), filesBefore.keys.toSet());
    }
  });

  test('suppression totale : tables vides, dossiers supprimés, consentement effacé', () async {
    final archive = await a.service().createArchive(outputDir: a.work, now: now);
    await a.service().markBackupDone(now);
    await a.service().deleteEverything(archiveDir: a.work);

    final all = await tables(a.db);
    for (final e in all.entries) {
      expect(e.value, isEmpty, reason: e.key);
    }
    for (final folder in photoFolders) {
      expect(Directory(p.join(a.docs.path, folder)).existsSync(), isFalse, reason: folder);
    }
    expect(archive.file.existsSync(), isFalse);
    expect(await a.db.metaValue('consent_accepted_at'), isNull);
    expect(await a.service().lastBackupAt(), isNull);
    // L'application est utilisable ensuite.
    await a.db.upsertSpot(SpotsCompanion.insert(
        id: 'n', name: 'Neuf', latitude: 1, longitude: 2, createdAt: t0, updatedAt: t0));
    expect(await a.db.select(a.db.spots).get(), hasLength(1));
  });

  test('le schéma des tables est entièrement exporté (garde contre un oubli)', () async {
    final archive = await a.service().createArchive(outputDir: a.work, now: now);
    final data = jsonEntry({
      for (final f in ZipDecoder().decodeBytes(archive.file.readAsBytesSync())) f.name: f.readBytes()!,
    }, 'data.json');
    String camel(String s) => s.replaceAllMapped(RegExp('_([a-z])'), (m) => m[1]!.toUpperCase());
    final tablesByKey = <String, ResultSetImplementation>{
      'spots': a.db.spots,
      'outings': a.db.outings,
      'harvests': a.db.harvests,
      'customSpecies': a.db.customSpecies,
      'identifications': a.db.identifications,
      'spotSpecies': a.db.spotSpecies,
    };
    for (final e in tablesByKey.entries) {
      final row = (data[e.key]! as List).first as Map<String, Object?>;
      expect(row.keys.toSet(), e.value.columnsByName.keys.map(camel).toSet(), reason: e.key);
    }
    expect(a.db.schemaVersion, 4);
  });

  test('la version de l\'application du manifeste suit pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.substring('version:'.length).trim(), backupAppVersion);
  });
}
