import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../map/location.dart';
import '../species/domain/species.dart';
import '../../data/providers.dart';
import 'analysis/multi_photo.dart';
import 'analysis/photo_quality.dart';
import 'identifier.dart';
import 'identifier_provider.dart';

/// Seuil d'affichage des candidats d'un vrai modèle : en dessous, un candidat
/// n'apporte rien (et ne doit pas déclencher d'alerte à lui seul).
const identifyThresholds = SafetyThresholds(minCandidateScore: 0.02);

/// L'utilisateur a fermé la fenêtre de choix de la photo.
class IdentifyCancelled implements Exception {
  const IdentifyCancelled();
}

/// Impossible d'obtenir la photo (autorisation refusée, fichier illisible…).
class IdentifyPhotoError implements Exception {
  const IdentifyPhotoError(this.cause);

  final Object cause;
}

/// La photo a été obtenue mais l'analyse a échoué.
class IdentifyAnalysisError implements Exception {
  const IdentifyAnalysisError(this.cause);

  final Object cause;
}

/// Que faire d'une photo de mauvaise qualité ? Jamais de refus définitif.
enum QualityChoice { retake, useAnyway }

/// Demande à l'utilisateur quoi faire d'une photo de mauvaise qualité.
typedef QualityPrompt = Future<QualityChoice> Function(
    QualityReport report, String imagePath);

/// Une photo choisie, avec son origine (appareil photo ou galerie).
class ChosenPhoto {
  const ChosenPhoto(this.path, this.source);

  final String path;
  final ImageSource source;
}

/// Déroulé d'une identification : choix de la photo, analyse par le moteur, règles
/// de sécurité (RM-5, RM-6), position de la prise de vue. L'interface ne fait que
/// l'afficher.
class IdentifyFlow {
  IdentifyFlow(this._ref);

  final Ref _ref;

  Edibility? edibilityOf(String id) {
    final all = _ref.read(allSpeciesProvider).value;
    if (all == null) return seedEdibilityOf(id);
    for (final s in all) {
      if (s.id == id) return s.edibility;
    }
    return null;
  }

  /// Exemple de DÉMONSTRATION (résultat fictif, jamais enregistré).
  Future<IdentificationOutcome> demo(int scenarioIndex) async {
    final raw = await FakeIdentifier(scenarioIndex: scenarioIndex)
        .identify(const IdentificationInput());
    return applySafetyRules(
      raw.candidates,
      edibilityOf: edibilityOf,
      isDemo: true,
      scenarioLabel: FakeIdentifier.scenarios[scenarioIndex].label,
    );
  }

  /// Demande une photo ([source]), l'analyse avec [engine] et renvoie le résultat.
  ///
  /// [onPhotoChosen] est appelé dès que la photo est choisie, avant l'analyse (pour
  /// afficher « Analyse en cours »). Si la photo est de mauvaise qualité (ID-8) et
  /// que [onQualityIssue] est fourni, l'utilisateur choisit de la refaire (la
  /// fenêtre de choix se rouvre) ou de l'utiliser quand même. Lève
  /// [IdentifyCancelled], [IdentifyPhotoError] ou [IdentifyAnalysisError].
  Future<IdentificationOutcome> captureAndIdentify(
    ImageSource source,
    Identifier engine, {
    void Function()? onPhotoChosen,
    QualityPrompt? onQualityIssue,
  }) async {
    String path;
    QualityReport? quality;
    while (true) {
      path = await _pick(source);
      onPhotoChosen?.call();
      quality = await _ref.read(photoQualityProvider)(path);
      if (quality == null || !quality.hasIssues || onQualityIssue == null) break;
      if (await onQualityIssue(quality, path) == QualityChoice.useAnyway) break;
    }

    final RawIdentification raw;
    try {
      raw = await engine.identify(IdentificationInput(imagePath: path));
    } catch (e) {
      throw IdentifyAnalysisError(e);
    }
    return _outcome(raw, path, source, quality);
  }

  /// Analyse plusieurs photos du même champignon (ID-6) et les combine en UN
  /// résultat. La première photo de [photos] est la photo principale : c'est
  /// elle que l'historique enregistre. Les règles RM-5/RM-6 sont les mêmes que
  /// pour une photo seule, et une alerte « espèce dangereuse » levée par une
  /// seule photo est conservée.
  Future<IdentificationOutcome> identifyPhotos(
    List<ChosenPhoto> photos,
    EmbeddingIdentifier engine, {
    void Function(int done)? onProgress,
  }) async {
    final main = photos.first;
    final quality = await _ref.read(photoQualityProvider)(main.path);
    final MultiIdentification multi;
    try {
      multi = await engine.identifyMany(
        [for (final p in photos) p.path],
        onProgress: onProgress,
      );
    } catch (e) {
      throw IdentifyAnalysisError(e);
    }
    final alerts = <String>{
      for (final raw in multi.perPhoto)
        ...applySafetyRules(
          raw.candidates,
          edibilityOf: edibilityOf,
          thresholds: identifyThresholds,
        ).dangerousSpeciesIds,
    };
    return _outcome(multi.fused, main.path, main.source, quality,
        photoCount: photos.length, extraDangerous: alerts);
  }

  Future<String> _pick(ImageSource source) async {
    final String? path;
    try {
      path = await _ref.read(photoPickerProvider)(source);
    } catch (e) {
      throw IdentifyPhotoError(e);
    }
    if (path == null) throw const IdentifyCancelled();
    return path;
  }

  IdentificationOutcome _outcome(
    RawIdentification raw,
    String path,
    ImageSource source,
    QualityReport? quality, {
    int photoCount = 1,
    Iterable<String> extraDangerous = const [],
  }) {
    // Position et mois de la prise de vue : seulement avec l'appareil photo, où la
    // photo vient d'être prise ici et maintenant. Une photo de la galerie peut
    // venir d'ailleurs ou d'un autre mois.
    final camera = source == ImageSource.camera;
    final position = camera ? _ref.read(locationProvider).value?.position : null;
    return applySafetyRules(
      raw.candidates,
      edibilityOf: edibilityOf,
      thresholds: identifyThresholds,
      unknownScore: raw.unknownScore,
      modelVersion: raw.modelVersion,
      imagePath: path,
      latitude: position?.latitude,
      longitude: position?.longitude,
      quality: quality,
      seasonMonth: camera ? _ref.read(clockProvider)().month : null,
      photoCount: photoCount,
      extraDangerousSpeciesIds: extraDangerous,
    );
  }
}

final identifyFlowProvider = Provider<IdentifyFlow>(IdentifyFlow.new);
