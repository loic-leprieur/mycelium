// Fusion de plusieurs photos avec le VRAI modèle (ID-6) :
//
//   flutter test integration_test/identify_multi_test.dart -d macos
//
// Vérifie sur la photo de référence (voir clip_fixture.dart) que : une photo
// dupliquée donne le même résultat qu'une photo seule, la fusion de deux photos
// donne UN résultat cohérent, et que la mesure de qualité tourne sur de vrais
// fichiers. La précision sur de vraies photos de champignons n'est PAS mesurée.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mycelium/features/identify/analysis/multi_photo.dart';
import 'package:mycelium/features/identify/analysis/photo_quality.dart';
import 'package:mycelium/features/identify/bioclip_identifier.dart';
import 'package:mycelium/features/identify/identifier.dart';
import 'package:mycelium/features/identify/identify_flow.dart';

import 'clip_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BioCLIP : fusion de photos en un seul résultat', (t) async {
    expect(await BioClipIdentifier.isBundled(), isTrue,
        reason: 'modèle absent : lancer tools/bioclip/export_bioclip.py');
    final engine = await BioClipIdentifier.load();
    final dir = await Directory.systemTemp.createTemp('mycelium_multi_test');
    final png = File('${dir.path}/a.png')..writeAsBytesSync(base64Decode(clipFixturePngBase64));
    final jpg = File('${dir.path}/b.jpg')..writeAsBytesSync(base64Decode(clipFixtureJpegBase64));

    final single = await engine.identify(IdentificationInput(imagePath: png.path));

    // Deux fois la même photo : même résultat qu'une photo seule.
    final twice = await engine.identifyMany([png.path, png.path]);
    expect((twice.fused.unknownScore - single.unknownScore).abs(), lessThan(0.001));
    for (final c in twice.fused.candidates) {
      final s = single.candidates.firstWhere((e) => e.speciesId == c.speciesId);
      expect((c.score - s.score).abs(), lessThan(0.001), reason: c.speciesId);
    }

    // PNG + JPEG : UN résultat fusionné, un résultat par photo, mêmes règles RM-5.
    final multi = await engine.identifyMany([png.path, jpg.path]);
    expect(multi.perPhoto, hasLength(2));
    expect(multi.fused.modelVersion, clipModelVersion);
    expect(multi.fused.candidates, hasLength(clipFixtureSpecies.length));
    expect((multi.fused.unknownScore - clipFixtureUnknown).abs(), lessThan(0.05));
    final outcome = applySafetyRules(
      multi.fused.candidates,
      edibilityOf: seedEdibilityOf,
      thresholds: identifyThresholds,
      unknownScore: multi.fused.unknownScore,
      photoCount: 2,
    );
    // Image synthétique : le modèle répond « hors base », jamais une espèce forcée.
    expect(outcome.isInsufficient, isTrue);
    expect(outcome.photoCount, 2);

    // Mesure de qualité sur de vrais fichiers (isolat compris).
    final report = await analyzePhotoQuality(png.path);
    expect(report.width, greaterThan(0));
    expect(report.sharpness, greaterThan(0));
    // ignore: avoid_print
    print('Qualité de la photo de référence : netteté ${report.sharpness}, '
        'luminosité ${report.meanBrightness}, défauts ${report.issues}');

    await engine.dispose();
    await dir.delete(recursive: true);
  });
}
