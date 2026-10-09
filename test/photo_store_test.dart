import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/data/photo_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory docs;
  late File source;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('mycelium_docs');
    final inbox = await Directory.systemTemp.createTemp('mycelium_inbox');
    source = File(p.join(inbox.path, 'IMG_0001.JPG'))..writeAsBytesSync([1, 2, 3]);
    photoRoot = () async => docs;
  });

  tearDown(() async {
    await docs.delete(recursive: true);
  });

  test('savePhotoRelative renvoie un chemin relatif et copie le fichier', () async {
    final stored = await savePhotoRelative(source.path, folder: 'identification_photos', id: 'abc');
    expect(stored, 'identification_photos/abc.JPG');
    expect(p.isRelative(stored), isTrue);
    expect(File(p.join(docs.path, stored)).readAsBytesSync(), [1, 2, 3]);
  });

  test('resolveStoredPhoto retrouve un chemin relatif', () async {
    final stored = await savePhotoRelative(source.path, folder: 'identification_photos', id: 'abc');
    final file = await resolveStoredPhoto(stored);
    expect(file, isNotNull);
    expect(file!.readAsBytesSync(), [1, 2, 3]);
  });

  test('résiste à un changement de dossier de l\'application', () async {
    final stored = await savePhotoRelative(source.path, folder: 'identification_photos', id: 'abc');
    // Réinstallation : les mêmes fichiers, sous un autre conteneur.
    final moved = await Directory.systemTemp.createTemp('mycelium_docs2');
    await Directory(p.join(docs.path, 'identification_photos'))
        .rename(p.join(moved.path, 'identification_photos'));
    photoRoot = () async => moved;
    addTearDown(() => moved.delete(recursive: true));

    expect(await resolveStoredPhoto(stored), isNotNull);
  });

  test('ancien chemin absolu : retrouvé tel quel, ou sous les Documents actuels', () async {
    final legacy = await savePhoto(source.path, folder: 'harvest_photos', id: 'h1');
    expect(p.isAbsolute(legacy), isTrue);
    expect(await resolveStoredPhoto(legacy), isNotNull);

    // L'ancien conteneur a disparu : l'ancien chemin pointe ailleurs…
    final stale = '/var/mobile/Containers/Data/Application/OLD-UUID/Documents/harvest_photos/h1.JPG';
    final found = await resolveStoredPhoto(stale);
    expect(found, isNotNull);
    expect(found!.path, p.join(docs.path, 'harvest_photos', 'h1.JPG'));
  });

  test('photo introuvable ou chemin vide : null, sans erreur', () async {
    expect(await resolveStoredPhoto(null), isNull);
    expect(await resolveStoredPhoto(''), isNull);
    expect(await resolveStoredPhoto('identification_photos/inconnue.jpg'), isNull);
    expect(await resolveStoredPhoto('/ailleurs/sans/dossier/x.jpg'), isNull);
  });

  test('deleteStoredPhoto supprime le fichier et tolère l\'absence', () async {
    final stored = await savePhotoRelative(source.path, folder: 'identification_photos', id: 'abc');
    await deleteStoredPhoto(stored);
    expect(await resolveStoredPhoto(stored), isNull);
    await deleteStoredPhoto(stored); // déjà supprimée : aucune erreur
    await deleteStoredPhoto(null);
  });
}
