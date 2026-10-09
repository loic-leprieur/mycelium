import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../map/location.dart';
import '../species/domain/species.dart';
import '../../data/providers.dart';
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
  /// afficher « Analyse en cours »). Lève [IdentifyCancelled], [IdentifyPhotoError]
  /// ou [IdentifyAnalysisError].
  Future<IdentificationOutcome> captureAndIdentify(
    ImageSource source,
    Identifier engine, {
    void Function()? onPhotoChosen,
  }) async {
    final String? path;
    try {
      path = await _ref.read(photoPickerProvider)(source);
    } catch (e) {
      throw IdentifyPhotoError(e);
    }
    if (path == null) throw const IdentifyCancelled();
    onPhotoChosen?.call();

    // Position de la prise de vue : seulement avec l'appareil photo, où la photo
    // vient d'être prise ici. Une photo de la galerie peut venir d'ailleurs.
    final position =
        source == ImageSource.camera ? _ref.read(locationProvider).value?.position : null;

    final RawIdentification raw;
    try {
      raw = await engine.identify(IdentificationInput(imagePath: path));
    } catch (e) {
      throw IdentifyAnalysisError(e);
    }
    return applySafetyRules(
      raw.candidates,
      edibilityOf: edibilityOf,
      thresholds: identifyThresholds,
      unknownScore: raw.unknownScore,
      modelVersion: raw.modelVersion,
      imagePath: path,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
  }
}

final identifyFlowProvider = Provider<IdentifyFlow>(IdentifyFlow.new);
