import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/features/journal/ui/outing_detail_screen.dart';
import 'package:mycelium/features/map/ui/spot_form_screen.dart';

import 'spot_support.dart';
import 'support/harness.dart';

final _form = find.byType(SpotFormScreen);

Future<Map<String, DateTime>> _seen(WidgetTester t, AppDatabase db, String spotId) async {
  final rows = await t.runAsync(() => db.select(db.spotSpecies).get());
  return {
    for (final r in rows!)
      if (r.spotId == spotId) r.speciesId: r.lastSeenAt,
  };
}

Future<void> _save(WidgetTester t) =>
    tapScrolled(t, find.text('Enregistrer'), inside: _form);

Future<void> _pick(WidgetTester t, String search, String name) async {
  await tapScrolled(t, find.text('Ajouter une espèce'), inside: _form);
  await t.enterText(find.byType(TextField).last, search);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(find.widgetWithText(ListTile, name));
  await settle(t);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await loadTestFonts();
  });

  group('Espèces observées (SPOT-4)', () {
    testWidgets('la fiche liste les espèces avec leur dernière observation', (t) async {
      await withSpotApp(t, location: '/map/spot?id=seed-0', (app) async {
        expect(find.text('Espèces observées'), findsOneWidget);
        expect(find.text('Cèpe de Bordeaux'), findsOneWidget);
        expect(find.text('Girolle'), findsOneWidget);
        // La sortie de septembre, plus ancienne, n'a pas fait reculer la date.
        expect(find.text('Dernière observation : 5 oct. 2026'), findsNWidgets(2));
      });
    });

    testWidgets('retirer une espèce : effectif à l\'enregistrement seulement', (t) async {
      await withSpotApp(t, location: '/map/spot?id=seed-0', (app) async {
        await t.tap(find.byTooltip('Retirer Cèpe de Bordeaux'));
        await settle(t);
        expect(find.text('Cèpe de Bordeaux'), findsNothing);
        expect((await _seen(t, app.db, 'seed-0')).keys, contains('cepe-de-bordeaux'));

        await _save(t);
        expect((await _seen(t, app.db, 'seed-0')).keys, ['girolle']);
        expect(find.text('Mes coins (4)'), findsOneWidget);
      });
    });

    testWidgets('quitter sans enregistrer ne change rien', (t) async {
      await withSpotApp(t, location: '/map/spot?id=seed-0', (app) async {
        await t.tap(find.byTooltip('Retirer Girolle'));
        await settle(t);
        await t.tap(find.byTooltip('Retour'));
        await settle(t);
        expect((await _seen(t, app.db, 'seed-0')).keys,
            unorderedEquals(['cepe-de-bordeaux', 'girolle']));
      });
    });

    testWidgets('ajouter une espèce depuis l\'encyclopédie', (t) async {
      await withSpotApp(t, location: '/map/spot?id=seed-0', (app) async {
        await _pick(t, 'morille', 'Morille');
        expect(find.text('Dernière observation : ${DateFormat.yMMMd('fr').format(DateTime.now())}'),
            findsOneWidget);

        final before = DateTime.now();
        await _save(t);
        final seen = await _seen(t, app.db, 'seed-0');
        expect(seen.keys, containsAll(['cepe-de-bordeaux', 'girolle', 'morille']));
        expect(seen['morille']!.isAfter(before.subtract(const Duration(minutes: 1))), isTrue);
        expect(seen['girolle'], day(10, 5), reason: 'les autres dates sont inchangées');
      });
    });

    testWidgets('le choix ne propose pas les espèces déjà notées', (t) async {
      await withSpotApp(t, location: '/map/spot?id=seed-0', (app) async {
        await tapScrolled(t, find.text('Ajouter une espèce'), inside: _form);
        final sheet = find.byType(BottomSheet);
        Finder choice(String name) =>
            find.descendant(of: sheet, matching: find.widgetWithText(ListTile, name));
        expect(choice('Cèpe d\'été'), findsOneWidget);
        expect(choice('Cèpe de Bordeaux'), findsNothing);
        expect(choice('Girolle'), findsNothing);

        // La recherche ignore les accents et la casse.
        await t.enterText(find.byType(TextField).last, 'CEPE');
        await t.pump(const Duration(milliseconds: 300));
        expect(choice('Cèpe d\'été'), findsOneWidget);
        expect(choice('Morille'), findsNothing);
      });
    });

    testWidgets('nouveau coin : espèces gardées en mémoire, écrites à l\'enregistrement',
        (t) async {
      await withSpotApp(t, location: '/map/spot?lat=48.6&lon=7.79', (app) async {
        await t.enterText(find.byType(TextFormField).first, 'Mon nouveau coin');
        await _pick(t, 'girolle', 'Girolle');
        expect(find.text('Girolle'), findsOneWidget);
        expect((await t.runAsync(() => app.db.select(app.db.spotSpecies).get()))!
            .where((r) => r.speciesId == 'girolle' && r.spotId != 'seed-0' && r.spotId != 'seed-1'),
            isEmpty, reason: 'rien n\'est écrit avant l\'enregistrement');

        await _save(t);
        final spots = await t.runAsync(() => app.db.select(app.db.spots).get());
        final created = spots!.singleWhere((s) => s.name == 'Mon nouveau coin');
        expect((await _seen(t, app.db, created.id)).keys, ['girolle']);
        // Il apparaît aussitôt sous « Chanterelles » dans le panneau.
        expect(find.text('Chanterelles (3)', skipOffstage: false), findsOneWidget);
      });
    });
  });

  group('Sorties à ce coin (SPOT-5)', () {
    testWidgets('dernière visite et sorties avec le résumé de leurs récoltes', (t) async {
      await withSpotApp(t, location: '/map/spot?id=seed-0', (app) async {
        await reveal(t, find.text('Sorties à ce coin'));
        expect(find.text('Dernière visite : 5 oct. 2026'), findsOneWidget);
        final fmt = DateFormat.yMMMMEEEEd('fr');
        expect(find.text(fmt.format(day(10, 5))), findsOneWidget);
        expect(find.text(fmt.format(day(9, 20))), findsOneWidget);
        expect(find.text('Cèpe de Bordeaux, Girolle · 5 pièces · 850 g'), findsOneWidget);
        expect(find.text('Cèpe de Bordeaux · 1 pièce'), findsOneWidget);
        // Les sorties des autres coins n'y figurent pas.
        expect(find.text(fmt.format(day(10, 7))), findsNothing);
      });
    });

    testWidgets('un appui sur une sortie ouvre le carnet, le retour revient à la fiche',
        (t) async {
      await withSpotApp(t, location: '/map/spot?id=seed-0', (app) async {
        final title = DateFormat.yMMMMEEEEd('fr').format(day(10, 5));
        await tapScrolled(t, find.text(title), inside: _form);
        expect(find.byType(OutingDetailScreen), findsOneWidget);
        expect(find.text('Sortie'), findsOneWidget);

        await t.tap(find.byTooltip('Retour'));
        await settle(t);
        expect(find.byType(OutingDetailScreen), findsNothing);
        expect(_form, findsOneWidget);
      });
    });

    testWidgets('coin jamais visité', (t) async {
      await withSpotApp(t, location: '/map/spot?id=seed-3', (app) async {
        await reveal(t, find.text('Sorties à ce coin'));
        expect(find.text('Jamais visité'), findsOneWidget);
        expect(find.textContaining('Aucune sortie enregistrée'), findsOneWidget);
        expect(find.textContaining('Aucune espèce notée'), findsOneWidget);
      });
    });

    testWidgets('au-delà de cinq sorties : les plus récentes, puis « Voir les autres »',
        (t) async {
      await withSpotApp(t, location: '/map/spot?id=seed-3', (app) async {
        final fmt = DateFormat.yMMMMEEEEd('fr');
        await reveal(t, find.text('Voir les 2 autres sorties'));
        expect(find.text('Dernière visite : 7 août 2026'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsNWidgets(5));
        expect(find.text(fmt.format(day(8, 3))), findsOneWidget);
        expect(find.text(fmt.format(day(8, 2)), skipOffstage: false), findsNothing);

        await t.tap(find.text('Voir les 2 autres sorties'));
        await settle(t);
        await reveal(t, find.text(fmt.format(day(8, 1))));
        expect(find.text('Voir les 2 autres sorties'), findsNothing);
        expect(find.text(fmt.format(day(8, 1))), findsOneWidget);
      }, seed: (db) async {
        await seedSpotData(db);
        for (var i = 1; i <= 7; i++) {
          await addOuting(db, 'o$i', day(8, i), spotId: 'seed-3');
        }
      });
    });
  });
}

/// Fait défiler la fiche jusqu'à [target].
Future<void> reveal(WidgetTester t, Finder target) async {
  if (target.evaluate().isEmpty) {
    await t.dragUntilVisible(
      target,
      find.descendant(of: _form, matching: find.byType(Scrollable)).first,
      const Offset(0, -140),
    );
  }
  await t.ensureVisible(target);
  await t.pump(const Duration(milliseconds: 300));
}
