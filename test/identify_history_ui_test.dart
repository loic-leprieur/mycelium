import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mycelium/core/group_filter.dart';
import 'package:mycelium/core/safety_widgets.dart';
import 'package:mycelium/features/identify/history/detail_screen.dart';
import 'package:mycelium/features/identify/history/history_screen.dart';
import 'package:mycelium/features/identify/history/stored_photo.dart';
import 'package:mycelium/features/map/navigation.dart';
import 'package:mycelium/features/species/domain/species_groups.dart';
import 'package:mycelium/features/species/ui/species_detail_screen.dart';
import 'package:path/path.dart' as p;

import 'identify_history_support.dart';
import 'support/flows.dart';
import 'support/harness.dart';

String top5(List<(String, double)> items) =>
    jsonEncode([for (final (id, score) in items) {'id': id, 'score': score}]);

/// Quatre identifications : girolle (coin, photo), cèpe (coin, photo),
/// inconnue (photo absente, hors base), morille (photo, un sosie mortel proposé).
Future<void> seed(WidgetTester t, HistoryApp app) async {
  await app.addSpot(t, id: 'sg', name: 'Clairière aux girolles', lat: 48.61, lon: 7.79);
  await app.addSpot(t, id: 'sc', name: 'Coin des cèpes', lat: 48.62, lon: 7.80);
  await app.addIdentification(t,
      id: 'i1',
      photoPath: await app.storePhoto(t, 'identification_photos/i1.png'),
      at: DateTime(2026, 10, 9, 14, 32),
      species: 'girolle',
      spotId: 'sg',
      lat: 48.61,
      lon: 7.79,
      unknownScore: 0.05,
      top5: top5([('girolle', 0.617), ('fausse-girolle', 0.2), ('chanterelle-en-tube', 0.08)]));
  await app.addIdentification(t,
      id: 'i2',
      photoPath: await app.storePhoto(t, 'identification_photos/i2.png'),
      at: DateTime(2026, 10, 8, 10, 5),
      species: 'cepe-de-bordeaux',
      spotId: 'sc',
      top5: top5([('cepe-de-bordeaux', 0.81), ('bolet-bai', 0.09)]));
  await app.addIdentification(t,
      id: 'i3',
      photoPath: 'identification_photos/absente.png', // fichier introuvable
      at: DateTime(2026, 10, 7, 9, 0),
      unknownScore: 0.4,
      top5: top5([('amanite-phalloide', 0.3), ('girolle', 0.2)]));
  await app.addIdentification(t,
      id: 'i4',
      photoPath: await app.storePhoto(t, 'identification_photos/i4.png'),
      at: DateTime(2026, 10, 6, 18, 0),
      species: 'morille',
      top5: top5([('morille', 0.52), ('gyromitre', 0.41)]));
}

Future<void> withApp(
  WidgetTester t,
  Future<void> Function(HistoryApp app) body, {
  ScreenCase screen = const ScreenCase('téléphone 412x915', 412, 915),
  String location = '/identify/history',
  bool seeded = true,
}) async {
  applyScreen(t, screen);
  final app = await HistoryApp.start(t, initialLocation: location);
  try {
    if (seeded) await seed(t, app);
    await t.pumpWidget(app.widget);
    await settleFor(t);
    await body(app);
  } finally {
    await app.dispose(t);
  }
}

List<String> allTexts(WidgetTester t) => [
      for (final w in t.widgetList<Text>(find.byType(Text, skipOffstage: false)))
        if (w.data != null) w.data!,
    ];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await loadTestFonts();
  });

  testWidgets('historique vide : message et titre sans nombre', (t) async {
    await withApp(t, seeded: false, (app) async {
      expect(find.text('Mes identifications'), findsOneWidget);
      expect(find.text('Aucune identification enregistrée'), findsOneWidget);
    });
  });

  testWidgets('liste : récentes d\'abord, espèce, date, coin, proposition du modèle', (t) async {
    await withApp(t, (app) async {
      expect(find.text('Mes identifications (4)'), findsOneWidget);
      final y = [
        for (final n in ['Girolle', 'Cèpe de Bordeaux', 'Espèce inconnue', 'Morille'])
          t.getTopLeft(find.text(n)).dy,
      ];
      expect(y, orderedEquals([...y]..sort()));
      expect(find.text('9 oct. 2026 à 14:32'), findsOneWidget);
      expect(find.text('Clairière aux girolles'), findsOneWidget);
      expect(find.text('Coin des cèpes'), findsOneWidget);
      expect(find.text('Sans coin'), findsNWidgets(2));
      expect(find.text('Le modèle proposait : Girolle 62 %'), findsOneWidget);
      expect(find.text('Le modèle proposait : Cèpe de Bordeaux 81 %'), findsOneWidget);
      // Photo introuvable : repli propre, sans erreur.
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(find.byType(StoredPhoto), findsNWidgets(4));
    });
  });

  testWidgets('RM-4 : aucune mention de comestibilité dans l\'historique ni le détail',
      (t) async {
    await withApp(t, (app) async {
      void check() {
        for (final s in allTexts(t)) {
          final low = s.toLowerCase();
          expect(low.contains('comestible'), isFalse, reason: s);
          expect(low.contains('bon à manger'), isFalse, reason: s);
          expect(low.contains('sans danger'), isFalse, reason: s);
        }
      }

      check();
      await t.tap(find.text('Girolle'));
      await settleFor(t);
      check();
    });
  });

  testWidgets('filtre par type : comptes, sélection, « Tous »', (t) async {
    await withApp(t, (app) async {
      expect(find.text('Cèpes (1)'), findsOneWidget);
      expect(find.text('Chanterelles (1)'), findsOneWidget);
      expect(find.text('Morilles (1)'), findsOneWidget);
      expect(find.textContaining('Autres'), findsNothing, reason: 'l\'inconnue est hors types');

      await t.tap(find.text('Chanterelles (1)'));
      await settleFor(t);
      expect(find.text('Mes identifications (1 sur 4)'), findsOneWidget);
      expect(find.text('Girolle'), findsOneWidget);
      expect(find.text('Cèpe de Bordeaux'), findsNothing);
      expect(find.text('Espèce inconnue'), findsNothing);

      // Plusieurs types : l'un OU l'autre.
      await tapRevealed(t, find.text('Morilles (1)'), inside: find.byType(GroupFilterBar));
      await settleFor(t);
      expect(find.text('Mes identifications (2 sur 4)'), findsOneWidget);
      expect(find.text('Morille'), findsOneWidget);

      await t.drag(find.byType(GroupFilterBar), const Offset(600, 0));
      await settleFor(t);
      await t.tap(find.text('Tous'));
      await settleFor(t);
      expect(find.text('Mes identifications (4)'), findsOneWidget);
      expect(find.text('Espèce inconnue'), findsOneWidget);
    });
  });

  testWidgets('un type qui disparaît quitte la sélection (retain)', (t) async {
    await withApp(t, (app) async {
      await t.tap(find.text('Cèpes (1)'));
      await settleFor(t);
      expect(find.text('Mes identifications (1 sur 4)'), findsOneWidget);

      await t.runAsync(() => app.db.deleteIdentification('i2'));
      await settleFor(t);

      expect(app.container(t).read(historyGroupFilterProvider), isEmpty);
      expect(find.text('Mes identifications (3)'), findsOneWidget);
      expect(find.text('Girolle'), findsOneWidget);
      expect(find.text('Aucun résultat pour ce filtre'), findsNothing);
    });
  });

  testWidgets('filtre sans résultat : message et « Tout afficher »', (t) async {
    await withApp(t, (app) async {
      app.container(t).read(historyGroupFilterProvider.notifier).toggle(MushroomGroup.trompettes);
      await settleFor(t);
      expect(find.text('Aucun résultat pour ce filtre'), findsOneWidget);

      await t.tap(find.text('Tout afficher'));
      await settleFor(t);
      expect(find.text('Aucun résultat pour ce filtre'), findsNothing);
      expect(find.text('Mes identifications (4)'), findsOneWidget);
    });
  });

  testWidgets('détail : photo, espèce, propositions, date, coordonnées, coin, avertissement',
      (t) async {
    await withApp(t, (app) async {
      await t.tap(find.text('Girolle'));
      await settleFor(t);

      expect(find.byType(IdentificationDetailScreen), findsOneWidget);
      expect(find.byType(StoredPhoto), findsOneWidget);
      expect(find.text('Espèce retenue'), findsOneWidget);
      expect(find.text('Voir la fiche de l\'espèce'), findsOneWidget);
      expect(find.text('Le modèle proposait'), findsOneWidget);
      expect(find.text('1. Girolle'), findsOneWidget);
      expect(find.text('62 %'), findsOneWidget);
      expect(find.text('2. Fausse girolle'), findsOneWidget);
      expect(find.text('vendredi 9 octobre 2026 à 14:32'), findsOneWidget);
      expect(find.text('Clairière aux girolles'), findsOneWidget);
      expect(find.text('48.61000, 7.79000'), findsOneWidget);
      expect(find.text('Version du modèle : test-1'), findsOneWidget);
      expect(find.byType(SafetyDisclaimer), findsOneWidget);
      expect(find.text('Peut-être une espèce hors de la base'), findsNothing);
      expect(find.textContaining('espèce dangereuse'), findsNothing);
    });
  });

  testWidgets('détail : lien vers la fiche de l\'espèce', (t) async {
    await withApp(t, (app) async {
      await t.tap(find.text('Girolle'));
      await settleFor(t);
      await tapRevealed(t, find.text('Voir la fiche de l\'espèce'),
          inside: find.byType(IdentificationDetailScreen));
      expect(find.byType(SpeciesDetailScreen), findsOneWidget);
    });
  });

  testWidgets('détail : photo absente, hors base et alerte sur une proposition mortelle',
      (t) async {
    await withApp(t, (app) async {
      await t.tap(find.text('Espèce inconnue'));
      await settleFor(t);

      expect(find.text('Photo introuvable sur cet appareil.'), findsOneWidget);
      expect(find.text('Espèce inconnue'), findsOneWidget);
      expect(find.text('Peut-être une espèce hors de la base'), findsOneWidget);
      expect(find.textContaining('40 %'), findsOneWidget);
      expect(find.text('ATTENTION : espèce dangereuse parmi les propositions'), findsOneWidget);
      expect(find.textContaining('Amanite phalloïde'), findsWidgets);
      expect(find.text('Sans coin'), findsOneWidget);
      expect(find.text('Inconnue'), findsOneWidget);
      expect(find.text('Voir le coin'), findsNothing);
      expect(find.byType(SafetyDisclaimer), findsOneWidget);
    });
  });

  testWidgets('détail : la note « hors base » apparaît dès 15 %, pas en dessous', (t) async {
    for (final (score, shown) in [(0.15, true), (0.149, false)]) {
      applyScreen(t, const ScreenCase('téléphone 412x915', 412, 915));
      final app = await HistoryApp.start(t, initialLocation: '/identify/history/e1');
      try {
        await app.addIdentification(t,
            id: 'e1',
            photoPath: 'identification_photos/x.png',
            at: DateTime(2026, 10, 9),
            unknownScore: score,
            top5: top5([('girolle', 0.5)]));
        await t.pumpWidget(app.widget);
        await settleFor(t);
        expect(find.text('Peut-être une espèce hors de la base'),
            shown ? findsOneWidget : findsNothing,
            reason: 'score $score');
      } finally {
        await app.dispose(t);
      }
    }
  });

  testWidgets('détail : « Voir le coin » lance le guidage et ouvre la carte', (t) async {
    await withApp(t, (app) async {
      await t.tap(find.text('Girolle'));
      await settleFor(t);
      await tapRevealed(t, find.text('Voir le coin'),
          inside: find.byType(IdentificationDetailScreen));

      expect(app.container(t).read(navigationProvider).target?.id, 'sg');
      expect(app.router.routeInformationProvider.value.uri.path, '/map');
    });
  });

  testWidgets('changer l\'espèce : le coin la retient, le modèle reste intact (RM-3)', (t) async {
    await withApp(t, (app) async {
      await t.tap(find.text('Girolle'));
      await settleFor(t);
      final before = (await app.identifications(t)).firstWhere((r) => r.id == 'i1');

      await tapRevealed(t, find.text('Changer l\'espèce'),
          inside: find.byType(IdentificationDetailScreen));
      final dialog = find.byType(Dialog);
      await t.enterText(find.descendant(of: dialog, matching: find.byType(TextField)), 'morille');
      await t.pump();
      await t.tap(find.descendant(of: dialog, matching: find.text('Morille')));
      await settleFor(t);

      final row = (await app.identifications(t)).firstWhere((r) => r.id == 'i1');
      expect(row.chosenSpeciesId, 'morille');
      expect(row.top5Json, before.top5Json);
      expect(row.spotId, 'sg');
      final seen = (await app.spotSpecies(t)).single;
      expect((seen.spotId, seen.speciesId, seen.lastSeenAt), ('sg', 'morille', before.createdAt));
      expect(find.text('Espèce corrigée : Morille.'), findsOneWidget);
      expect(find.text('Morille'), findsWidgets);
      expect(find.text('1. Girolle'), findsOneWidget, reason: 'propositions du modèle inchangées');
    });
  });

  testWidgets('changer l\'espèce sans coin : rien dans spotSpecies ; « Je ne sais pas » possible',
      (t) async {
    await withApp(t, (app) async {
      await t.tap(find.text('Morille'));
      await settleFor(t);

      await tapRevealed(t, find.text('Changer l\'espèce'),
          inside: find.byType(IdentificationDetailScreen));
      await t.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), 'girolle');
      await t.pump();
      await t.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Girolle')));
      await settleFor(t);
      expect((await app.identifications(t)).firstWhere((r) => r.id == 'i4').chosenSpeciesId, 'girolle');
      expect(await app.spotSpecies(t), isEmpty);

      await tapRevealed(t, find.text('Changer l\'espèce'),
          inside: find.byType(IdentificationDetailScreen));
      await t.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Je ne sais pas')));
      await settleFor(t);
      expect((await app.identifications(t)).firstWhere((r) => r.id == 'i4').chosenSpeciesId, isNull);
      expect(find.text('Espèce inconnue'), findsOneWidget);
    });
  });

  testWidgets('supprimer : confirmation, puis ligne et photo supprimées', (t) async {
    await withApp(t, (app) async {
      await t.tap(find.text('Girolle'));
      await settleFor(t);
      final file = p.join(app.docs.path, 'identification_photos', 'i1.png');
      expect(await t.runAsync(() => Future.value(app.docs.existsSync())), isTrue);

      // Annuler ne supprime rien.
      await tapRevealed(t, find.text('Supprimer cette identification'),
          inside: find.byType(IdentificationDetailScreen));
      expect(find.text('Supprimer cette identification ?'), findsOneWidget);
      await t.tap(find.text('Annuler'));
      await settleFor(t);
      expect(await app.identifications(t), hasLength(4));

      await tapRevealed(t, find.text('Supprimer cette identification'),
          inside: find.byType(IdentificationDetailScreen));
      await t.tap(find.text('Supprimer'));
      await settleUntil(t, () async => (await app.db.select(app.db.identifications).get()).length == 3);
      await settleFor(t);

      expect((await app.identifications(t)).map((r) => r.id), isNot(contains('i1')));
      expect(await app.filesIn(t, 'identification_photos'), isNot(contains(p.basename(file))));
      expect(find.byType(IdentificationHistoryScreen), findsOneWidget);
      expect(find.text('Mes identifications (3)'), findsOneWidget);
      expect(await app.spots(t), hasLength(2), reason: 'les coins ne sont pas touchés');
    });
  });

  testWidgets('ancien chemin absolu : la photo est retrouvée', (t) async {
    applyScreen(t, const ScreenCase('téléphone 412x915', 412, 915));
    final app = await HistoryApp.start(t);
    try {
      await app.storePhoto(t, 'identification_photos/old.png');
      await app.addIdentification(t,
          id: 'old',
          photoPath: p.join(app.docs.path, 'identification_photos', 'old.png'),
          at: DateTime(2026, 9, 1),
          species: 'girolle');
      await t.pumpWidget(app.widget);
      await t.pump();
      app.router.go('/identify/history');
      await settleFor(t);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    } finally {
      await app.dispose(t);
    }
  });

  testWidgets('identification inconnue : message plutôt qu\'un écran vide', (t) async {
    await withApp(t, seeded: false, location: '/identify/history/nope', (app) async {
      expect(find.text('Cette identification n\'existe plus.'), findsOneWidget);
    });
  });

  for (final screen in screenCases) {
    testWidgets('${screen.name} : liste et détail sans débordement', (t) async {
      await withApp(t, screen: screen, (app) async {
        expect(find.text('Mes identifications (4)'), findsOneWidget);
        await t.tap(find.text('Girolle'));
        await settleFor(t);
        expect(find.byType(IdentificationDetailScreen), findsOneWidget);
        await reveal(t, find.byType(SafetyDisclaimer),
            inside: find.byType(IdentificationDetailScreen));
      });
    });
  }
}
