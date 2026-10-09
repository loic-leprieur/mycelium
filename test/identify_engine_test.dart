import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/features/identify/class_bank.dart';
import 'package:mycelium/features/identify/identifier.dart';
import 'package:mycelium/features/identify/image_preprocess.dart';
import 'package:mycelium/features/species/data/species_seed.dart';

RgbImage load(String name) =>
    decodeRgb(File('test/fixtures/$name').readAsBytesSync());

/// Écart absolu max et moyen entre deux images de même taille.
({int max, double mean}) diff(RgbImage a, RgbImage b) {
  expect((a.width, a.height), (b.width, b.height));
  var max = 0, sum = 0;
  for (var i = 0; i < a.data.length; i++) {
    final d = (a.data[i] - b.data[i]).abs();
    if (d > max) max = d;
    sum += d;
  }
  return (max: max, mean: sum / a.data.length);
}

void main() {
  group('Prétraitement identique à PIL / open_clip', () {
    // Les références viennent de tools/bioclip/make_fixtures.py (Pillow).
    for (final name in ['landscape', 'portrait']) {
      test('Resize(224, bicubique) + CenterCrop : $name', () {
        final src = load('clip_$name.png');
        final out = centerCrop(resizeShortSide(src, 224), 224);
        final d = diff(out, load('clip_${name}_224.png'));
        expect(d.max, lessThanOrEqualTo(2), reason: 'écart max ${d.max}');
        expect(d.mean, lessThan(0.3), reason: 'écart moyen ${d.mean}');
      });
    }

    test('le recadrage arrondit comme Python (moitié -> pair)', () {
      // 299 px de large : (299 − 224) / 2 = 37,5 -> 38 (pair), pas 37.
      final src = RgbImage(299, 224, Uint8List(299 * 224 * 3));
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 299; x++) {
          src.data[(y * 299 + x) * 3] = x % 256;
        }
      }
      expect(centerCrop(src, 224).data[0], 38);
    });

    test('une image déjà à la bonne taille n\'est pas rééchantillonnée', () {
      final src = load('clip_landscape_224.png');
      expect(identical(resizeShortSide(src, 224), src), isTrue);
    });

    test('tenseur 1×3×224×224 normalisé par canal', () {
      final tensor = preprocessClip(
        File('test/fixtures/clip_landscape.png').readAsBytesSync(),
      );
      expect(tensor, hasLength(3 * 224 * 224));
      final expected = centerCrop(
        resizeShortSide(load('clip_landscape.png'), 224),
        224,
      );
      for (final i in [0, 1000, 50175]) {
        for (var c = 0; c < 3; c++) {
          final v = (expected.data[i * 3 + c] / 255 - clipMean[c]) / clipStd[c];
          expect(tensor[c * 224 * 224 + i], closeTo(v, 1e-5));
        }
      }
    });

    test('une photo illisible lève une erreur claire', () {
      expect(
        () => preprocessClip(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Banque de classes et scores', () {
    // Quatre classes en dimension 4 : deux espèces, une « hors base », un fond.
    ClassBank bank({double scale = 100}) {
      final rows = <List<double>>[
        [1, 0, 0, 0], // cepe-de-bordeaux
        [0, 1, 0, 0], // girolle
        [0, 0, 1, 0], // autre champignon (hors base)
        [0, 0, 0, 1], // fond
      ];
      return ClassBank(
        modelVersion: 'test-1',
        logitScale: scale,
        dim: 4,
        classes: const [
          BankClass(kind: ClassKind.species, name: 'a', speciesId: 'cepe-de-bordeaux'),
          BankClass(kind: ClassKind.species, name: 'b', speciesId: 'girolle'),
          BankClass(kind: ClassKind.other, name: 'c'),
          BankClass(kind: ClassKind.background, name: 'd'),
        ],
        embeddings: Float32List.fromList([for (final r in rows) ...r]),
      );
    }

    test('les probabilités somment à 1', () {
      final p = bank().probabilities([.3, .2, .1, .05]);
      expect(p.reduce((a, b) => a + b), closeTo(1, 1e-9));
    });

    test('un vecteur proche d\'une espèce la place en tête', () {
      final raw = bank().score([.97, .1, .1, .05]);
      expect(raw.candidates.first.speciesId, 'cepe-de-bordeaux');
      expect(raw.candidates.first.score, greaterThan(.9));
      expect(raw.unknownScore, lessThan(.1));
      expect(raw.modelVersion, 'test-1');
    });

    test('un vecteur proche d\'une classe hors base : jamais de réponse forcée', () {
      final raw = bank().score([.05, .05, .97, .05]);
      expect(raw.unknownScore, greaterThan(.9));
      expect(raw.candidates.first.score, lessThan(.1));
      // Combinée aux règles de sécurité : identification insuffisante.
      final outcome = applySafetyRules(
        raw.candidates,
        edibilityOf: seedEdibilityOf,
        unknownScore: raw.unknownScore,
      );
      expect(outcome.isInsufficient, isTrue);
    });

    test('l\'échelle du vecteur n\'importe pas (normalisation)', () {
      final a = bank().score([.3, .2, .1, .05]);
      final b = bank().score([3, 2, 1, .5]);
      expect(a.candidates.first.score, closeTo(b.candidates.first.score, 1e-9));
    });

    test('mauvaise dimension ou vecteur nul : erreur', () {
      expect(() => bank().score([1, 2]), throwsArgumentError);
      expect(() => bank().score([0, 0, 0, 0]), throwsArgumentError);
    });

    test('lecture du JSON produit par export_bioclip.py', () {
      final floats = Float32List.fromList([1, 0, 0, 1]);
      final json = {
        'version': 'v-json',
        'logitScale': 100.0,
        'dim': 2,
        'inputSize': 224,
        'mean': [.5, .5, .5],
        'std': [.25, .25, .25],
        'classes': [
          {'id': 'girolle', 'kind': 'species', 'name': 'Cantharellus cibarius'},
          {'id': null, 'kind': 'background', 'name': 'a photo of Plantae'},
        ],
        'embeddings': base64Encode(floats.buffer.asUint8List()),
      };
      final loaded = ClassBank.fromJson(json);
      expect(loaded.modelVersion, 'v-json');
      expect(loaded.speciesCount, 1);
      expect(loaded.mean, [.5, .5, .5]);
      expect(loaded.score([1, 0]).candidates.single.speciesId, 'girolle');
    });
  });

  group('Règles de sécurité avec un vrai modèle', () {
    List<Candidate> cands(List<(String, double)> l) =>
        [for (final (id, s) in l) Candidate(speciesId: id, score: s)];

    test('RM-5 : une espèce hors base aussi probable que le 1er candidat => insuffisant', () {
      final outcome = applySafetyRules(
        cands([('girolle', .55), ('fausse-girolle', .05)]),
        edibilityOf: seedEdibilityOf,
        thresholds: const SafetyThresholds(minTopScore: .4, minMargin: .1),
        unknownScore: .6,
      );
      expect(outcome.isInsufficient, isTrue);
      expect(outcome.unknownScore, .6);
    });

    test('un candidat net, sans doute hors base, reste valide', () {
      final outcome = applySafetyRules(
        cands([('bolet-bai', .85), ('cepe-de-bordeaux', .05)]),
        edibilityOf: seedEdibilityOf,
        unknownScore: .08,
      );
      expect(outcome.isInsufficient, isFalse);
    });

    test('RM-6 : un candidat mortel quasi nul n\'affole pas l\'écran', () {
      final raw = cands([
        ('bolet-bai', .90),
        ('cepe-de-bordeaux', .06),
        ('amanite-phalloide', .004), // 0,4 % : bruit du modèle
      ]);
      const filtered = SafetyThresholds(minCandidateScore: .02);
      expect(
        applySafetyRules(raw, edibilityOf: seedEdibilityOf, thresholds: filtered)
            .dangerousSpeciesIds,
        isEmpty,
      );
      // Sans seuil (démonstration), la règle reste stricte, quel que soit le score.
      expect(
        applySafetyRules(raw, edibilityOf: seedEdibilityOf).dangerousSpeciesIds,
        contains('amanite-phalloide'),
      );
    });

    test('RM-6 : un candidat mortel crédible déclenche l\'alerte, même en 3e position', () {
      final outcome = applySafetyRules(
        cands([('girolle', .40), ('fausse-girolle', .30), ('amanite-phalloide', .12)]),
        edibilityOf: seedEdibilityOf,
        thresholds: const SafetyThresholds(minCandidateScore: .02),
      );
      expect(outcome.dangerousSpeciesIds, ['amanite-phalloide']);
    });

    test('toutes les espèces du banc d\'essai existent dans le catalogue', () {
      final classes = jsonDecode(
        File('tools/bioclip/classes.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final seedIds = speciesSeed.map((s) => s.id).toSet();
      final ids = [for (final s in classes['species'] as List) (s as Map)['id'] as String];
      expect(ids.toSet(), seedIds, reason: 'classes.json et species_seed.dart divergent');
      // Cohérence de la comestibilité utilisée pour l'évaluation.
      for (final s in classes['species'] as List) {
        final id = (s as Map)['id'] as String;
        final seed = speciesSeed.firstWhere((e) => e.id == id);
        expect(s['edibility'], seed.edibility.name, reason: id);
      }
      expect(math.max(1, ids.length), 21);
    });
  });
}
