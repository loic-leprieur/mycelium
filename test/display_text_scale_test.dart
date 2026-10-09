import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/data/providers.dart';
import 'package:mycelium/features/settings/display/display_screen.dart';
import 'package:mycelium/features/settings/display/text_scale.dart';

import 'species_support.dart';
import 'support/harness.dart';

double scaleOf(WidgetTester t) =>
    MediaQuery.textScalerOf(t.element(find.byType(Scaffold).first)).scale(10);

void main() {
  setUpAll(loadTestFonts);

  group('textScaleProvider', () {
    late AppDatabase db;
    ProviderContainer newContainer() {
      final c = ProviderContainer(overrides: [databaseProvider.overrideWith((ref) => db)]);
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() => db.close());

    test('Normal par défaut, valeurs inconnues comprises', () async {
      expect(await newContainer().read(textScaleProvider.future), TextScaleLevel.normal);
      await db.setMeta(textScaleMetaKey, 'énorme');
      expect(await newContainer().read(textScaleProvider.future), TextScaleLevel.normal);
    });

    test('le choix est enregistré sous « text_scale » et relu', () async {
      final c = newContainer();
      await c.read(textScaleProvider.future);
      await c.read(textScaleProvider.notifier).choose(TextScaleLevel.extraLarge);
      expect(c.read(textScaleProvider).value, TextScaleLevel.extraLarge);
      expect(await db.metaValue('text_scale'), 'xlarge');
      expect(await newContainer().read(textScaleProvider.future), TextScaleLevel.extraLarge);
    });

    test('un choix fait avant la fin du chargement n\'est pas écrasé', () async {
      await db.setMeta(textScaleMetaKey, 'large');
      final c = newContainer();
      final pending = c.read(textScaleProvider.future);
      await c.read(textScaleProvider.notifier).choose(TextScaleLevel.normal);
      await pending;
      expect(c.read(textScaleProvider).value, TextScaleLevel.normal);
    });

    test('échelle : celle du système × celle du niveau (Normal = ×1,1 comme avant)', () {
      expect(appTextScaler(TextScaler.noScaling, TextScaleLevel.normal).scale(10), closeTo(11, 1e-9));
      expect(appTextScaler(TextScaler.linear(1.2), TextScaleLevel.large).scale(10), closeTo(15.6, 1e-9));
      expect(appTextScaler(TextScaler.linear(2), TextScaleLevel.extraLarge).scale(10), closeTo(30, 1e-9));
    });
  });

  testWidgets('réglage enregistré : appliqué au démarrage', (t) async {
    final app = SpeciesApp(location: '/settings');
    try {
      await t.runAsync(() => app.db.setMeta('text_scale', 'large'));
      await t.pumpWidget(app.widget);
      await settleSpecies(t);
      expect(scaleOf(t), closeTo(13, 1e-9));
    } finally {
      await app.dispose(t);
    }
  });

  testWidgets('Réglages > Affichage : choix appliqué, persisté, multiplié au système', (t) async {
    t.view.physicalSize = const Size(360 * 3, 640 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    t.platformDispatcher.textScaleFactorTestValue = 1.2;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final app = SpeciesApp(location: '/settings');
    try {
      await t.pumpWidget(app.widget);
      await settleSpecies(t);
      expect(scaleOf(t), closeTo(10 * 1.2 * 1.1, 1e-9));

      await t.tap(find.text('Affichage'));
      await settleSpecies(t);
      expect(find.byType(DisplayScreen), findsOneWidget);
      // Chaque choix montre un exemple à sa taille réelle.
      final normal = t.getSize(find.text('Cèpe de Bordeaux').first).height;
      final big = t.getSize(find.text('Cèpe de Bordeaux').last).height;
      expect(big, greaterThan(normal));

      await t.tap(find.text('Très grand'));
      await settleSpecies(t);
      expect(scaleOf(t), closeTo(10 * 1.2 * 1.5, 1e-9));
      expect(await t.runAsync(() => app.db.metaValue('text_scale')), 'xlarge');

      await t.tap(find.text('Normal'));
      await settleSpecies(t);
      expect(scaleOf(t), closeTo(10 * 1.2 * 1.1, 1e-9));
      expect(await t.runAsync(() => app.db.metaValue('text_scale')), 'normal');
    } finally {
      await app.dispose(t);
    }
  });

  testWidgets('encyclopédie en « Très grand » sur petit écran : rien ne déborde', (t) async {
    t.view.physicalSize = const Size(360 * 3, 640 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final app = SpeciesApp();
    try {
      await t.runAsync(() => app.db.setMeta('text_scale', 'xlarge'));
      await t.pumpWidget(app.widget);
      await settleSpecies(t);
      await t.tap(find.textContaining('Filtres'));
      await settleSpecies(t);
      final season = find.text('En saison ce mois-ci');
      await t.ensureVisible(season);
      await t.tap(season);
      await settleSpecies(t);
      expect(t.takeException(), isNull);
    } finally {
      await app.dispose(t);
    }
  });
}
