import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'class_bank.dart';
import 'identifier.dart';
import 'image_preprocess.dart';

/// Identification embarquée, 100 % hors connexion (ID-2) : BioCLIP (ViT-B/16,
/// licence MIT) exécuté par ONNX Runtime sur le téléphone.
///
/// La photo est prétraitée hors du fil principal, encodée en un vecteur de
/// 512 nombres par le modèle, puis comparée aux vecteurs précalculés des
/// espèces (voir [ClassBank]). Le modèle et ses classes sont produits par
/// `tools/bioclip/export_bioclip.py` dans `assets/models/`.
class BioClipIdentifier implements EmbeddingIdentifier {
  BioClipIdentifier._(this._session, this.bank);

  static const modelAsset = 'assets/models/bioclip_visual.onnx';
  static const classesAsset = 'assets/models/bioclip_classes.json';

  final OrtSession _session;
  final ClassBank bank;

  /// Vrai si le modèle est embarqué dans cette version de l'application. Le
  /// fichier (115 Mo) n'est pas versionné : une version compilée sans lui
  /// reste utilisable, en mode démonstration.
  static Future<bool> isBundled([AssetBundle? bundle]) async {
    final manifest =
        await AssetManifest.loadFromAssetBundle(bundle ?? rootBundle);
    final assets = manifest.listAssets();
    return assets.contains(modelAsset) && assets.contains(classesAsset);
  }

  static Future<BioClipIdentifier> load({AssetBundle? bundle}) async {
    final classes = await (bundle ?? rootBundle).loadString(classesAsset);
    final bank = ClassBank.fromJson(jsonDecode(classes) as Map<String, dynamic>);
    final session = await OnnxRuntime().createSessionFromAsset(
      modelAsset,
      options: OrtSessionOptions(
        intraOpNumThreads: 4,
        providers: [OrtProvider.CPU],
      ),
    );
    return BioClipIdentifier._(session, bank);
  }

  @override
  bool get isDemo => false;

  /// Vecteur de 512 nombres (normalisé) décrivant la photo.
  @override
  Future<List<double>> embed(String imagePath) async {
    final size = bank.inputSize;
    final mean = bank.mean ?? clipMean;
    final std = bank.std ?? clipStd;
    final pixels = await Isolate.run(
      () => preprocessClipFile(imagePath, size: size, mean: mean, std: std),
    );

    final input = await OrtValue.fromList(pixels, [1, 3, size, size]);
    Map<String, OrtValue>? outputs;
    try {
      outputs = await _session.run({_session.inputNames.first: input});
      final values =
          await outputs[_session.outputNames.first]!.asFlattenedList();
      return [for (final v in values) (v as num).toDouble()];
    } finally {
      await input.dispose();
      for (final output in outputs?.values ?? const <OrtValue>[]) {
        await output.dispose();
      }
    }
  }

  @override
  Future<RawIdentification> identify(IdentificationInput input) async {
    final path = input.imagePath;
    if (path == null) throw ArgumentError('Aucune photo à analyser.');
    return bank.score(await embed(path));
  }

  @override
  RawIdentification classify(List<double> embedding) => bank.score(embedding);

  Future<void> dispose() => _session.close();
}
