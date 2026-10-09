import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/data/photo_store.dart';
import 'package:mycelium/features/identify/history/identification_saver.dart';
import 'package:mycelium/features/identify/history/place_sheet.dart';
import 'package:mycelium/features/identify/identifier.dart';
import 'package:path/path.dart' as p;

import 'identify_history_support.dart' show outcomeFor, samplePhotoBytes;

/// Enregistrement d'une identification : ce qui est écrit en base, et où.
void main() {
  final now = DateTime(2026, 10, 9, 14, 32);

  late AppDatabase db;
  late Directory docs;
  late String photo;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    docs = await Directory.systemTemp.createTemp('mycelium_docs');
    final inbox = await Directory.systemTemp.createTemp('mycelium_inbox');
    photo = (await File(p.join(inbox.path, 'IMG_0042.JPG')).writeAsBytes(samplePhotoBytes)).path;
    photoRoot = () async => docs;
    addTearDown(() async {
      await db.close();
      await docs.delete(recursive: true);
      await inbox.delete(recursive: true);
    });
  });

  Future<Spot> addSpot(String id, String name, {double lat = 48.6121, double lon = 7.7917}) async {
    await db.upsertSpot(SpotsCompanion.insert(
      id: id,
      name: name,
      latitude: lat,
      longitude: lon,
      createdAt: now,
      updatedAt: now,
    ));
    return (await db.spotById(id))!;
  }

  test('espèce + coin existant : photo relative, position, coin, espèce, top 5 et modèle', () async {
    final spot = await addSpot('s1', 'Clairière aux girolles');
    final outcome = outcomeFor(photo, lat: 48.612, lon: 7.7916, unknownScore: 0.07);

    final saved = await saveIdentification(
      db,
      outcome: outcome,
      speciesId: 'girolle',
      place: ExistingSpot(spot),
      now: now,
    );

    final row = (await db.identificationById(saved.id))!;
    // Photo : copiée dans les Documents, chemin RELATIF en base.
    expect(row.photoPath, 'identification_photos/${saved.id}.JPG');
    expect(p.isRelative(row.photoPath), isTrue);
    expect(File(p.join(docs.path, row.photoPath)).readAsBytesSync(), samplePhotoBytes);
    expect(saved.photoPath, row.photoPath);
    // Ce que l'utilisateur a décidé, et où.
    expect(row.chosenSpeciesId, 'girolle');
    expect(row.spotId, 's1');
    expect(saved.spot?.id, 's1');
    expect(row.latitude, 48.612);
    expect(row.longitude, 7.7916);
    expect(row.createdAt, now);
    // Ce que le modèle avait répondu, conservé à part (traçabilité).
    expect(row.modelVersion, 'test-1');
    expect(row.unknownScore, 0.07);
    expect(jsonDecode(row.top5Json), [
      {'id': 'girolle', 'score': 0.8},
      {'id': 'fausse-girolle', 'score': 0.1},
      {'id': 'chanterelle-en-tube', 'score': 0.05},
    ]);
    // Le coin retient l'espèce : c'est ce que filtre la carte.
    final seen = (await db.select(db.spotSpecies).get()).single;
    expect((seen.spotId, seen.speciesId, seen.lastSeenAt), ('s1', 'girolle', now));
  });

  test('nouveau coin : créé à la position choisie, avec le nom saisi, et rattaché', () async {
    final saved = await saveIdentification(
      db,
      outcome: outcomeFor(photo, lat: 48.612, lon: 7.7916),
      speciesId: 'morille',
      place: const NewSpot(name: 'Lisière aux morilles', latitude: 48.6125, longitude: 7.79),
      now: now,
    );

    final spots = await db.select(db.spots).get();
    expect(spots, hasLength(1));
    expect(spots.single.name, 'Lisière aux morilles');
    expect(spots.single.latitude, 48.6125);
    expect(spots.single.longitude, 7.79);
    expect(spots.single.isFavorite, isFalse);
    expect(spots.single.createdAt, now);
    // Identifiant unique (uuid), distinct de celui de l'identification.
    expect(spots.single.id, isNot(saved.id));
    expect(spots.single.id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-')));

    final row = (await db.identificationById(saved.id))!;
    expect(row.spotId, spots.single.id);
    expect(saved.spot?.name, 'Lisière aux morilles');
    final seen = (await db.select(db.spotSpecies).get()).single;
    expect((seen.spotId, seen.speciesId), (spots.single.id, 'morille'));
    // La position de la photo n'est pas celle du coin : chacune garde la sienne.
    expect(row.latitude, 48.612);
    expect(row.longitude, 7.7916);
  });

  test('photo de la galerie : aucune position inventée, même avec un nouveau coin', () async {
    final saved = await saveIdentification(
      db,
      outcome: outcomeFor(photo), // pas de latitude ni de longitude
      speciesId: 'girolle',
      place: const NewSpot(name: 'Ma position', latitude: 48.0, longitude: 7.0),
      now: now,
    );

    final row = (await db.identificationById(saved.id))!;
    expect(row.latitude, isNull);
    expect(row.longitude, isNull);
    expect((await db.select(db.spots).get()).single.latitude, 48.0);
  });

  test('sans emplacement : ni coin, ni espèce observée', () async {
    final saved = await saveIdentification(
      db,
      outcome: outcomeFor(photo, lat: 48.612, lon: 7.7916),
      speciesId: 'girolle',
      place: const NoPlace(),
      now: now,
    );

    final row = (await db.identificationById(saved.id))!;
    expect(row.chosenSpeciesId, 'girolle');
    expect(row.spotId, isNull);
    expect(saved.spot, isNull);
    expect(row.latitude, 48.612, reason: 'la position de la photo est gardée quand même');
    expect(await db.select(db.spots).get(), isEmpty);
    expect(await db.select(db.spotSpecies).get(), isEmpty);
  });

  test('« Je ne sais pas » : photo et position gardées, sans espèce ni coin', () async {
    final saved = await saveIdentification(
      db,
      outcome: outcomeFor(photo, lat: 48.612, lon: 7.7916),
      speciesId: null,
      place: const NoPlace(),
      now: now,
    );

    final row = (await db.identificationById(saved.id))!;
    expect(row.chosenSpeciesId, isNull);
    expect(row.spotId, isNull);
    expect(row.latitude, 48.612);
    expect(row.longitude, 7.7916);
    expect(File(p.join(docs.path, row.photoPath)).existsSync(), isTrue);
    expect(jsonDecode(row.top5Json), isNotEmpty, reason: 'le résultat du modèle est conservé');
    expect(await db.select(db.spotSpecies).get(), isEmpty);
  });

  test('l\'espèce retenue est celle de l\'utilisateur, le modèle reste intact (RM-3)', () async {
    final saved = await saveIdentification(
      db,
      outcome: outcomeFor(photo), // le modèle propose d'abord la girolle
      speciesId: 'cepe-de-bordeaux',
      place: const NoPlace(),
      now: now,
    );

    final row = (await db.identificationById(saved.id))!;
    expect(row.chosenSpeciesId, 'cepe-de-bordeaux');
    expect((jsonDecode(row.top5Json) as List).first['id'], 'girolle');
  });

  test('un résultat sans candidat s\'enregistre avec un top 5 vide', () async {
    final saved = await saveIdentification(
      db,
      outcome: outcomeFor(photo, candidates: const <Candidate>[]),
      speciesId: null,
      place: const NoPlace(),
      now: now,
    );
    expect((await db.identificationById(saved.id))!.top5Json, '[]');
  });

  test('l\'espèce marquée dans un coin ne recule jamais dans le temps', () async {
    final spot = await addSpot('s1', 'Coin');
    final later = now.add(const Duration(days: 3));
    await db.markSpeciesSeen('s1', 'girolle', later);

    await saveIdentification(
      db,
      outcome: outcomeFor(photo),
      speciesId: 'girolle',
      place: ExistingSpot(spot),
      now: now, // plus ancienne que la dernière observation
    );

    expect((await db.select(db.spotSpecies).get()).single.lastSeenAt, later);
  });

  test('le coin a été supprimé entre-temps : l\'identification reste sans coin', () async {
    final spot = await addSpot('s1', 'Coin');
    await db.deleteSpot('s1');

    final saved = await saveIdentification(
      db,
      outcome: outcomeFor(photo),
      speciesId: 'girolle',
      place: ExistingSpot(spot),
      now: now,
    );

    expect((await db.identificationById(saved.id))!.spotId, isNull);
    expect(saved.spot, isNull);
    expect(await db.select(db.spotSpecies).get(), isEmpty);
  });

  test('chaque enregistrement a son identifiant et sa propre copie de la photo', () async {
    final first = await saveIdentification(db,
        outcome: outcomeFor(photo), speciesId: 'girolle', place: const NoPlace(), now: now);
    final second = await saveIdentification(db,
        outcome: outcomeFor(photo), speciesId: 'girolle', place: const NoPlace(), now: now);

    expect(first.id, isNot(second.id));
    expect(first.photoPath, isNot(second.photoPath));
    final files = Directory(p.join(docs.path, 'identification_photos')).listSync();
    expect(files, hasLength(2));
  });

  test('échec de la base : la photo copiée est supprimée, l\'erreur remonte', () async {
    // Une base dont la table des identifications a disparu : l'écriture échoue
    // après la copie de la photo.
    await db.customStatement('DROP TABLE identifications');

    await expectLater(
      saveIdentification(db,
          outcome: outcomeFor(photo), speciesId: 'girolle', place: const NoPlace(), now: now),
      throwsA(anything),
    );

    final dir = Directory(p.join(docs.path, 'identification_photos'));
    expect(dir.existsSync() ? dir.listSync() : const <FileSystemEntity>[], isEmpty,
        reason: 'aucun fichier orphelin');
  });

  test('échec pendant l\'écriture : ni identification, ni coin créé à moitié', () async {
    await db.customStatement('DROP TABLE identifications');

    await expectLater(
      saveIdentification(db,
          outcome: outcomeFor(photo),
          speciesId: 'girolle',
          place: const NewSpot(name: 'Coin fantôme', latitude: 48, longitude: 7),
          now: now),
      throwsA(anything),
    );

    expect(await db.select(db.spots).get(), isEmpty, reason: 'transaction annulée');
    expect(await db.select(db.spotSpecies).get(), isEmpty);
    final dir = Directory(p.join(docs.path, 'identification_photos'));
    expect(dir.existsSync() ? dir.listSync() : const <FileSystemEntity>[], isEmpty);
  });

  test('sans photo, on n\'enregistre rien', () async {
    const withoutPhoto = IdentificationOutcome(
      candidates: [Candidate(speciesId: 'girolle', score: 0.9)],
      isInsufficient: false,
      dangerousSpeciesIds: [],
      isDemo: false,
    );
    await expectLater(
      saveIdentification(db,
          outcome: withoutPhoto, speciesId: 'girolle', place: const NoPlace(), now: now),
      throwsArgumentError,
    );
    expect(await db.select(db.identifications).get(), isEmpty);
  });
}
