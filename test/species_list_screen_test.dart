import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mycelium/core/group_filter.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/features/species/ui/danger_badge.dart';
import 'package:mycelium/features/species/ui/species_list_screen.dart';

import 'species_support.dart';
import 'support/harness.dart';

Future<void> open(WidgetTester t, SpeciesApp app) async {
  t.view.physicalSize = const Size(412 * 2.625, 3000 * 2.625);
  t.view.devicePixelRatio = 2.625;
  addTearDown(t.view.reset);
  await t.pumpWidget(app.widget);
  await settleSpecies(t);
}

Finder tile(String name) => find.widgetWithText(ListTile, name);

Future<void> openFilters(WidgetTester t) async {
  await t.tap(find.textContaining('Filtres'));
  await settleSpecies(t);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await loadTestFonts();
  });

  testWidgets('filtres combinés : comestibilité, habitat, saison, réinitialisation', (t) async {
    final app = SpeciesApp(now: DateTime(2026, 10, 9));
    try {
      await open(t, app);
      expect(tile('Girolle'), findsOneWidget);

      await openFilters(t);
      await t.tap(find.widgetWithText(FilterChip, 'Bon comestible'));
      await t.tap(find.textContaining('Conifères ('));
      await settleSpecies(t);
      expect(find.textContaining('Filtres (2)'), findsOneWidget);
      expect(find.text('7 espèces sur 21'), findsOneWidget);
      expect(tile('Girolle'), findsOneWidget);
      expect(tile('Cèpe d\'été'), findsNothing);
      expect(tile('Amanite phalloïde'), findsNothing);

      // En saison ce mois-ci (octobre) : le cèpe des pins y est, pas le bolet de Satan.
      await t.tap(find.text('En saison ce mois-ci'));
      await settleSpecies(t);
      expect(find.textContaining('Filtres (3)'), findsOneWidget);
      expect(tile('Cèpe des pins'), findsOneWidget);

      // Un autre mois : mars -> plus aucun bon comestible de conifères.
      await t.tap(find.text('Un autre mois…'));
      await settleSpecies(t);
      await t.tap(find.text('Mars'));
      await settleSpecies(t);
      expect(find.text('Aucune espèce ne correspond'), findsOneWidget);
      expect(find.text('0 espèce sur 21'), findsOneWidget);

      await t.tap(find.text('Réinitialiser les filtres'));
      await settleSpecies(t);
      expect(find.text('Aucune espèce ne correspond'), findsNothing);
      expect(find.textContaining('sur 21'), findsNothing);
      expect(tile('Amanite phalloïde'), findsWidgets);
    } finally {
      await app.dispose(t);
    }
  });

  testWidgets('type via les pastilles et recherche combinée', (t) async {
    final app = SpeciesApp();
    try {
      await open(t, app);
      await openFilters(t);
      final amanites = find.widgetWithText(FilterChip, 'Amanites (3)');
      await t.dragUntilVisible(
        amanites,
        find.descendant(of: find.byType(GroupFilterBar), matching: find.byType(Scrollable)),
        const Offset(-150, 0),
      );
      await t.ensureVisible(amanites);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(amanites);
      await settleSpecies(t);
      expect(find.text('3 espèces sur 21'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'tue');
      await settleSpecies(t);
      expect(find.text('1 espèce sur 21'), findsOneWidget);
      expect(tile('Amanite tue-mouches'), findsOneWidget);
      // Les types de la carte ne sont pas touchés par ce filtre local.
      final container = ProviderScope.containerOf(t.element(find.byType(SpeciesListScreen)));
      expect(container.read(mapGroupFilterProvider), isEmpty);
    } finally {
      await app.dispose(t);
    }
  });

  testWidgets('fiche personnelle sans habitat : signalée puis affichable', (t) async {
    final app = SpeciesApp();
    try {
      await t.runAsync(() => app.db.upsertCustomSpecies(CustomSpeciesCompanion.insert(
            id: 'perso', commonName: 'Trompette test', description: const Value('x'), createdAt: DateTime(2026),
          )));
      await open(t, app);
      await openFilters(t);
      await t.tap(find.textContaining('Conifères ('));
      await settleSpecies(t);
      expect(tile('Trompette test'), findsNothing);
      expect(find.textContaining('1 fiche sans information'), findsOneWidget);
      expect(find.textContaining('est masquée'), findsOneWidget);
      await tapScrolled(t, find.text('Afficher'));
      expect(tile('Trompette test'), findsOneWidget);
      expect(find.textContaining('est affichée'), findsOneWidget);
    } finally {
      await app.dispose(t);
    }
  });

  testWidgets('badges et rubrique des espèces mortelles', (t) async {
    final app = SpeciesApp();
    try {
      await open(t, app);
      expect(find.text('Espèces mortelles à connaître'), findsOneWidget);
      expect(find.text('4 espèces : ne jamais en consommer'), findsOneWidget);
      // Rubrique ouverte : les 4 espèces mortelles y figurent.
      expect(find.widgetWithText(ListTile, 'Galère marginée'), findsWidgets);

      // Repliable.
      await t.tap(find.text('Espèces mortelles à connaître'));
      await settleSpecies(t);
      expect(find.text('4 espèces : ne jamais en consommer'), findsOneWidget);

      // Badge sur chaque espèce toxique ou mortelle de la liste (7), aucun ailleurs.
      await t.enterText(find.byType(TextField), '');
      await settleSpecies(t);
      var badges = find.byType(DangerBadge);
      expect(badges.evaluate().length, lessThanOrEqualTo(7));
      expect(find.descendant(of: tile('Amanite phalloïde'), matching: find.text('MORTEL')), findsOneWidget);
      expect(find.descendant(of: tile('Amanite panthère'), matching: find.text('TOXIQUE')), findsOneWidget);
      expect(find.descendant(of: tile('Girolle'), matching: find.byType(DangerBadge)), findsNothing);

      // La rubrique disparaît dès qu'on filtre ou qu'on cherche.
      await t.enterText(find.byType(TextField), 'amanite');
      await settleSpecies(t);
      expect(find.text('Espèces mortelles à connaître'), findsNothing);
      badges = find.byType(DangerBadge);
      expect(badges, findsNWidgets(3));
    } finally {
      await app.dispose(t);
    }
  });

  testWidgets('fiche dangereuse : lien « Intoxication : que faire ? »', (t) async {
    final app = SpeciesApp(location: '/species/amanite-phalloide');
    try {
      await open(t, app);
      final link = find.text('Intoxication : que faire ?');
      expect(link, findsOneWidget);
      await t.tap(link);
      await settleSpecies(t);
      final router = GoRouter.of(t.element(find.byType(Scaffold).first));
      expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/settings/safety');
    } finally {
      await app.dispose(t);
    }
  });

  testWidgets('fiche comestible : pas de lien d\'intoxication', (t) async {
    final app = SpeciesApp(location: '/species/girolle');
    try {
      await open(t, app);
      expect(find.text('Intoxication : que faire ?'), findsNothing);
    } finally {
      await app.dispose(t);
    }
  });
}
