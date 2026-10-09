import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/features/identify/history/place_sheet.dart';
import 'package:mycelium/features/identify/identifier.dart';
import 'package:mycelium/features/identify/ui/result_screen.dart';

import 'identify_history_support.dart';
import 'support/flows.dart';
import 'support/harness.dart';

/// Position de la photo = position GPS simulée du harnais.
const here = LatLng(testLat, testLon);

/// Un point à [meters] mètres de [here], dans la direction [bearing] (° depuis le nord).
LatLng away(double meters, [double bearing = 0]) =>
    const Distance().offset(here, meters, bearing);

Finder get confirmGirolle => find.text('C\'est bien : Girolle');
Finder get placeQuestion => find.text('Où l\'avez-vous trouvé ?');

Future<void> waitFor(WidgetTester t, Finder finder) =>
    settleUntil(t, () async => finder.evaluate().isNotEmpty);

Future<void> waitForSaved(WidgetTester t, HistoryApp app, {int count = 1}) => settleUntil(
      t,
      () async => (await app.db.select(app.db.identifications).get()).length >= count,
    );

Future<void> withApp(
  WidgetTester t,
  Future<void> Function(HistoryApp app) body, {
  ScreenCase screen = const ScreenCase('téléphone 412x915', 412, 915),
  bool withGps = true,
}) async {
  applyScreen(t, screen);
  final app = await HistoryApp.start(t, withGps: withGps);
  try {
    await body(app);
  } finally {
    await app.dispose(t);
  }
}

/// Ouvre l'écran de résultat pour [outcome], par la vraie navigation de l'application.
Future<void> openResult(WidgetTester t, HistoryApp app, IdentificationOutcome outcome) async {
  await t.pumpWidget(app.widget);
  await settleFor(t);
  unawaited(app.router.push('/identify/result', extra: outcome));
  await settleFor(t);
  expect(find.byType(ResultScreen), findsOneWidget);
}

/// « C'est bien : Girolle », puis attend la feuille « Où l'avez-vous trouvé ? ».
Future<void> chooseGirolle(WidgetTester t) async {
  await tapRevealed(t, confirmGirolle, inside: find.byType(ResultScreen));
  await waitFor(t, placeQuestion);
}

Future<void> tapInSheet(WidgetTester t, String label) =>
    tapRevealed(t, find.text(label), inside: find.byType(PlaceSheet));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await loadTestFonts();
  });

  for (final screen in [screenCases[0], screenCases[1], screenCases[2]]) {
    group(screen.name, () {
      testWidgets('coin proche (≤ 150 m) suggéré : un appui y range l\'identification',
          (t) async {
        await withApp(t, screen: screen, (app) async {
          await app.addSpot(t, id: 'near', name: 'Clairière aux girolles',
              lat: away(60).latitude, lon: away(60).longitude);
          await app.addSpot(t, id: 'far', name: 'Lisière lointaine',
              lat: away(900, 90).latitude, lon: away(900, 90).longitude);
          final photo = await app.takePhoto(t);
          await openResult(t, app, outcomeFor(photo, lat: testLat, lon: testLon));

          await chooseGirolle(t);
          expect(find.text('Espèce retenue : Girolle'), findsOneWidget);
          expect(find.text('Clairière aux girolles'), findsOneWidget);
          expect(find.text('Coin le plus proche, à 60 m de la photo'), findsOneWidget);
          expect(find.text('Lisière lointaine'), findsNothing, reason: 'trop loin pour être suggéré');

          await tapInSheet(t, 'Clairière aux girolles');
          await waitForSaved(t, app);

          final row = (await app.identifications(t)).single;
          expect(row.spotId, 'near');
          expect(row.chosenSpeciesId, 'girolle');
          expect(row.latitude, testLat);
          expect(row.longitude, testLon);
          expect(row.photoPath, startsWith('identification_photos/'));
          expect(await app.filesIn(t, 'identification_photos'), ['${row.id}.JPG']);
          final seen = (await app.spotSpecies(t)).single;
          expect((seen.spotId, seen.speciesId), ('near', 'girolle'));
          expect(await app.spots(t), hasLength(2), reason: 'aucun coin créé');

          expect(find.byType(PlaceSheet), findsNothing);
          await reveal(t, find.text('Enregistré'), inside: find.byType(ResultScreen));
          expect(find.text('Enregistré'), findsOneWidget);
          expect(
            find.text('Cette identification est dans votre historique, rangée dans '
                'le coin « Clairière aux girolles ».'),
            findsOneWidget,
          );
          expect(confirmGirolle, findsNothing, reason: 'la décision est prise');
        });
      });
    });
  }

  testWidgets('aucune suggestion quand le coin est à plus de 150 m', (t) async {
    await withApp(t, (app) async {
      await app.addSpot(t, id: 'far', name: 'Coin à 400 m',
          lat: away(400).latitude, lon: away(400).longitude);
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo, lat: testLat, lon: testLon));

      await chooseGirolle(t);
      expect(find.textContaining('Coin le plus proche'), findsNothing);
      expect(find.text('Coin à 400 m'), findsNothing);
      // Il reste possible de le choisir dans la liste.
      expect(find.text('Un autre coin…'), findsOneWidget);
      expect(find.text('Parmi votre coin'), findsOneWidget);
    });
  });

  testWidgets('le plus proche l\'emporte quand plusieurs coins sont dans le rayon', (t) async {
    await withApp(t, (app) async {
      await app.addSpot(t, id: 'a', name: 'À 120 m', lat: away(120).latitude, lon: away(120).longitude);
      await app.addSpot(t, id: 'b', name: 'À 30 m', lat: away(30, 90).latitude, lon: away(30, 90).longitude);
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo, lat: testLat, lon: testLon));

      await chooseGirolle(t);
      expect(find.text('À 30 m'), findsOneWidget);
      expect(find.text('À 120 m'), findsNothing);
      expect(find.text('Coin le plus proche, à 30 m de la photo'), findsOneWidget);
    });
  });

  testWidgets('photo de la galerie : pas de suggestion, la position actuelle sert de repère',
      (t) async {
    await withApp(t, (app) async {
      // Un coin tout près de moi, mais la photo n'a pas de position connue.
      await app.addSpot(t, id: 'close', name: 'Tout près de moi',
          lat: away(5).latitude, lon: away(5).longitude);
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo)); // galerie : ni latitude ni longitude

      await chooseGirolle(t);
      expect(find.textContaining('Coin le plus proche'), findsNothing);
      expect(find.text('Coin créé à ma position actuelle'), findsOneWidget);
      expect(find.text('Coin créé à l\'endroit de la photo'), findsNothing);
    });
  });

  testWidgets('nouveau coin ici : nom proposé d\'après le type, modifiable', (t) async {
    await withApp(t, (app) async {
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo, lat: testLat, lon: testLon));
      await chooseGirolle(t);
      expect(find.text('Coin créé à l\'endroit de la photo'), findsOneWidget);

      await tapInSheet(t, 'Nouveau coin ici');
      expect(find.text('Nom du nouveau coin'), findsOneWidget);
      final today = DateFormat('d MMM', 'fr').format(DateTime.now());
      expect(find.widgetWithText(TextField, 'Chanterelles – $today'), findsOneWidget,
          reason: 'la girolle est une chanterelle');

      await t.enterText(find.byType(TextField), 'Vallon des girolles');
      await t.pump();
      await t.tap(find.text('Créer le coin'));
      await waitForSaved(t, app);

      final spot = (await app.spots(t)).single;
      expect(spot.name, 'Vallon des girolles');
      expect(spot.latitude, testLat);
      expect(spot.longitude, testLon);
      final row = (await app.identifications(t)).single;
      expect(row.spotId, spot.id);
      expect(row.chosenSpeciesId, 'girolle');
      final seen = (await app.spotSpecies(t)).single;
      expect((seen.spotId, seen.speciesId), (spot.id, 'girolle'));

      await reveal(t, find.text('Enregistré'), inside: find.byType(ResultScreen));
      expect(find.textContaining('rangée dans le coin « Vallon des girolles »'), findsOneWidget);
    });
  });

  testWidgets('nom proposé tel quel : un seul appui sur « Créer le coin »', (t) async {
    await withApp(t, (app) async {
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo, lat: testLat, lon: testLon));
      await chooseGirolle(t);

      await tapInSheet(t, 'Nouveau coin ici');
      await t.tap(find.text('Créer le coin'));
      await waitForSaved(t, app);

      final today = DateFormat('d MMM', 'fr').format(DateTime.now());
      expect((await app.spots(t)).single.name, 'Chanterelles – $today');
    });
  });

  testWidgets('photo de la galerie : le nouveau coin est à ma position, pas la photo',
      (t) async {
    await withApp(t, (app) async {
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo));
      await chooseGirolle(t);

      await tapInSheet(t, 'Nouveau coin ici');
      await t.tap(find.text('Créer le coin'));
      await waitForSaved(t, app);

      final spot = (await app.spots(t)).single;
      expect(spot.latitude, testLat, reason: 'position GPS actuelle');
      expect(spot.longitude, testLon);
      final row = (await app.identifications(t)).single;
      expect(row.spotId, spot.id);
      expect(row.latitude, isNull, reason: 'la position de la photo n\'est pas inventée');
      expect(row.longitude, isNull);
    });
  });

  testWidgets('nom vide refusé ; annuler la saisie revient à la feuille sans rien écrire',
      (t) async {
    await withApp(t, (app) async {
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo, lat: testLat, lon: testLon));
      await chooseGirolle(t);

      await tapInSheet(t, 'Nouveau coin ici');
      await t.enterText(find.byType(TextField), '   ');
      await t.pump();
      final create = find.widgetWithText(FilledButton, 'Créer le coin');
      expect(t.widget<FilledButton>(create).onPressed, isNull, reason: 'un coin a toujours un nom');

      await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Annuler')));
      await settle(t);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(PlaceSheet), findsOneWidget, reason: 'on peut choisir autre chose');
      expect(await app.identifications(t), isEmpty);
      expect(await app.spots(t), isEmpty);
    });
  });

  testWidgets('un autre coin : liste du plus proche au plus éloigné', (t) async {
    await withApp(t, (app) async {
      await app.addSpot(t, id: 'far', name: 'Aaa lointain', lat: away(900).latitude, lon: away(900).longitude);
      await app.addSpot(t, id: 'mid', name: 'Mmm moyen', lat: away(500, 180).latitude, lon: away(500, 180).longitude);
      await app.addSpot(t, id: 'close', name: 'Zzz proche', lat: away(200, 90).latitude, lon: away(200, 90).longitude);
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo, lat: testLat, lon: testLon));
      await chooseGirolle(t);
      expect(find.text('Parmi vos 3 coins'), findsOneWidget);

      await tapInSheet(t, 'Un autre coin…');
      await waitFor(t, find.text('Choisir un coin'));
      expect(find.text('Du plus proche au plus éloigné'), findsOneWidget);
      final close = t.getTopLeft(find.text('Zzz proche')).dy;
      final mid = t.getTopLeft(find.text('Mmm moyen')).dy;
      final far = t.getTopLeft(find.text('Aaa lointain')).dy;
      expect(close, lessThan(mid));
      expect(mid, lessThan(far));
      expect(find.text('à 200 m'), findsOneWidget);

      await t.tap(find.text('Mmm moyen'));
      await waitForSaved(t, app);
      final row = (await app.identifications(t)).single;
      expect(row.spotId, 'mid');
      final seen = (await app.spotSpecies(t)).single;
      expect((seen.spotId, seen.speciesId), ('mid', 'girolle'));
    });
  });

  testWidgets('un autre coin : sans aucune position, par ordre alphabétique', (t) async {
    await withApp(t, withGps: false, (app) async {
      await app.addSpot(t, id: 'z', name: 'Zone des sapins', lat: 48.0, lon: 7.0);
      await app.addSpot(t, id: 'e', name: 'Étang des mousses', lat: 48.1, lon: 7.1);
      await app.addSpot(t, id: 'a', name: 'Abri du chasseur', lat: 48.2, lon: 7.2);
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo)); // galerie, GPS absent
      await chooseGirolle(t);

      await tapInSheet(t, 'Un autre coin…');
      await waitFor(t, find.text('Choisir un coin'));
      expect(find.text('Par ordre alphabétique'), findsOneWidget);
      final abri = t.getTopLeft(find.text('Abri du chasseur')).dy;
      final etang = t.getTopLeft(find.text('Étang des mousses')).dy;
      final zone = t.getTopLeft(find.text('Zone des sapins')).dy;
      expect(abri, lessThan(etang), reason: 'sans tenir compte des accents');
      expect(etang, lessThan(zone));
    });
  });

  testWidgets('sans position ni GPS : « Nouveau coin ici » est indisponible', (t) async {
    await withApp(t, withGps: false, (app) async {
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo));
      await chooseGirolle(t);

      expect(find.text('Position GPS indisponible'), findsOneWidget);
      await tapInSheet(t, 'Nouveau coin ici');
      expect(find.text('Nom du nouveau coin'), findsNothing);
      expect(find.byType(PlaceSheet), findsOneWidget);
      // On peut toujours garder la photo sans emplacement.
      expect(find.text('Un autre coin…'), findsNothing, reason: 'aucun coin enregistré');
      await tapInSheet(t, 'Sans emplacement');
      await waitForSaved(t, app);
      expect((await app.identifications(t)).single.spotId, isNull);
    });
  });

  testWidgets('sans emplacement : photo et espèce gardées, ni coin ni espèce observée',
      (t) async {
    await withApp(t, (app) async {
      await app.addSpot(t, id: 'near', name: 'Coin voisin',
          lat: away(40).latitude, lon: away(40).longitude);
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo, lat: testLat, lon: testLon));
      await chooseGirolle(t);

      await tapInSheet(t, 'Sans emplacement');
      await waitForSaved(t, app);

      final row = (await app.identifications(t)).single;
      expect(row.chosenSpeciesId, 'girolle');
      expect(row.spotId, isNull);
      expect(row.latitude, testLat, reason: 'la position de la photo reste enregistrée');
      expect(await app.spotSpecies(t), isEmpty);
      expect(await app.spots(t), hasLength(1));
      await reveal(t, find.text('Enregistré'), inside: find.byType(ResultScreen));
      expect(find.textContaining('avec l\'espèce que vous avez retenue'), findsOneWidget);
    });
  });

  testWidgets('« Annuler » dans la feuille : rien n\'est enregistré, on peut recommencer',
      (t) async {
    await withApp(t, (app) async {
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo, lat: testLat, lon: testLon));
      await chooseGirolle(t);

      await tapInSheet(t, 'Annuler');
      await settleFor(t);
      expect(find.byType(PlaceSheet), findsNothing);
      expect(await app.identifications(t), isEmpty);
      expect(await app.filesIn(t, 'identification_photos'), isEmpty, reason: 'photo non copiée');

      // Les boutons de décision sont de nouveau utilisables.
      await chooseGirolle(t);
      await tapInSheet(t, 'Sans emplacement');
      await waitForSaved(t, app);
      expect(await app.identifications(t), hasLength(1));
    });
  });

  testWidgets('toucher à côté de la feuille équivaut à annuler', (t) async {
    await withApp(t, (app) async {
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo, lat: testLat, lon: testLon));
      await chooseGirolle(t);

      await t.tapAt(const Offset(200, 20)); // le fond sombre, au-dessus de la feuille
      await settleFor(t);
      expect(find.byType(PlaceSheet), findsNothing);
      expect(await app.identifications(t), isEmpty);
      expect(confirmGirolle, findsOneWidget);
    });
  });

  testWidgets('« Je ne sais pas » : pas de feuille, photo et position gardées, sans coin',
      (t) async {
    await withApp(t, (app) async {
      await app.addSpot(t, id: 'near', name: 'Coin voisin',
          lat: away(40).latitude, lon: away(40).longitude);
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo, lat: testLat, lon: testLon));

      await tapRevealed(t, find.text('Je ne sais pas'), inside: find.byType(ResultScreen));
      await waitForSaved(t, app);

      expect(placeQuestion, findsNothing);
      final row = (await app.identifications(t)).single;
      expect(row.chosenSpeciesId, isNull);
      expect(row.spotId, isNull);
      expect(row.latitude, testLat);
      expect(row.longitude, testLon);
      expect(row.photoPath, startsWith('identification_photos/'));
      expect(jsonDecode(row.top5Json), isNotEmpty, reason: 'le résultat du modèle est conservé');
      expect(await app.spotSpecies(t), isEmpty);
      await reveal(t, find.text('Enregistré'), inside: find.byType(ResultScreen));
      expect(find.text('Cette photo est dans votre historique, sans nom d\'espèce.'), findsOneWidget);
    });
  });

  testWidgets('une autre espèce : recherche sans accents, puis lieu ; le modèle reste intact',
      (t) async {
    await withApp(t, (app) async {
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo, lat: testLat, lon: testLon));

      await tapRevealed(t, find.text('Une autre espèce…'), inside: find.byType(ResultScreen));
      expect(find.text('Quelle espèce ?'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'cepe');
      await t.pump();
      final dialog = find.byType(Dialog);
      expect(find.descendant(of: dialog, matching: find.text('Cèpe de Bordeaux')), findsOneWidget,
          reason: 'l\'accent oublié ne gêne pas');
      expect(find.descendant(of: dialog, matching: find.text('Girolle')), findsNothing);

      await t.tap(find.descendant(of: dialog, matching: find.text('Cèpe de Bordeaux')));
      await waitFor(t, placeQuestion);
      expect(find.text('Espèce retenue : Cèpe de Bordeaux'), findsOneWidget);
      await tapInSheet(t, 'Sans emplacement');
      await waitForSaved(t, app);

      final row = (await app.identifications(t)).single;
      expect(row.chosenSpeciesId, 'cepe-de-bordeaux');
      expect((jsonDecode(row.top5Json) as List).first['id'], 'girolle',
          reason: 'RM-3 : la proposition du modèle est conservée telle quelle');
    });
  });

  testWidgets('une autre espèce : fermer la liste n\'enregistre rien', (t) async {
    await withApp(t, (app) async {
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo));

      await tapRevealed(t, find.text('Une autre espèce…'), inside: find.byType(ResultScreen));
      await t.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Annuler')));
      await settleFor(t);

      expect(find.byType(Dialog), findsNothing);
      expect(placeQuestion, findsNothing);
      expect(await app.identifications(t), isEmpty);
    });
  });

  testWidgets('« Ajouter à une sortie ? » vient après la feuille d\'emplacement', (t) async {
    await withApp(t, (app) async {
      await t.runAsync(() => app.db.upsertOuting(
          OutingsCompanion.insert(id: 'o1', startedAt: DateTime(2026, 10, 8), spotId: const Value(null))));
      final photo = await app.takePhoto(t);
      await openResult(t, app, outcomeFor(photo, lat: testLat, lon: testLon));
      await chooseGirolle(t);
      expect(find.text('Ajouter à une sortie ?'), findsNothing, reason: 'pas avant l\'emplacement');

      await tapInSheet(t, 'Sans emplacement');
      await waitFor(t, find.text('Ajouter à une sortie ?'));
      expect(await app.identifications(t), hasLength(1), reason: 'déjà enregistrée');
      await settleFor(t);
      await tapRevealed(t, find.text('Non merci'), inside: find.byType(BottomSheet));
      await settleFor(t);
      expect(find.text('Ajouter à une sortie ?'), findsNothing);
    });
  });

  testWidgets('un résultat de démonstration ne propose aucun enregistrement', (t) async {
    await withApp(t, (app) async {
      await t.pumpWidget(app.widget);
      await settleFor(t);
      final demo = applySafetyRules(
        FakeIdentifier.scenarios.first.candidates,
        edibilityOf: seedEdibilityOf,
        isDemo: true,
        scenarioLabel: 'test',
      );
      unawaited(app.router.push('/identify/result', extra: demo));
      await settleFor(t);

      expect(find.byType(ResultScreen), findsOneWidget);
      expect(find.text('Votre décision'), findsNothing);
      expect(confirmGirolle, findsNothing);
      expect(await app.identifications(t), isEmpty);
    });
  });
}
