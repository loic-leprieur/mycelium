// Identification embarquée de bout en bout, avec le VRAI modèle :
//
//   flutter test integration_test/identify_model_test.dart -d macos
//
// Compare le vecteur et les scores calculés dans l'application (prétraitement
// Dart + ONNX Runtime + banque de classes) à ceux de la chaîne Python de
// référence (voir tools/bioclip/make_fixtures.py). Nécessite le modèle dans
// assets/models/ (tools/bioclip/export_bioclip.py).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mycelium/features/identify/bioclip_identifier.dart';
import 'package:mycelium/features/identify/identifier.dart';

import 'clip_fixture.dart';

double cosine(List<double> a, List<double> b) {
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return dot / (math.sqrt(na) * math.sqrt(nb));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BioCLIP embarqué : mêmes résultats que la chaîne Python', (t) async {
    expect(await BioClipIdentifier.isBundled(), isTrue,
        reason: 'modèle absent : lancer tools/bioclip/export_bioclip.py');

    final loading = Stopwatch()..start();
    final engine = await BioClipIdentifier.load();
    // ignore: avoid_print
    print('Chargement du modèle : ${loading.elapsedMilliseconds} ms');

    final dir = await Directory.systemTemp.createTemp('mycelium_model_test');
    final photo = File('${dir.path}/fixture.png')
      ..writeAsBytesSync(base64Decode(clipFixturePngBase64));
    final jpeg = File('${dir.path}/fixture.jpg')
      ..writeAsBytesSync(base64Decode(clipFixtureJpegBase64));

    final first = Stopwatch()..start();
    final embedding = await engine.embed(photo.path);
    // ignore: avoid_print
    print('Première analyse : ${first.elapsedMilliseconds} ms');
    expect(embedding, hasLength(512));

    // Mêmes pixels que la référence Python (PNG sans perte) : seuls le prétraitement
    // Dart et ONNX Runtime entrent en jeu.
    final similarity = cosine(embedding, clipFixtureEmbedding);
    // ignore: avoid_print
    print('Cosinus Dart/ONNX vs Python (PNG)  : $similarity');
    expect(similarity, greaterThan(0.995));

    // Même photo en JPEG : le décodeur JPEG de Dart diffère de libjpeg (PIL).
    final jpegSimilarity = cosine(await engine.embed(jpeg.path), clipFixtureEmbedding);
    // ignore: avoid_print
    print('Cosinus Dart/ONNX vs Python (JPEG) : $jpegSimilarity');
    expect(jpegSimilarity, greaterThan(0.9));

    final timing = Stopwatch()..start();
    final raw = await engine.identify(IdentificationInput(imagePath: photo.path));
    // ignore: avoid_print
    print('Analyse suivante : ${timing.elapsedMilliseconds} ms');

    expect(raw.modelVersion, clipModelVersion);
    expect(raw.candidates, hasLength(clipFixtureSpecies.length));
    expect((raw.unknownScore - clipFixtureUnknown).abs(), lessThan(0.03));
    for (final c in raw.candidates) {
      expect(
        (c.score - clipFixtureSpecies[c.speciesId]!).abs(),
        lessThan(0.03),
        reason: c.speciesId,
      );
    }

    // Un fichier qui n'est pas une photo : erreur, jamais de résultat inventé.
    final bad = File('${dir.path}/bad.jpg')..writeAsBytesSync([1, 2, 3, 4]);
    await expectLater(
      engine.identify(IdentificationInput(imagePath: bad.path)),
      throwsA(anything),
    );

    await engine.dispose();
    await dir.delete(recursive: true);
  });
}
