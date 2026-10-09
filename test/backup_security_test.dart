import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/data/backup/backup_format.dart';
import 'package:mycelium/data/backup/backup_service.dart';

import 'backup_support.dart';

void main() {
  late Install a;
  late Install b;
  late File good;

  setUp(() async {
    a = await Install.create();
    b = await Install.create();
    a.use();
    await seed(a);
    good = (await a.service().createArchive(outputDir: a.work, now: DateTime(2026, 10, 9))).file;
    // L'appareil cible a déjà des données : elles doivent survivre à tout refus.
    await seed(b);
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  Future<void> refused(File zip, BackupErrorKind kind, {RestoreMode mode = RestoreMode.replace}) async {
    final dbBefore = await tables(b.db);
    final filesBefore = tree(b.docs);
    await expectLater(
      b.service().restore(zip, mode: mode),
      throwsA(isA<BackupException>().having((e) => e.kind, 'kind', kind)),
    );
    await expectUntouched(b, dbBefore, filesBefore);
  }

  group('chemins malveillants (zip-slip)', () {
    for (final name in [
      '../evil.txt',
      'photos/../../evil.txt',
      '/etc/evil.txt',
      'photos\\..\\evil.txt',
      'C:/evil.txt',
      'photos/harvest_photos/../../x.jpg',
      'photos//x.jpg',
    ]) {
      test('« $name » : archive refusée sans rien écrire', () async {
        final evil = rewrite(good, (e) => {...e, name: [1, 2, 3]});
        await refused(evil, BackupErrorKind.unsafe);
        expect(File('${b.docs.parent.path}/evil.txt').existsSync(), isFalse);
      });
    }

    test('chemin de photo dangereux dans data.json', () async {
      final evil = rewrite(good, (e) {
        final data = jsonEntry(e, 'data.json');
        ((data['harvests']! as List).first as Map<String, Object?>)['photoPath'] = '../../evil.jpg';
        return {...e, 'data.json': jsonBytes(data)};
      });
      await refused(evil, BackupErrorKind.unsafe);
    });
  });

  group('versions', () {
    test('schéma plus récent que l\'application', () async {
      final newer = rewrite(good, (e) {
        final m = jsonEntry(e, 'manifest.json')..['schemaVersion'] = b.db.schemaVersion + 1;
        return {...e, 'manifest.json': jsonBytes(m)};
      });
      await refused(newer, BackupErrorKind.tooNew);
    });

    test('conteneur plus récent', () async {
      final newer = rewrite(good, (e) {
        final m = jsonEntry(e, 'manifest.json')..['formatVersion'] = backupFormatVersion + 1;
        return {...e, 'manifest.json': jsonBytes(m)};
      });
      await refused(newer, BackupErrorKind.tooNew);
    });

    test('autre format', () async {
      final other = rewrite(good, (e) {
        final m = jsonEntry(e, 'manifest.json')..['format'] = 'autre-chose';
        return {...e, 'manifest.json': jsonBytes(m)};
      });
      await refused(other, BackupErrorKind.notABackup);
    });
  });

  group('archive abîmée', () {
    test('fichier qui n\'est pas une archive', () async {
      final junk = File('${a.work.path}/junk.zip')..writeAsBytesSync(bytesOf(3, 4000));
      await refused(junk, BackupErrorKind.notABackup);
    });

    test('fichier vide', () async {
      final empty = File('${a.work.path}/empty.zip')..writeAsBytesSync([]);
      await refused(empty, BackupErrorKind.notABackup);
    });

    test('archive tronquée', () async {
      final bytes = good.readAsBytesSync();
      final cut = File('${a.work.path}/cut.zip')..writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 2));
      await refused(cut, BackupErrorKind.notABackup);
    });

    test('photo modifiée : somme de contrôle fausse, rien n\'est changé', () async {
      final bytes = good.readAsBytesSync();
      // Les photos sont stockées telles quelles : on retrouve la plus grosse et on la corrompt.
      final marker = bytesOf(3, 300000);
      final at = _indexOf(bytes, marker.sublist(0, 64));
      expect(at, greaterThan(0));
      bytes[at + 100000] ^= 0xff;
      final bad = File('${a.work.path}/bad.zip')..writeAsBytesSync(bytes);
      await refused(bad, BackupErrorKind.corrupted);
      // En fusion, seule une photo absente de l'appareil est lue dans l'archive.
      b.photo('harvest_photos/h3.jpg').deleteSync();
      await refused(bad, BackupErrorKind.corrupted, mode: RestoreMode.merge);
    });

    test('manifeste ou données absents', () async {
      await refused(rewrite(good, (e) => {...e}..remove('manifest.json')), BackupErrorKind.notABackup);
      await refused(rewrite(good, (e) => {...e}..remove('data.json')), BackupErrorKind.notABackup);
    });

    test('photo annoncée mais absente de l\'archive', () async {
      final gone = rewrite(good, (e) => {...e}..remove('photos/harvest_photos/h1.jpg'));
      await refused(gone, BackupErrorKind.incomplete);
    });
  });

  group('contenu incohérent', () {
    Future<void> broken(void Function(Map<String, Object?> data) edit) async {
      final bad = rewrite(good, (e) {
        final d = jsonEntry(e, 'data.json');
        edit(d);
        return {...e, 'data.json': jsonBytes(d)};
      });
      await refused(bad, BackupErrorKind.invalid);
    }

    Map<String, Object?> firstRow(Map<String, Object?> d, String table) =>
        (d[table]! as List).first as Map<String, Object?>;

    test('JSON illisible', () async {
      final bad = rewrite(good, (e) => {...e, 'data.json': '{pas du json'.codeUnits});
      await refused(bad, BackupErrorKind.invalid);
    });

    test('section manquante', () => broken((d) => d.remove('spotSpecies')));
    test('latitude textuelle', () => broken((d) => firstRow(d, 'spots')['latitude'] = 'nord'));
    test('latitude hors limites', () => broken((d) => firstRow(d, 'spots')['latitude'] = 123.0));
    test('date invalide', () => broken((d) => firstRow(d, 'outings')['startedAt'] = 'hier'));
    test('identifiant manquant', () => broken((d) => firstRow(d, 'spots').remove('id')));
    test('identifiant en double', () => broken((d) {
          final spots = d['spots']! as List;
          spots.add(Map<String, Object?>.of(spots.first as Map<String, Object?>));
        }));
    test('comptes du manifeste faux', () async {
      final bad = rewrite(good, (e) {
        final m = jsonEntry(e, 'manifest.json');
        (m['counts']! as Map<String, Object?>)['spots'] = 99;
        return {...e, 'manifest.json': jsonBytes(m)};
      });
      await refused(bad, BackupErrorKind.invalid);
    });
  });
}

int _indexOf(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}
