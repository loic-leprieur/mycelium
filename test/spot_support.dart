import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/data/database.dart';

import 'support/harness.dart';

/// Laisse les animations (dont celles qui se répètent) et les écritures en base
/// se terminer, sans `pumpAndSettle` qui ne s'arrêterait jamais.
Future<void> settle(WidgetTester t, {int ms = 600}) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
  await t.pump();
  await t.pump(Duration(milliseconds: ms));
  await t.pump(const Duration(milliseconds: 500));
}

/// Fait défiler la liste de [inside] jusqu'à rendre [target] visible, puis
/// appuie dessus. Les listes sont paresseuses : un texte plus bas n'existe pas
/// tant qu'on n'a pas défilé jusqu'à lui.
Future<void> tapScrolled(WidgetTester t, Finder target, {required Finder inside}) async {
  if (target.evaluate().isEmpty) {
    final scrollable = find.descendant(of: inside, matching: find.byType(Scrollable)).first;
    await t.dragUntilVisible(target, scrollable, const Offset(0, -140));
  }
  await t.ensureVisible(target);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(target);
  await settle(t);
}

/// Fenêtre assez haute pour que toute la liste des coins soit construite
/// (la liste est paresseuse : seuls les coins visibles existent dans l'arbre).
const tallWindow = ScreenCase('fenêtre haute 1280x1400', 1280, 1400, 1);

/// Date sans heure ni fuseau pour les données de test.
DateTime day(int month, int dayOfMonth, [int year = 2026]) =>
    DateTime(year, month, dayOfMonth, 10);

/// Ajoute une sortie, rattachée à un coin ou non.
Future<void> addOuting(AppDatabase db, String id, DateTime at, {String? spotId}) =>
    db.upsertOuting(OutingsCompanion.insert(
      id: id,
      startedAt: at,
      spotId: Value(spotId),
    ));

/// Données communes aux tests des coins, en plus des trois coins de [TestApp] :
///
/// - `seed-0` « Coin des cèpes » (favori) : cèpe de Bordeaux et girolle ; deux
///   sorties (20 septembre et 5 octobre), la dernière avec deux récoltes ;
/// - `seed-1` « Clairière aux girolles » : girolle ; une sortie le 28 septembre ;
/// - `seed-2` « Lisière des morilles » : morille ; une sortie le 7 octobre ;
/// - `seed-3` « Zone sans observation » : très éloignée, sans espèce ni sortie.
///
/// Les observations viennent des récoltes (comme dans l'application) ; la
/// sortie de septembre, plus ancienne, ne fait pas reculer la date du cèpe.
/// Ordre par distance : cèpes, girolles, morilles, zone ; par nom : girolles,
/// cèpes, morilles, zone ; par dernière visite : morilles, cèpes, girolles, zone.
Future<void> seedSpotData(AppDatabase db) async {
  final now = day(10, 8);
  await db.upsertSpot(SpotsCompanion.insert(
    id: 'seed-3',
    name: 'Zone sans observation',
    latitude: 48.70,
    longitude: 7.90,
    isFavorite: const Value(false),
    createdAt: now,
    updatedAt: now,
  ));

  await addOuting(db, 'out-sept', day(9, 20), spotId: 'seed-0');
  await addOuting(db, 'out-oct', day(10, 5), spotId: 'seed-0');
  await addOuting(db, 'out-girolles', day(9, 28), spotId: 'seed-1');
  await addOuting(db, 'out-morilles', day(10, 7), spotId: 'seed-2');

  await db.addHarvest(HarvestsCompanion.insert(
    id: 'h-sept',
    outingId: 'out-sept',
    speciesId: 'cepe-de-bordeaux',
    quantityCount: const Value(1),
  ));
  await db.addHarvest(HarvestsCompanion.insert(
    id: 'h-oct-cepe',
    outingId: 'out-oct',
    speciesId: 'cepe-de-bordeaux',
    quantityCount: const Value(3),
    weightGrams: const Value(500),
  ));
  await db.addHarvest(HarvestsCompanion.insert(
    id: 'h-oct-girolle',
    outingId: 'out-oct',
    speciesId: 'girolle',
    quantityCount: const Value(2),
    weightGrams: const Value(350),
  ));
  await db.addHarvest(HarvestsCompanion.insert(
    id: 'h-girolles',
    outingId: 'out-girolles',
    speciesId: 'girolle',
  ));
  await db.addHarvest(HarvestsCompanion.insert(
    id: 'h-morilles',
    outingId: 'out-morilles',
    speciesId: 'morille',
    quantityCount: const Value(4),
  ));
}

/// Lance l'application sur [location], avec les coins de [TestApp] et ceux de
/// [seedSpotData], puis exécute [body]. La base est remplie AVANT d'afficher
/// l'application : sinon ses lectures, démarrées dans le temps simulé du test,
/// bloqueraient l'écriture.
Future<void> withSpotApp(
  WidgetTester t,
  Future<void> Function(TestApp app) body, {
  String location = '/map',
  ScreenCase? screen,
  Future<void> Function(AppDatabase db) seed = seedSpotData,
}) async {
  applyScreen(t, screen ?? tallWindow);
  final app = TestApp(initialLocation: location);
  try {
    await app.seedSpots(t);
    await t.runAsync(() => seed(app.db));
    await t.pumpWidget(app.widget);
    await settle(t);
    await body(app);
  } finally {
    await app.dispose(t);
  }
}
