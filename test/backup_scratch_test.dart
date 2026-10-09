import 'dart:isolate';

import 'package:drift/drift.dart' show InsertMode, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/data/database.dart';

class _Out {
  _Out(this.spots);
  final List<Spot> spots;
}

Future<_Out> _task(int n) async => _Out([
      for (var i = 0; i < n; i++)
        Spot(
          id: 's$i',
          name: 'n$i',
          latitude: 48.1,
          longitude: 7.1,
          isFavorite: false,
          createdAt: DateTime.utc(2026, 10, 8),
          updatedAt: DateTime.utc(2026, 10, 8),
        ),
    ]);

class _Fail implements Exception {
  _Fail(this.message);
  final String message;
}

void main() {
  test('Isolate.run renvoie des classes Drift', () async {
    final out = await Isolate.run(() => _task(3));
    expect(out.spots, hasLength(3));
    expect(out.spots.first.createdAt.isUtc, isTrue);
  });

  test('Isolate.run propage une exception personnalisée', () async {
    try {
      await Isolate.run<void>(() => throw _Fail('boum'));
      fail('aurait dû échouer');
    } catch (e) {
      // ignore: avoid_print
      print('type=${e.runtimeType} -> $e');
    }
  });

  test('transaction imbriquée + insertOrIgnore + rollback', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    final out = await _task(3);
    await db.batch((b) => b.insertAll(db.spots, out.spots, mode: InsertMode.insertOrIgnore));
    expect(await db.select(db.spots).get(), hasLength(3));
    // même lignes : ignorées
    await db.batch((b) => b.insertAll(db.spots, out.spots, mode: InsertMode.insertOrIgnore));
    expect(await db.select(db.spots).get(), hasLength(3));

    await db.transaction(() async {
      await db.markSpeciesSeen('s0', 'girolle', DateTime(2026, 10, 1));
      await db.markSpeciesSeen('s0', 'girolle', DateTime(2026, 9, 1));
    });
    expect((await db.select(db.spotSpecies).get()).single.lastSeenAt, DateTime(2026, 10, 1));

    try {
      await db.transaction(() async {
        await db.delete(db.spots).go();
        await db.markSpeciesSeen('s1', 'cepe', DateTime(2026, 10, 1));
        throw _Fail('échec');
      });
    } catch (_) {}
    expect(await db.select(db.spots).get(), hasLength(3));
    expect(await db.select(db.spotSpecies).get(), hasLength(1));
    await db.customStatement('VACUUM');
    await db.close();
  });
}
