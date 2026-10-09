import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/features/identify/ui/identify_screen.dart';
import 'package:mycelium/features/journal/ui/harvest_form_sheet.dart';
import 'package:mycelium/features/journal/ui/outing_form_screen.dart';
import 'package:mycelium/features/map/ui/spot_form_screen.dart';
import 'package:mycelium/features/species/ui/species_detail_screen.dart';
import 'package:mycelium/features/map/ui/map_screen.dart';
import 'package:mycelium/features/species/ui/add_species_screen.dart';
import 'package:mycelium/features/species/ui/species_list_screen.dart';

/// Laisse les animations (dont celles qui se répètent) et les écritures en
/// base se terminer, sans `pumpAndSettle` qui ne s'arrêterait jamais.
Future<void> settle(WidgetTester t, {int ms = 600}) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
  await t.pump();
  await t.pump(Duration(milliseconds: ms));
  await t.pump(const Duration(milliseconds: 500));
}

/// Bouton retour de la barre du haut (infobulle française : « Retour »).
Future<void> goBack(WidgetTester t) async {
  await t.tap(find.byTooltip('Retour'));
  await settle(t);
}

Future<void> tapTab(WidgetTester t, String label) async {
  await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await settle(t);
}

/// Fait défiler la liste de [inside] (premier Scrollable qu'il contient) jusqu'à
/// rendre [target] visible. Les listes sont paresseuses : on ne s'appuie donc
/// pas sur un texte qui pourrait ne pas être construit.
Future<void> reveal(WidgetTester t, Finder target, {required Finder inside}) async {
  if (target.evaluate().isEmpty) {
    final scrollable = find.descendant(of: inside, matching: find.byType(Scrollable)).first;
    await t.dragUntilVisible(target, scrollable, const Offset(0, -140));
  }
  await t.ensureVisible(target);
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> tapRevealed(WidgetTester t, Finder target, {required Finder inside}) async {
  await reveal(t, target, inside: inside);
  await t.tap(target);
  await settle(t);
}

/// Carte : liste des coins, guidage à vol d'oiseau, arrêt, création d'un coin.
Future<void> runMapFlow(WidgetTester t) async {
  await settle(t);
  expect(find.text('Mes coins (3)'), findsOneWidget);
  expect(find.text('Coin des cèpes (test)'), findsOneWidget);

  // Un clic sur un coin lance le guidage.
  await t.tap(find.text('Coin des cèpes (test)'));
  await settle(t);
  expect(find.text('Guidage en cours'), findsOneWidget);
  expect(find.textContaining(" m à vol d'oiseau"), findsWidgets);
  expect(find.textContaining('Cap '), findsWidgets);
  await reveal(t, find.text('Autres coins'), inside: find.byType(MapScreen));
  expect(find.text('Autres coins'), findsOneWidget);

  // Arrêt du guidage. Le bouton est dans le résumé, au-dessus de « Autres coins » :
  // le défilement vers ce titre a pu le faire sortir de l'écran (il reste construit).
  await t.ensureVisible(find.text('Arrêter le guidage', skipOffstage: false));
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(find.text('Arrêter le guidage'));
  await settle(t);
  expect(find.text('Guidage en cours'), findsNothing);
  // Remonte en haut du panneau (liste paresseuse, restée défilée).
  await t.drag(
    find.descendant(of: find.byType(MapScreen), matching: find.byType(ListView)).first,
    const Offset(0, 700),
  );
  await settle(t);
  expect(find.text('Mes coins (3)'), findsOneWidget);

  // Création d'un coin à la position actuelle.
  await t.tap(find.text('Ajouter'));
  await settle(t);
  expect(find.text('Nouveau coin'), findsOneWidget);
  await t.enterText(find.byType(TextFormField).first, 'Mon coin test');
  await t.pump();
  await tapRevealed(t, find.text('Enregistrer'), inside: find.byType(SpotFormScreen));
  expect(find.text('Mes coins (4)'), findsOneWidget);
}

/// Identification (démonstration) : alerte sur espèce mortelle.
Future<void> runIdentifyFlow(WidgetTester t) async {
  await tapTab(t, 'Identifier');
  expect(find.text('MODE DÉMONSTRATION'), findsOneWidget);

  await tapRevealed(t, find.text('Champignon à lames avec anneau'),
      inside: find.byType(IdentifyScreen));
  await settle(t, ms: 1500);
  expect(find.text('ATTENTION : espèce dangereuse parmi les candidats'), findsOneWidget);
  expect(find.text('Amanite phalloïde'), findsWidgets);

  await goBack(t);
  await settle(t);
  expect(find.text('Champignon à lames avec anneau'), findsOneWidget);
}

/// Encyclopédie : recherche, fiche, confusions, ajout d'une espèce personnelle.
Future<void> runSpeciesFlow(WidgetTester t) async {
  await tapTab(t, 'Espèces');
  final search = find.descendant(
    of: find.byType(SpeciesListScreen),
    matching: find.byType(TextField),
  );

  await t.enterText(search, 'cèpe');
  await settle(t);
  expect(find.text('Cèpe de Bordeaux'), findsOneWidget);

  await t.tap(find.text('Cèpe de Bordeaux'));
  await settle(t);
  expect(find.text('Boletus edulis'), findsOneWidget);
  await tapRevealed(t, find.text('Bolet de Satan'),
      inside: find.byType(SpeciesDetailScreen));
  expect(find.text('Rubroboletus satanas'), findsOneWidget);
  await goBack(t);
  await settle(t);
  await goBack(t);
  await settle(t);

  // Ajout d'une espèce personnelle.
  await t.tap(find.text('Ajouter une espèce'));
  await settle(t);
  expect(find.text('Nouvelle espèce'), findsOneWidget);
  final fields = find.descendant(
    of: find.byType(AddSpeciesScreen),
    matching: find.byType(TextFormField),
  );
  await t.enterText(fields.first, 'Trompette test');
  await t.enterText(fields.at(1), 'Description de test');
  await t.pump();
  await tapRevealed(t, find.text('Enregistrer'), inside: find.byType(AddSpeciesScreen));

  await t.enterText(search, 'Trompette test');
  await settle(t);
  expect(find.widgetWithText(ListTile, 'Trompette test'), findsOneWidget);
  expect(find.text('Fiche personnelle, non vérifiée'), findsOneWidget);
}

/// Carnet : nouvelle sortie, récolte avec quantité et poids, totaux.
Future<void> runJournalFlow(WidgetTester t) async {
  await tapTab(t, 'Carnet');
  expect(find.text('Aucune sortie pour le moment'), findsOneWidget);

  await t.tap(find.text('Nouvelle sortie'));
  await settle(t);
  await tapRevealed(t, find.text('Créer la sortie'), inside: find.byType(OutingFormScreen));

  expect(find.text('Aucune récolte enregistrée.'), findsOneWidget);
  await t.tap(find.text('Ajouter une récolte'));
  await settle(t);
  expect(find.byType(HarvestFormSheet), findsOneWidget);

  final sheet = find.byType(HarvestFormSheet);
  // Photo, poids et quantité sont proposés.
  expect(find.descendant(of: sheet, matching: find.text('Photo de la récolte')), findsOneWidget);

  await t.tap(find.descendant(of: sheet, matching: find.byType(DropdownButtonFormField<String>)));
  await settle(t);
  // Le menu déroulant est une liste paresseuse : on fait défiler jusqu'à l'espèce.
  final girolle = find.text('Girolle');
  if (girolle.evaluate().isEmpty) {
    await t.dragUntilVisible(girolle, find.byType(Scrollable).last, const Offset(0, -120));
  }
  // Construit ne veut pas dire visible : on le ramène à l'écran avant de cliquer.
  await t.ensureVisible(girolle);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(girolle);
  await settle(t);

  final fields = find.descendant(of: sheet, matching: find.byType(TextField));
  await t.enterText(fields.at(0), '3');
  await t.enterText(fields.at(1), '850');
  await t.pump();
  await tapRevealed(t, find.descendant(of: sheet, matching: find.text('Ajouter')), inside: sheet);

  expect(find.byType(HarvestFormSheet), findsNothing);
  expect(find.text('Girolle'), findsOneWidget);
  expect(find.text('× 3'), findsOneWidget);
  expect(find.text('850 g'), findsOneWidget);
  expect(find.text('Total : 3 pièces · 850 g'), findsOneWidget);

  // Les totaux apparaissent dans la liste du carnet.
  await goBack(t);
  await settle(t);
  expect(find.textContaining('3 pièces · 850 g'), findsOneWidget);
}
