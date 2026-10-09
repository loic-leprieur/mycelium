import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mycelium/app.dart';
import 'package:mycelium/core/router.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/data/photo_store.dart';
import 'package:mycelium/data/providers.dart';
import 'package:mycelium/features/identify/identifier.dart';
import 'package:mycelium/features/identify/identifier_provider.dart';
import 'package:mycelium/features/identify/identify_flow.dart';
import 'package:mycelium/features/map/location.dart';
import 'package:mycelium/features/map/map_config.dart';
import 'package:path/path.dart' as p;

import 'support/flows.dart';
import 'support/harness.dart';

/// Vraie image (224 x 224), pour que les miniatures aient quelque chose à décoder.
List<int> get samplePhotoBytes =>
    File('test/fixtures/clip_landscape_224.png').readAsBytesSync();

/// Résultat d'identification tel que le produit l'écran « Identifier » : règles de
/// sécurité appliquées, photo [photoPath], position de la prise de vue [lat]/[lon]
/// (absente pour une photo de la galerie).
IdentificationOutcome outcomeFor(
  String photoPath, {
  double? lat,
  double? lon,
  double unknownScore = 0.05,
  List<Candidate>? candidates,
}) =>
    applySafetyRules(
      candidates ??
          const [
            Candidate(speciesId: 'girolle', score: 0.8),
            Candidate(speciesId: 'fausse-girolle', score: 0.1),
            Candidate(speciesId: 'chanterelle-en-tube', score: 0.05),
          ],
      edibilityOf: seedEdibilityOf,
      thresholds: identifyThresholds,
      unknownScore: unknownScore,
      modelVersion: 'test-1',
      imagePath: photoPath,
      latitude: lat,
      longitude: lon,
    );

/// L'application complète sur une base en mémoire, avec un dossier « Documents »
/// et une « boîte de réception » (là où l'appareil photo dépose ses fichiers)
/// temporaires, et un GPS simulé (ou absent).
class HistoryApp {
  HistoryApp._(this.db, this.router, this.widget, this.docs, this.inbox);

  final AppDatabase db;
  final GoRouter router;
  final Widget widget;

  /// Simule les Documents de l'application (`photoRoot`).
  final Directory docs;

  /// Là où se trouvent les photos prises, avant d'être copiées dans [docs].
  final Directory inbox;

  static Future<HistoryApp> start(
    WidgetTester t, {
    String initialLocation = '/identify',
    bool withGps = true,
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final docs = (await t.runAsync(() => Directory.systemTemp.createTemp('mycelium_docs')))!;
    final inbox = (await t.runAsync(() => Directory.systemTemp.createTemp('mycelium_inbox')))!;
    photoRoot = () async => docs;
    final db = AppDatabase(NativeDatabase.memory());
    final router = buildRouter(initialLocation: initialLocation);
    final widget = ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) => db),
        locationProvider.overrideWith(
          (ref) => Stream.value(
            withGps
                ? LocationState(LocationStatus.ok, testPosition())
                : const LocationState(LocationStatus.unavailable),
          ),
        ),
        tilesEnabledProvider.overrideWithValue(false),
        identifierProvider.overrideWith((ref) async => null),
      ],
      child: MyceliumApp(router: router),
    );
    return HistoryApp._(db, router, widget, docs, inbox);
  }

  /// Fournit un conteneur Riverpod pour lire l'état (guidage, etc.).
  ProviderContainer container(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(MyceliumApp)));

  /// Une photo « prise » : un fichier dans la boîte de réception.
  Future<String> takePhoto(WidgetTester t, {String name = 'IMG_0001.JPG'}) async {
    final file = File(p.join(inbox.path, name));
    await t.runAsync(() => file.writeAsBytes(samplePhotoBytes));
    return file.path;
  }

  /// Un fichier déjà rangé dans les Documents : renvoie son chemin relatif.
  Future<String> storePhoto(WidgetTester t, String relative) async {
    final file = File(p.join(docs.path, relative));
    await t.runAsync(() async {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(samplePhotoBytes);
    });
    return relative;
  }

  Future<void> addSpot(
    WidgetTester t, {
    required String id,
    required String name,
    required double lat,
    required double lon,
    bool favorite = false,
  }) =>
      t.runAsync(() => db.upsertSpot(SpotsCompanion.insert(
            id: id,
            name: name,
            latitude: lat,
            longitude: lon,
            isFavorite: Value(favorite),
            createdAt: DateTime(2026, 10, 1),
            updatedAt: DateTime(2026, 10, 1),
          )));

  Future<void> addIdentification(
    WidgetTester t, {
    required String id,
    required String photoPath,
    required DateTime at,
    String? species,
    String? spotId,
    double? lat,
    double? lon,
    double unknownScore = 0,
    String top5 = '[]',
    String modelVersion = 'test-1',
  }) =>
      t.runAsync(() => db.addIdentification(IdentificationsCompanion.insert(
            id: id,
            photoPath: photoPath,
            modelVersion: modelVersion,
            top5Json: top5,
            unknownScore: Value(unknownScore),
            chosenSpeciesId: Value(species),
            createdAt: at,
            latitude: Value(lat),
            longitude: Value(lon),
            spotId: Value(spotId),
          )));

  Future<List<Identification>> identifications(WidgetTester t) async =>
      (await t.runAsync(() => db.select(db.identifications).get()))!;

  Future<List<Spot>> spots(WidgetTester t) async =>
      (await t.runAsync(() => db.select(db.spots).get()))!;

  Future<List<SpotSpeciesRow>> spotSpecies(WidgetTester t) async =>
      (await t.runAsync(() => db.select(db.spotSpecies).get()))!;

  /// Fichiers présents sous `<Documents>/<folder>`.
  Future<List<String>> filesIn(WidgetTester t, String folder) async {
    final dir = Directory(p.join(docs.path, folder));
    return (await t.runAsync(() async {
      if (!await dir.exists()) return <String>[];
      return [
        await for (final e in dir.list())
          if (e is File) p.basename(e.path),
      ];
    }))!;
  }

  /// Laisse l'interface se terminer proprement, puis ferme la base et supprime
  /// les dossiers temporaires.
  Future<void> dispose(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    await t.runAsync(() async {
      await db.close();
      await docs.delete(recursive: true);
      await inbox.delete(recursive: true);
    });
  }
}

/// Alterne temps réel (fichiers, base) et temps simulé (images, animations) jusqu'à
/// ce que [done] soit vrai : une suite d'opérations sur des fichiers a besoin de
/// plusieurs tours, contrairement à un simple [settle].
Future<void> settleUntil(
  WidgetTester t,
  Future<bool> Function() done, {
  int tries = 80,
}) async {
  for (var i = 0; i < tries; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 120));
    if (await t.runAsync(done) ?? false) {
      await settle(t);
      return;
    }
  }
  fail('La condition attendue n\'a jamais été atteinte.');
}

/// Laisse défiler quelques tours (miniatures, flux de la base) quand on n'attend
/// pas d'écriture précise.
Future<void> settleFor(WidgetTester t, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 120));
  }
  await settle(t);
}
