import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/app.dart';
import 'package:mycelium/core/router.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/data/providers.dart';
import 'package:mycelium/features/identify/identifier_provider.dart';
import 'package:mycelium/features/map/location.dart';
import 'package:mycelium/features/map/map_config.dart';
import 'package:mycelium/features/species/ui/species_list_screen.dart';

import 'support/harness.dart';

/// Laisse animations et écritures en base se terminer (sans `pumpAndSettle`,
/// que les animations répétées empêcheraient de finir).
Future<void> settleSpecies(WidgetTester t, {int ms = 600}) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await t.pump();
  await t.pump(Duration(milliseconds: ms));
  await t.pump(const Duration(milliseconds: 500));
}

/// Application de test sur l'encyclopédie, avec une horloge réglable
/// (comme `TestApp`, qui ne permet pas d'ajouter de remplacement).
class SpeciesApp {
  SpeciesApp._(this.db, this.widget);

  final AppDatabase db;
  final Widget widget;

  factory SpeciesApp({String location = '/species', DateTime? now}) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    return SpeciesApp._(
      db,
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) => db),
          locationProvider.overrideWith(
            (ref) => Stream.value(LocationState(LocationStatus.ok, testPosition())),
          ),
          tilesEnabledProvider.overrideWithValue(false),
          identifierProvider.overrideWith((ref) async => null),
          if (now != null) speciesClockProvider.overrideWithValue(() => now),
        ],
        child: MyceliumApp(router: buildRouter(initialLocation: location)),
      ),
    );
  }

  Future<void> dispose(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    await t.runAsync(db.close);
  }
}

/// Fait défiler [inside] jusqu'à rendre [target] visible, puis le touche.
Future<void> tapScrolled(WidgetTester t, Finder target, {Finder? inside}) async {
  if (target.evaluate().isEmpty) {
    final scrollable = find.descendant(
      of: inside ?? find.byType(Scaffold).last,
      matching: find.byType(Scrollable),
    ).last;
    await t.dragUntilVisible(target, scrollable, const Offset(0, -120));
  }
  await t.ensureVisible(target);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(target);
  await settleSpecies(t);
}
