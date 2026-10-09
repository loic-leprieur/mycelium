import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mycelium/app.dart';
import 'package:mycelium/core/router.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/data/providers.dart';
import 'package:mycelium/features/identify/identifier_provider.dart';
import 'package:mycelium/features/map/location.dart';
import 'package:mycelium/features/map/map_config.dart';

/// Position GPS simulée : forêt de la Robertsau, Strasbourg.
const testLat = 48.612;
const testLon = 7.7916;

Position testPosition() => Position(
      latitude: testLat,
      longitude: testLon,
      timestamp: DateTime(2026, 10, 8),
      accuracy: 8,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// Application de test : base en mémoire, GPS simulé, pas de tuiles réseau.
class TestApp {
  TestApp._(this.db, this.widget);

  final AppDatabase db;
  final Widget widget;

  factory TestApp({String initialLocation = '/map'}) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    final widget = ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) => db),
        locationProvider.overrideWith(
          (ref) => Stream.value(LocationState(LocationStatus.ok, testPosition())),
        ),
        tilesEnabledProvider.overrideWithValue(false),
        // Les tests ne dépendent pas du modèle (115 Mo, non versionné) : démo seule.
        identifierProvider.overrideWith((ref) async => null),
      ],
      child: MyceliumApp(router: buildRouter(initialLocation: initialLocation)),
    );
    return TestApp._(db, widget);
  }

  /// Trois coins à quelques centaines de mètres de la position simulée.
  Future<void> seedSpots(WidgetTester t) => t.runAsync(() async {
        final now = DateTime(2026, 10, 8);
        final spots = [
          ('Coin des cèpes (test)', 'Conifères', 48.6150, 7.7940, true),
          ('Clairière aux girolles (test)', 'Feuillus', 48.6090, 7.7880, false),
          ('Lisière des morilles (test)', 'Mixte', 48.6200, 7.8000, false),
        ];
        for (final (i, s) in spots.indexed) {
          await db.upsertSpot(SpotsCompanion.insert(
            id: 'seed-$i',
            name: s.$1,
            latitude: s.$3,
            longitude: s.$4,
            forestType: Value(s.$2),
            isFavorite: Value(s.$5),
            createdAt: now,
            updatedAt: now,
          ));
        }
      });

  Future<void> dispose(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    await t.runAsync(db.close);
  }
}

/// Charge Roboto et les icônes Material depuis le SDK Flutter, pour que les
/// tests mesurent le texte comme sur un vrai appareil (sinon la police de test,
/// très large, provoque de faux dépassements).
Future<void> loadTestFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';

  Future<ByteData> read(String name) async {
    final bytes = await File('$dir/$name').readAsBytes();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }

  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      if (File('$dir/$f').existsSync()) loader.addFont(read(f));
    }
    await loader.load();
  }

  await family('Roboto', [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-italic.ttf',
  ]);
  // Les titres demandent Georgia : on la remplace par Roboto Bold.
  await family('Georgia', ['roboto-bold.ttf']);
  await family('MaterialIcons', ['materialicons-regular.otf']);
}


/// Tailles d'écran testées (en pixels logiques).
class ScreenCase {
  const ScreenCase(this.name, this.width, this.height, [this.pixelRatio = 2.625]);

  final String name;
  final double width;
  final double height;
  final double pixelRatio;
}

const screenCases = [
  ScreenCase('petit téléphone 360x640', 360, 640, 3),
  ScreenCase('téléphone 412x915', 412, 915),
  ScreenCase('téléphone paysage 915x412', 915, 412),
  ScreenCase('fenêtre Windows 1280x720', 1280, 720, 1),
];

void applyScreen(WidgetTester t, ScreenCase screen) {
  t.view.physicalSize = Size(screen.width * screen.pixelRatio, screen.height * screen.pixelRatio);
  t.view.devicePixelRatio = screen.pixelRatio;
  addTearDown(t.view.reset);
}
