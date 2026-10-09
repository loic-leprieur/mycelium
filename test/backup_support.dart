import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/data/backup/backup_service.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/data/photo_store.dart';
import 'package:path/path.dart' as p;

/// Une « installation » : base en mémoire + dossier Documents temporaire.
class Install {
  Install._(this.db, this.docs, this.work);

  final AppDatabase db;
  final Directory docs;
  final Directory work;

  static Future<Install> create() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final base = await Directory.systemTemp.createTemp('mycelium_backup_');
    final docs = await Directory(p.join(base.path, 'Documents')).create();
    final work = await Directory(p.join(base.path, 'tmp')).create();
    return Install._(AppDatabase(NativeDatabase.memory()), docs, work);
  }

  BackupService service({DateTime Function()? clock}) =>
      BackupService(db: db, photosRoot: docs, clock: clock);

  /// Les lectures de photos passent par `photoRoot` : à appeler avant d'exporter.
  void use() => photoRoot = () async => docs;

  File photo(String rel) => File(p.join(docs.path, rel));

  void writePhoto(String rel, List<int> bytes) {
    final f = photo(rel);
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes);
  }

  Future<void> dispose() async {
    await db.close();
    await docs.parent.delete(recursive: true);
  }
}

final t0 = DateTime.utc(2026, 10, 1, 8);

Uint8List bytesOf(int seed, [int n = 5000]) => Uint8List.fromList(List.generate(n, (i) => (i * 7 + seed) & 0xff));

/// Données variées : photos relatives, ancien chemin absolu, ancien conteneur.
Future<void> seed(Install i) async {
  final db = i.db;
  await db.upsertSpot(SpotsCompanion.insert(
    id: 's1', name: 'Coin des cèpes', latitude: 48.2, longitude: 7.3,
    forestType: const Value('Conifères'), isFavorite: const Value(true), createdAt: t0, updatedAt: t0));
  await db.upsertSpot(SpotsCompanion.insert(
    id: 's2', name: 'Sans sortie', latitude: 48.3, longitude: 7.4, createdAt: t0, updatedAt: t0));
  await db.upsertOuting(OutingsCompanion.insert(id: 'o1', startedAt: t0, spotId: const Value('s1'), durationMin: const Value(90)));
  i.writePhoto('harvest_photos/h1.jpg', bytesOf(1));
  i.writePhoto('harvest_photos/h2.jpg', bytesOf(2));
  i.writePhoto('harvest_photos/h3.jpg', bytesOf(3, 300000));
  i.writePhoto('species_photos/c1.jpg', bytesOf(4));
  i.writePhoto('identification_photos/i1.jpg', bytesOf(5));
  await db.addHarvest(HarvestsCompanion.insert(
    id: 'h1', outingId: 'o1', speciesId: 'girolle', photoPath: const Value('harvest_photos/h1.jpg'), quantityCount: const Value(3)));
  await db.addHarvest(HarvestsCompanion.insert(
    id: 'h2', outingId: 'o1', speciesId: 'cepe-de-bordeaux', photoPath: Value(i.photo('harvest_photos/h2.jpg').path), weightGrams: const Value(800)));
  await db.addHarvest(HarvestsCompanion.insert(
    id: 'h3', outingId: 'o1', speciesId: 'morille',
    photoPath: const Value('/var/mobile/Containers/Data/Application/OLD-UUID/Documents/harvest_photos/h3.jpg')));
  await db.upsertCustomSpecies(CustomSpeciesCompanion.insert(
    id: 'c1', commonName: 'Ma trompette', description: const Value('desc'), photoPath: const Value('species_photos/c1.jpg'), createdAt: t0));
  await db.addIdentification(IdentificationsCompanion.insert(
    id: 'i1', photoPath: 'identification_photos/i1.jpg', modelVersion: 'v1', top5Json: '[{"id":"girolle","score":0.8}]',
    unknownScore: const Value(0.1), chosenSpeciesId: const Value('girolle'), createdAt: t0,
    latitude: const Value(48.21), longitude: const Value(7.31), spotId: const Value('s1')));
  await db.markSpeciesSeen('s2', 'morille', t0);
  await db.setMeta('consent_accepted_at', '2026-09-01');
  await db.setMeta('consent_version', '1');
  await db.setMeta('text_scale', '1.3');
}

/// Contenu des tables, comparable (les photos ne sont pas incluses).
Future<Map<String, Object>> tables(AppDatabase db) async => {
      'spots': await db.select(db.spots).get(),
      'outings': await db.select(db.outings).get(),
      'harvests': await db.select(db.harvests).get(),
      'customSpecies': await db.select(db.customSpecies).get(),
      'identifications': await db.select(db.identifications).get(),
      'spotSpecies': await db.select(db.spotSpecies).get(),
      'appMeta': await db.select(db.appMeta).get(),
    };

/// Arborescence d'un dossier : chemin relatif -> contenu.
Map<String, List<int>> tree(Directory dir) => {
      if (dir.existsSync())
        for (final f in dir.listSync(recursive: true).whereType<File>())
          p.relative(f.path, from: dir.path): f.readAsBytesSync(),
    };

/// Réécrit une archive : [edit] reçoit ses entrées (nom -> octets) et renvoie
/// les entrées à écrire. Sert à fabriquer des archives piégées ou abîmées.
File rewrite(File zip, Map<String, List<int>> Function(Map<String, List<int>> entries) edit, {String suffix = 'edit'}) {
  final archive = ZipDecoder().decodeBytes(zip.readAsBytesSync());
  final entries = <String, List<int>>{for (final f in archive) if (f.isFile) f.name: f.readBytes()!};
  final out = Archive();
  edit(entries).forEach((name, data) => out.add(ArchiveFile.bytes(name, data)));
  final target = File('${zip.path}.$suffix.zip');
  target.writeAsBytesSync(ZipEncoder().encodeBytes(out));
  return target;
}

Map<String, Object?> jsonEntry(Map<String, List<int>> entries, String name) =>
    jsonDecode(utf8.decode(entries[name]!)) as Map<String, Object?>;

List<int> jsonBytes(Object? value) => utf8.encode(jsonEncode(value));

/// Vérifie qu'une restauration refusée n'a rien changé.
Future<void> expectUntouched(Install i, Map<String, Object> dbBefore, Map<String, List<int>> filesBefore) async {
  expect((await tables(i.db)).toString(), dbBefore.toString());
  final after = tree(i.docs);
  expect(after.keys.toSet(), filesBefore.keys.toSet());
  for (final k in after.keys) {
    expect(after[k], filesBefore[k], reason: k);
  }
}
