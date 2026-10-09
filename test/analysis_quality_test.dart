import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/data/providers.dart';
import 'package:mycelium/features/identify/analysis/multi_photo.dart';
import 'package:mycelium/features/identify/analysis/photo_quality.dart';
import 'package:mycelium/features/identify/analysis/season.dart';
import 'package:mycelium/features/identify/class_bank.dart';
import 'package:mycelium/features/identify/identifier.dart';
import 'package:mycelium/features/identify/identifier_provider.dart';
import 'package:mycelium/features/identify/identify_flow.dart';
import 'package:mycelium/features/identify/image_preprocess.dart';
import 'package:mycelium/features/species/data/species_seed.dart';
import 'package:mycelium/features/species/domain/species.dart';

/// Image synthétique à texture naturelle (bruit à plusieurs échelles), déterministe.
RgbImage texture(int w, int h, {int seed = 1}) {
  final rnd = math.Random(seed);
  final lum = Float64List(w * h);
  for (final cell in [1, 2, 4, 8, 16, 32]) {
    final gw = (w / cell).ceil() + 1, gh = (h / cell).ceil() + 1;
    final grid = [for (var i = 0; i < gw * gh; i++) rnd.nextDouble() - .5];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        lum[y * w + x] += grid[(y ~/ cell) * gw + x ~/ cell] * math.sqrt(cell) * 14;
      }
    }
  }
  final data = Uint8List(w * h * 3);
  for (var i = 0; i < w * h; i++) {
    final v = (128 + lum[i]).round().clamp(0, 255);
    data[i * 3] = v;
    data[i * 3 + 1] = v;
    data[i * 3 + 2] = v;
  }
  return RgbImage(w, h, data);
}

/// Flou de boîte (rayon [r], deux passes).
RgbImage blur(RgbImage src, int r) {
  var cur = src.data;
  for (var pass = 0; pass < 2; pass++) {
    for (final horizontal in [true, false]) {
      final out = Uint8List(cur.length);
      for (var y = 0; y < src.height; y++) {
        for (var x = 0; x < src.width; x++) {
          for (var c = 0; c < 3; c++) {
            var s = 0, n = 0;
            for (var d = -r; d <= r; d++) {
              final xx = horizontal ? x + d : x, yy = horizontal ? y : y + d;
              if (xx < 0 || yy < 0 || xx >= src.width || yy >= src.height) continue;
              s += cur[(yy * src.width + xx) * 3 + c];
              n++;
            }
            out[(y * src.width + x) * 3 + c] = (s / n).round();
          }
        }
      }
      cur = out;
    }
  }
  return RgbImage(src.width, src.height, cur);
}

RgbImage mapPixels(RgbImage src, int Function(int) f) => RgbImage(
      src.width,
      src.height,
      Uint8List.fromList([for (final v in src.data) f(v).clamp(0, 255)]),
    );

void main() {
  group('ID-8 : qualité de la photo (images synthétiques)', () {
    final sharp = texture(640, 480);

    test('photo nette : aucun défaut', () {
      final r = measureQuality(sharp);
      expect(r.hasIssues, isFalse, reason: 'netteté ${r.sharpness}');
      expect(r.sharpness, greaterThan(3));
    });

    test('photo floue : signalée floue, et moins nette que l\'originale', () {
      final r = measureQuality(blur(sharp, 12));
      expect(r.has(QualityIssue.blurry), isTrue, reason: 'netteté ${r.sharpness}');
      expect(r.sharpness, lessThan(measureQuality(sharp).sharpness));
    });

    test('photo sombre : signalée trop sombre, sans juger la netteté', () {
      final r = measureQuality(mapPixels(sharp, (v) => v ~/ 6));
      expect(r.issues, [QualityIssue.tooDark]);
      expect(r.meanBrightness, lessThan(40));
    });

    test('photo surexposée : signalée, sans juger la netteté', () {
      final r = measureQuality(mapPixels(sharp, (v) => v + 150));
      expect(r.issues, [QualityIssue.tooBright]);
      expect(r.brightShare, greaterThan(.35));
    });

    test('photo trop petite', () {
      final r = measureQuality(texture(300, 200));
      expect(r.has(QualityIssue.tooSmall), isTrue);
      expect(measureQuality(texture(320, 320)).has(QualityIssue.tooSmall), isFalse);
    });

    test('image unie : floue, et sans division par zéro', () {
      final flat = RgbImage(640, 480, Uint8List(640 * 480 * 3)..fillRange(0, 640 * 480 * 3, 128));
      final r = measureQuality(flat);
      expect(r.sharpness, closeTo(1, 1e-6));
      expect(r.has(QualityIssue.blurry), isTrue);
    });

    test('seuils personnalisables', () {
      final r = measureQuality(sharp, thresholds: const QualityThresholds(minSharpness: 1000));
      expect(r.has(QualityIssue.blurry), isTrue);
    });
  });

  group('ID-7 : saison', () {
    test('saison simple et saison à cheval sur deux années', () {
      expect(isInSeason(6, 11, 6), isTrue);
      expect(isInSeason(6, 11, 11), isTrue);
      expect(isInSeason(6, 11, 12), isFalse);
      expect(isInSeason(6, 11, 1), isFalse);
      // novembre -> février
      for (final m in [11, 12, 1, 2]) {
        expect(isInSeason(11, 2, m), isTrue, reason: 'mois $m');
      }
      for (final m in [3, 6, 10]) {
        expect(isInSeason(11, 2, m), isFalse, reason: 'mois $m');
      }
      expect(isInSeason(5, 5, 5), isTrue);
      expect(isInSeason(5, 5, 6), isFalse);
    });

    test('saison inconnue : aucun jugement', () {
      expect(isInSeason(null, 5, 3), isNull);
      expect(isInSeason(3, null, 3), isNull);
    });

    Species? find(String id) => speciesSeed.firstWhere((s) => s.id == id);

    test('hors saison : la morille en octobre, jamais une espèce dangereuse', () {
      final out = outOfSeasonCandidates(
        const [
          Candidate(speciesId: 'morille', score: .5),
          Candidate(speciesId: 'gyromitre', score: .3),
          Candidate(speciesId: 'girolle', score: .1),
        ],
        10,
        find,
      );
      // La gyromitre (mortelle, mars -> juin) n'est pas citée ; la girolle est de saison.
      expect(out.map((s) => s.id), ['morille']);
    });

    test('les scores ne sont pas modifiés par le contexte', () {
      final raw = const [Candidate(speciesId: 'morille', score: .7)];
      final out = applySafetyRules(raw, edibilityOf: seedEdibilityOf, seasonMonth: 10);
      expect(out.candidates.single.score, .7);
      expect(out.seasonMonth, 10);
    });
  });

  group('ID-6 : fusion de photos', () {
    // Banque de dimension 4 : deux espèces, une classe hors base.
    ClassBank bank() => ClassBank(
          modelVersion: 'test',
          logitScale: 20,
          dim: 4,
          classes: const [
            BankClass(kind: ClassKind.species, name: 'a', speciesId: 'cepe-de-bordeaux'),
            BankClass(kind: ClassKind.species, name: 'b', speciesId: 'amanite-phalloide'),
            BankClass(kind: ClassKind.other, name: 'c'),
          ],
          embeddings: Float32List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]),
        );

    test('moyenne des vecteurs normalisés : chaque photo pèse autant', () {
      final f = fuseEmbeddings([
        [10, 0],
        [0, 1],
      ]);
      expect(f[0], closeTo(.5, 1e-12));
      expect(f[1], closeTo(.5, 1e-12));
      expect(fuseEmbeddings([[3, 4]]), [closeTo(.6, 1e-12), closeTo(.8, 1e-12)]);
      expect(() => fuseEmbeddings([]), throwsArgumentError);
      expect(() => fuseEmbeddings([[0, 0]]), throwsArgumentError);
    });

    test('identifyMany : UN résultat fusionné et un résultat par photo', () async {
      final engine = _FakeEngine(bank(), {
        'a.jpg': [1, .2, 0, 0],
        'b.jpg': [1, 0, .3, 0],
      });
      final progress = <int>[];
      final multi = await engine.identifyMany(['a.jpg', 'b.jpg'], onProgress: progress.add);
      expect(progress, [1, 2]);
      expect(multi.perPhoto, hasLength(2));
      expect(multi.fused.candidates.first.speciesId, 'cepe-de-bordeaux');
      // Une seule photo : même résultat qu'avec le moteur seul.
      final single = await engine.identifyMany(['a.jpg']);
      final alone = engine.classify(await engine.embed('a.jpg'));
      expect(single.fused.candidates.first.score, closeTo(alone.candidates.first.score, 1e-12));
    });

    ProviderContainer container(Map<String, List<double>> vectors) {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWith((ref) => AppDatabase(NativeDatabase.memory())),
        photoQualityProvider.overrideWithValue((_) async => null),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('flux : photo principale = première, mêmes règles RM-5, nombre de photos', () async {
      final c = container({});
      final engine = _FakeEngine(bank(), {
        'cap.jpg': [1, 0, 0, 0],
        'gills.jpg': [1, 0, .1, 0],
      });
      final outcome = await c.read(identifyFlowProvider).identifyPhotos(
        const [
          ChosenPhoto('cap.jpg', ImageSource.gallery),
          ChosenPhoto('gills.jpg', ImageSource.gallery),
        ],
        engine,
      );
      expect(outcome.imagePath, 'cap.jpg');
      expect(outcome.photoCount, 2);
      expect(outcome.isInsufficient, isFalse);
      expect(outcome.seasonMonth, isNull, reason: 'galerie : date inconnue');
      expect(outcome.hasLocation, isFalse);
    });

    test('RM-6 : l\'alerte d\'une photo seule survit à la fusion', () async {
      final c = container({});
      // Photo 1 : amanite phalloïde nette. Photos 2 à 5 : cèpe. Le résultat fusionné
      // est dominé par le cèpe, mais l'alerte levée par la photo 1 reste.
      final engine = _FakeEngine(bank(), {
        'p1.jpg': [0, 1, 0, 0],
        for (final n in ['p2', 'p3', 'p4', 'p5']) '$n.jpg': [1, 0, 0, 0],
      });
      final outcome = await c.read(identifyFlowProvider).identifyPhotos(
        [
          for (final n in ['p1', 'p2', 'p3', 'p4', 'p5'])
            ChosenPhoto('$n.jpg', ImageSource.gallery),
        ],
        engine,
      );
      expect(outcome.candidates.first.speciesId, 'cepe-de-bordeaux');
      expect(outcome.dangerousSpeciesIds, contains('amanite-phalloide'));
    });

    test('RM-5 : photos incohérentes ou hors base => identification insuffisante', () async {
      final c = container({});
      final engine = _FakeEngine(bank(), {
        'x.jpg': [0, 0, 1, 0],
        'y.jpg': [0, 0, 1, .1],
      });
      final outcome = await c.read(identifyFlowProvider).identifyPhotos(
        const [
          ChosenPhoto('x.jpg', ImageSource.gallery),
          ChosenPhoto('y.jpg', ImageSource.gallery),
        ],
        engine,
      );
      expect(outcome.isInsufficient, isTrue);
    });
  });

  group('ID-8 : dans le flux', () {
    ProviderContainer container(QualityReport? report, {DateTime? now}) {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      var n = 0;
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWith((ref) => AppDatabase(NativeDatabase.memory())),
        photoPickerProvider.overrideWithValue((_) async => 'photo${n++}.jpg'),
        photoQualityProvider.overrideWithValue((_) async => report),
        if (now != null) clockProvider.overrideWithValue(() => now),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    const bad = QualityReport(
      width: 640,
      height: 480,
      sharpness: 1,
      meanBrightness: 100,
      brightShare: 0,
      issues: [QualityIssue.blurry],
    );

    test('mauvaise photo + « Utiliser quand même » : analysée, rapport joint', () async {
      final c = container(bad);
      final asked = <String>[];
      final outcome = await c.read(identifyFlowProvider).captureAndIdentify(
            ImageSource.gallery,
            _Stub(),
            onQualityIssue: (report, path) async {
              asked.add(path);
              return QualityChoice.useAnyway;
            },
          );
      expect(asked, ['photo0.jpg']);
      expect(outcome.imagePath, 'photo0.jpg');
      expect(outcome.quality, same(bad));
    });

    test('« Refaire la photo » : le choix de la photo est rouvert', () async {
      final c = container(bad);
      var calls = 0;
      final stub = _Stub();
      final outcome = await c.read(identifyFlowProvider).captureAndIdentify(
            ImageSource.gallery,
            stub,
            onQualityIssue: (_, _) async =>
                ++calls == 1 ? QualityChoice.retake : QualityChoice.useAnyway,
          );
      expect(calls, 2);
      expect(outcome.imagePath, 'photo1.jpg');
      expect(stub.paths, ['photo1.jpg'], reason: 'la première photo n\'est pas analysée');
    });

    test('bonne photo ou mesure impossible : aucune question, jamais de blocage', () async {
      for (final report in [
        null,
        const QualityReport(
            width: 640, height: 480, sharpness: 5, meanBrightness: 100, brightShare: 0, issues: []),
      ]) {
        final c = container(report);
        final outcome = await c.read(identifyFlowProvider).captureAndIdentify(
              ImageSource.gallery,
              _Stub(),
              onQualityIssue: (_, _) async => fail('ne doit pas être appelé'),
            );
        expect(outcome.candidates, isNotEmpty);
      }
    });

    test('sans rappel : la photo mauvaise est analysée quand même', () async {
      final c = container(bad);
      final outcome = await c
          .read(identifyFlowProvider)
          .captureAndIdentify(ImageSource.gallery, _Stub());
      expect(outcome.quality?.has(QualityIssue.blurry), isTrue);
    });

    test('mois de la prise de vue : appareil photo seulement', () async {
      final now = DateTime(2026, 10, 9);
      final cam = await container(null, now: now)
          .read(identifyFlowProvider)
          .captureAndIdentify(ImageSource.camera, _Stub());
      final gal = await container(null, now: now)
          .read(identifyFlowProvider)
          .captureAndIdentify(ImageSource.gallery, _Stub());
      expect(cam.seasonMonth, 10);
      expect(gal.seasonMonth, isNull);
    });
  });
}

class _Stub implements Identifier {
  final paths = <String>[];

  @override
  bool get isDemo => false;

  @override
  Future<RawIdentification> identify(IdentificationInput input) async {
    paths.add(input.imagePath!);
    return const RawIdentification(
      modelVersion: 's',
      candidates: [Candidate(speciesId: 'girolle', score: .9), Candidate(speciesId: 'morille', score: .05)],
    );
  }
}

class _FakeEngine implements EmbeddingIdentifier {
  _FakeEngine(this.bank, this.vectors);

  final ClassBank bank;
  final Map<String, List<double>> vectors;

  @override
  bool get isDemo => false;

  @override
  Future<List<double>> embed(String imagePath) async => vectors[imagePath]!;

  @override
  RawIdentification classify(List<double> embedding) => bank.score(embedding);

  @override
  Future<RawIdentification> identify(IdentificationInput input) async =>
      classify(await embed(input.imagePath!));
}
