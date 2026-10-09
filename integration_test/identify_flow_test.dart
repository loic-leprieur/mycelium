// Parcours « Identifier » de bout en bout avec le VRAI modèle embarqué :
//
//   flutter test integration_test/identify_flow_test.dart -d macos
//
// Photo -> analyse locale -> écran de résultat -> décision de l'utilisateur ->
// historique en base. Le choix de la photo (fenêtre système) est remplacé par
// un fichier de test ; tout le reste est réel (modèle, ONNX Runtime, stockage).
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mycelium/app.dart';
import 'package:mycelium/core/router.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/data/photo_store.dart';
import 'package:mycelium/data/providers.dart';
import 'package:mycelium/features/identify/identifier_provider.dart';
import 'package:mycelium/features/identify/ui/result_screen.dart';
import 'package:mycelium/features/map/location.dart';
import 'package:mycelium/features/map/map_config.dart';

import 'clip_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('identification : photo, résultat, décision, historique', (t) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    final dir = await Directory.systemTemp.createTemp('mycelium_flow_test');
    final photo = File('${dir.path}/champignon.png')
      ..writeAsBytesSync(base64Decode(clipFixturePngBase64));

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) => db),
          locationProvider.overrideWith(
            (ref) => Stream.value(const LocationState(LocationStatus.unavailable)),
          ),
          tilesEnabledProvider.overrideWithValue(false),
          // Pas de fenêtre système : la « galerie » renvoie la photo de test.
          photoPickerProvider.overrideWithValue((_) async => photo.path),
        ],
        child: MyceliumApp(router: buildRouter(initialLocation: '/identify')),
      ),
    );

    // Le modèle se charge (quelques centaines de ms) : la bannière passe de
    // « Chargement » à « Identification sur l'appareil », sans mode démonstration.
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 250));
      if (find.text("Identification sur l'appareil").evaluate().isNotEmpty) break;
    }
    expect(find.text("Identification sur l'appareil"), findsOneWidget);
    expect(find.text('MODE DÉMONSTRATION'), findsNothing);

    // Sur ordinateur : un seul bouton « Choisir une photo » (pas d'appareil photo).
    await t.tap(find.text('Choisir une photo'));
    // La photo de test est petite (330 px) : la qualité est signalée (ID-8) et
    // l'utilisateur choisit de l'utiliser quand même.
    for (var i = 0; i < 80; i++) {
      await t.pump(const Duration(milliseconds: 250));
      if (find.text('Photo à vérifier').evaluate().isNotEmpty) break;
    }
    expect(find.text('Photo à vérifier'), findsOneWidget);
    expect(find.text('Refaire la photo'), findsOneWidget);
    await t.tap(find.text('Utiliser quand même'));
    for (var i = 0; i < 80; i++) {
      await t.pump(const Duration(milliseconds: 250));
      if (find.text('Résultat').evaluate().isNotEmpty) break;
    }
    expect(find.text('Résultat'), findsOneWidget);
    expect(find.text('Qualité de la photo'), findsOneWidget);

    // Image synthétique : le modèle doit répondre « hors base », sans forcer
    // d'espèce (RM-5), et rien n'est présenté comme une démonstration.
    expect(find.text('Identification insuffisante'), findsOneWidget);
    expect(find.text('Peut-être une espèce hors de la base'), findsOneWidget);
    expect(find.textContaining('DÉMONSTRATION'), findsNothing);
    final results = find.descendant(
      of: find.byType(ResultScreen),
      matching: find.byType(Scrollable),
    );
    // L'avertissement de sécurité est affiché sur chaque résultat (RM-4).
    await t.scrollUntilVisible(
      find.textContaining('Cette identification est une aide'),
      200,
      scrollable: results.first,
    );
    expect(find.textContaining('Cette identification est une aide'), findsOneWidget);
    // Aucune confirmation proposée tant que le modèle n'est pas sûr : l'utilisateur
    // peut seulement choisir lui-même l'espèce, ou dire qu'il ne sait pas.
    await t.scrollUntilVisible(find.text('Une autre espèce…'), 200,
        scrollable: results.first);
    expect(find.textContaining("C'est bien"), findsNothing);
    expect(find.text('Une autre espèce…'), findsOneWidget);

    // Décision de l'utilisateur : « Je ne sais pas » est enregistré tel quel (RM-3).
    await t.scrollUntilVisible(find.text('Je ne sais pas'), 200,
        scrollable: results.first);
    await t.tap(find.text('Je ne sais pas'));
    await t.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('Enregistré'), findsOneWidget);

    final rows = await db.select(db.identifications).get();
    expect(rows, hasLength(1));
    expect(rows.single.chosenSpeciesId, isNull);
    expect(rows.single.modelVersion, clipModelVersion);
    expect(rows.single.unknownScore, greaterThan(0.5));
    expect(jsonDecode(rows.single.top5Json) as List, isNotEmpty);
    expect(await resolveStoredPhoto(rows.single.photoPath), isNotNull,
        reason: 'la photo est copiée dans le dossier de l\'application');

    await t.pumpWidget(const SizedBox());
    await db.close();
    await dir.delete(recursive: true);
  });
}
