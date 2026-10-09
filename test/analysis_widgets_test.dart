import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/data/providers.dart';
import 'package:mycelium/features/identify/analysis/analysis_notes.dart';
import 'package:mycelium/features/identify/analysis/multi_photo_screen.dart';
import 'package:mycelium/features/identify/analysis/photo_quality.dart';
import 'package:mycelium/features/identify/analysis/quality_dialog.dart';
import 'package:mycelium/features/identify/identifier.dart';
import 'package:mycelium/features/identify/identifier_provider.dart';
import 'package:mycelium/features/identify/identify_flow.dart';
import 'package:mycelium/features/identify/ui/identify_screen.dart';

import 'support/harness.dart';

const _blurry = QualityReport(
  width: 640,
  height: 480,
  sharpness: 1,
  meanBrightness: 100,
  brightShare: 0,
  issues: [QualityIssue.blurry, QualityIssue.tooDark],
);

AppDatabase? _db;

/// Comme `testWidgets`, puis libère la base en mémoire et ses minuteries.
void tw(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    try {
      await body(t);
    } finally {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      await t.runAsync(() async => _db?.close());
      _db = null;
    }
  });
}

Widget scope(Widget child, {List<Override> overrides = const []}) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith((ref) => _db ??= AppDatabase(NativeDatabase.memory())),
      ...overrides,
    ],
    child: MaterialApp(home: child),
  );
}

IdentificationOutcome outcome({
  QualityReport? quality,
  int? month,
  int photos = 1,
  List<Candidate> candidates = const [Candidate(speciesId: 'morille', score: .6)],
  List<String> dangerous = const [],
}) =>
    IdentificationOutcome(
      candidates: candidates,
      isInsufficient: false,
      dangerousSpeciesIds: dangerous,
      isDemo: false,
      quality: quality,
      seasonMonth: month,
      photoCount: photos,
    );

class _Engine implements EmbeddingIdentifier {
  final embedded = <String>[];

  @override
  bool get isDemo => false;

  @override
  Future<List<double>> embed(String imagePath) async {
    embedded.add(imagePath);
    return [1, 0];
  }

  @override
  RawIdentification classify(List<double> embedding) => const RawIdentification(
        modelVersion: 't',
        candidates: [Candidate(speciesId: 'girolle', score: .9)],
      );

  @override
  Future<RawIdentification> identify(IdentificationInput input) async => classify([1, 0]);
}

void main() {
  setUpAll(loadTestFonts);

  tw('dialogue de qualité : refaire ou utiliser quand même', (t) async {
    for (final (label, expected) in [
      ('Refaire la photo', QualityChoice.retake),
      ('Utiliser quand même', QualityChoice.useAnyway),
    ]) {
      QualityChoice? choice;
      await t.pumpWidget(scope(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                choice = await askAboutPhotoQuality(context, _blurry, '/absente.jpg'),
            child: const Text('go'),
          ),
        ),
      )));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.textContaining('semble floue'), findsOneWidget);
      expect(find.textContaining('très sombre'), findsOneWidget);
      expect(find.textContaining('moins fiable'), findsOneWidget);
      await t.tap(find.text(label));
      await t.pumpAndSettle();
      expect(choice, expected);
      expect(find.text('Photo à vérifier'), findsNothing);
    }
  });

  group('AnalysisNotes', () {
    Future<void> show(WidgetTester t, IdentificationOutcome o) async {
      await t.pumpWidget(scope(Scaffold(body: SingleChildScrollView(child: AnalysisNotes(outcome: o)))));
      await t.pump();
    }

    tw('photo de mauvaise qualité signalée', (t) async {
      await show(t, outcome(quality: _blurry));
      expect(find.text('Qualité de la photo'), findsOneWidget);
      expect(find.textContaining('Photo floue, Photo trop sombre'), findsOneWidget);
    });

    tw('hors saison : morille en octobre, saison à cheval incluse', (t) async {
      await show(t, outcome(month: 10));
      expect(find.textContaining('hors saison habituelle pour : Morille (mars → mai)'), findsOneWidget);
      expect(find.textContaining('ne change ni les scores ni les alertes'), findsOneWidget);
      await show(t, outcome(month: 4));
      expect(find.text('Saison'), findsNothing);
      // Mois inconnu (galerie) : aucune remarque inventée.
      await show(t, outcome());
      expect(find.text('Saison'), findsNothing);
    });

    tw('une espèce dangereuse n\'est jamais déclarée « hors saison »', (t) async {
      await show(
        t,
        outcome(
          month: 10,
          candidates: const [Candidate(speciesId: 'gyromitre', score: .6)],
          dangerous: const ['gyromitre'],
        ),
      );
      expect(find.text('Saison'), findsNothing);
    });

    tw('multi-photos : nombre de photos et alerte d\'une photo seule', (t) async {
      await show(
        t,
        outcome(
          photos: 3,
          candidates: const [Candidate(speciesId: 'cepe-de-bordeaux', score: .7)],
          dangerous: const ['amanite-phalloide'],
        ),
      );
      expect(find.text('Résultat combiné de 3 photos'), findsOneWidget);
      expect(find.text('Alerte conservée'), findsOneWidget);
      expect(find.textContaining('Amanite phalloïde'), findsOneWidget);
    });

    tw('rien à dire : rien d\'affiché ; démonstration : rien non plus', (t) async {
      await show(t, outcome());
      expect(find.byType(Card), findsNothing);
      expect(find.text('Qualité de la photo'), findsNothing);
      await show(
        t,
        IdentificationOutcome(
          candidates: const [],
          isInsufficient: true,
          dangerousSpeciesIds: const [],
          isDemo: true,
          quality: _blurry,
        ),
      );
      expect(find.text('Qualité de la photo'), findsNothing);
    });
  });

  group('écran multi-photos', () {
    late List<ImageSource> asked;
    late int n;

    Future<IdentificationOutcome?> open(WidgetTester t, _Engine engine,
        {bool camera = true, QualityReport? quality}) async {
      asked = [];
      n = 0;
      IdentificationOutcome? result;
      await t.pumpWidget(scope(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await Navigator.of(context).push(
                MaterialPageRoute<IdentificationOutcome>(
                  builder: (_) => MultiPhotoScreen(engine: engine),
                ),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
        overrides: [
          hasCameraProvider.overrideWithValue(camera),
          photoPickerProvider.overrideWithValue((source) async {
            asked.add(source);
            return 'photo${n++}.jpg';
          }),
          photoQualityProvider.overrideWithValue((_) async => quality),
        ],
      ));
      await t.tap(find.text('ouvrir'));
      await t.pumpAndSettle();
      return result;
    }

    tw('« Analyser » n\'est possible qu\'à partir de 2 photos', (t) async {
      t.view.physicalSize = const Size(900, 3200);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await open(t, _Engine());
      expect(find.text('0 photo sur 6'), findsOneWidget);
      FilledButton analyze() => t.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Analyser (encore 2 photos)'));
      expect(analyze().onPressed, isNull);

      await t.tap(find.text('Appareil photo').first);
      await t.pumpAndSettle();
      expect(find.text('1 photo sur 6'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Analyser (encore 1 photo)'), findsOneWidget);

      // Étape 2 par la galerie.
      await t.tap(find.text('Galerie').at(1));
      await t.pumpAndSettle();
      expect(asked, [ImageSource.camera, ImageSource.gallery]);
      expect(find.text('2 photos sur 6'), findsOneWidget);
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Analyser (2 photos)')).onPressed,
          isNotNull);

      // Retirer une photo fait retomber sous le minimum.
      await t.tap(find.byTooltip('Retirer cette photo').first);
      await t.pumpAndSettle();
      expect(find.text('1 photo sur 6'), findsOneWidget);
    });

    tw('analyse : résultat unique renvoyé, photo principale en premier', (t) async {
      t.view.physicalSize = const Size(900, 3200);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final engine = _Engine();
      IdentificationOutcome? result;
      asked = [];
      n = 0;
      await t.pumpWidget(scope(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await Navigator.of(context).push(
                MaterialPageRoute<IdentificationOutcome>(
                  builder: (_) => MultiPhotoScreen(engine: engine),
                ),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
        overrides: [
          hasCameraProvider.overrideWithValue(false),
          // Les photos sont choisies dans l'ordre inverse des étapes.
          photoPickerProvider.overrideWithValue((_) async => 'photo${n++}.jpg'),
          photoQualityProvider.overrideWithValue((_) async => null),
        ],
      ));
      await t.tap(find.text('ouvrir'));
      await t.pumpAndSettle();
      // Étape 3 puis étape 1 : la photo principale est celle de l'étape 1 (photo1).
      await t.tap(find.text('Choisir une photo').at(2));
      await t.pumpAndSettle();
      await t.tap(find.text('Choisir une photo').at(0));
      await t.pumpAndSettle();
      await t.tap(find.text('Analyser (2 photos)'));
      await t.pumpAndSettle();
      expect(engine.embedded, ['photo1.jpg', 'photo0.jpg']);
      expect(result, isNotNull);
      expect(result!.imagePath, 'photo1.jpg');
      expect(result!.photoCount, 2);
      expect(result!.candidates.first.speciesId, 'girolle');
    });

    tw('photo de mauvaise qualité : remarque non bloquante sur l\'étape', (t) async {
      t.view.physicalSize = const Size(900, 3200);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await open(t, _Engine(), quality: _blurry);
      await t.tap(find.text('Appareil photo').first);
      await t.pumpAndSettle();
      expect(find.textContaining('Photo floue, Photo trop sombre'), findsOneWidget);
      expect(find.textContaining('vous pouvez la refaire'), findsOneWidget);
    });
  });

  group('écran Identifier', () {
    Widget app(List<String> picked, {required QualityReport? quality}) => scope(
          MaterialApp.router(
            routerConfig: GoRouter(routes: [
              GoRoute(path: '/', builder: (_, _) => const IdentifyScreen()),
              GoRoute(
                path: '/identify/result',
                builder: (_, state) => Text(
                  'résultat ${(state.extra! as IdentificationOutcome).imagePath}',
                ),
              ),
            ]),
          ),
          overrides: [
            identifierProvider.overrideWith((ref) async => _Engine()),
            hasCameraProvider.overrideWithValue(true),
            photoPickerProvider.overrideWithValue((_) async {
              picked.add('p${picked.length}.jpg');
              return picked.last;
            }),
            photoQualityProvider.overrideWithValue((_) async => quality),
          ],
        );

    tw('mauvaise photo : fenêtre, « Refaire » rouvre le choix, puis résultat', (t) async {
      t.view.physicalSize = const Size(900, 3200);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final picked = <String>[];
      await t.pumpWidget(app(picked, quality: _blurry));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Je ne sais pas : plusieurs photos'), findsOneWidget);
      expect(find.text('Mes identifications'), findsOneWidget);

      await t.tap(find.text('Prendre une photo'));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('Photo à vérifier'), findsOneWidget);
      await t.tap(find.text('Refaire la photo'));
      await t.pump(const Duration(milliseconds: 200));
      expect(picked, ['p0.jpg', 'p1.jpg']);
      expect(find.text('Photo à vérifier'), findsOneWidget);
      await t.tap(find.text('Utiliser quand même'));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('résultat p1.jpg'), findsOneWidget);
    });

    tw('le bouton multi-photos ouvre l\'écran guidé', (t) async {
      t.view.physicalSize = const Size(900, 3200);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(app([], quality: null));
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.text('Je ne sais pas : plusieurs photos'));
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Plusieurs photos'), findsOneWidget);
      expect(find.text('1. Dessus du chapeau'), findsOneWidget);
    });
  });
}
