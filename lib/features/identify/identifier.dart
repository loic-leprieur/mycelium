import '../species/data/species_seed.dart';
import '../species/domain/species.dart';

/// Une espèce proposée par un moteur d'identification, avec son score (0–1).
class Candidate {
  const Candidate({required this.speciesId, required this.score});

  final String speciesId;
  final double score;
}

/// Seuils de la règle RM-5, à calibrer sur des photos réelles (cahier des charges §11.3).
class SafetyThresholds {
  const SafetyThresholds({this.minTopScore = 0.60, this.minMargin = 0.15});

  /// Score minimal du meilleur candidat.
  final double minTopScore;

  /// Écart minimal entre le 1er et le 2e candidat.
  final double minMargin;
}

/// Résultat après application des règles de sécurité.
class IdentificationOutcome {
  const IdentificationOutcome({
    required this.candidates,
    required this.isInsufficient,
    required this.dangerousSpeciesIds,
    required this.isDemo,
    this.scenarioLabel,
  });

  /// Top 5, triés par score décroissant.
  final List<Candidate> candidates;

  /// RM-5 : identification trop incertaine, aucune espèce ne doit être mise en avant.
  final bool isInsufficient;

  /// RM-6 : espèces toxiques/mortelles présentes parmi les candidats.
  final List<String> dangerousSpeciesIds;

  /// Résultat factice (moteur de démonstration).
  final bool isDemo;
  final String? scenarioLabel;
}

/// Applique RM-5 et RM-6 à une liste de candidats.
///
/// Fonction pure : testée unitairement, indépendante du moteur d'identification.
IdentificationOutcome applySafetyRules(
  List<Candidate> raw, {
  required Edibility? Function(String speciesId) edibilityOf,
  SafetyThresholds thresholds = const SafetyThresholds(),
  bool isDemo = false,
  String? scenarioLabel,
}) {
  final sorted = [...raw]..sort((a, b) => b.score.compareTo(a.score));
  final top5 = sorted.take(5).toList();

  var insufficient = top5.isEmpty;
  if (top5.isNotEmpty) {
    final topScore = top5.first.score;
    final margin = top5.length > 1 ? topScore - top5[1].score : topScore;
    insufficient =
        topScore < thresholds.minTopScore || margin < thresholds.minMargin;
  }

  final dangerous = [
    for (final c in top5)
      if (edibilityOf(c.speciesId)?.isDangerous ?? false) c.speciesId,
  ];

  return IdentificationOutcome(
    candidates: top5,
    isInsufficient: insufficient,
    dangerousSpeciesIds: dangerous,
    isDemo: isDemo,
    scenarioLabel: scenarioLabel,
  );
}

/// Entrée du moteur : le chemin de la photo (ignoré par le moteur de démo).
class IdentificationInput {
  const IdentificationInput({this.imagePath});

  final String? imagePath;
}

/// Contrat d'un moteur d'identification. Le vrai modèle embarqué (V1.5)
/// l'implémentera sans modifier l'interface utilisateur.
abstract class Identifier {
  Future<List<Candidate>> identify(IdentificationInput input);
}

/// Scénario prédéfini du moteur de démonstration.
class DemoScenario {
  const DemoScenario(this.label, this.description, this.candidates);

  final String label;
  final String description;
  final List<Candidate> candidates;
}

/// Moteur de DÉMONSTRATION : renvoie des résultats écrits en dur.
/// Ne regarde jamais l'image. À ne pas confondre avec une vraie identification.
class FakeIdentifier implements Identifier {
  FakeIdentifier({this.scenarioIndex = 0});

  int scenarioIndex;

  static const scenarios = <DemoScenario>[
    DemoScenario(
      'Photo nette d\'un bolet',
      'Un résultat clair : un candidat très au-dessus des autres.',
      [
        Candidate(speciesId: 'bolet-bai', score: 0.81),
        Candidate(speciesId: 'cepe-de-bordeaux', score: 0.09),
        Candidate(speciesId: 'bolet-granule', score: 0.04),
        Candidate(speciesId: 'bolet-amer', score: 0.03),
        Candidate(speciesId: 'cepe-d-ete', score: 0.02),
      ],
    ),
    DemoScenario(
      'Champignon orange en forêt',
      'Une comestible et un sosie sans intérêt très proches : identification insuffisante.',
      [
        Candidate(speciesId: 'girolle', score: 0.42),
        Candidate(speciesId: 'fausse-girolle', score: 0.38),
        Candidate(speciesId: 'chanterelle-en-tube', score: 0.10),
        Candidate(speciesId: 'amanite-tue-mouches', score: 0.06),
        Candidate(speciesId: 'pied-de-mouton', score: 0.04),
      ],
    ),
    DemoScenario(
      'Champignon à lames avec anneau',
      'Un candidat mortel est en tête : alerte rouge, jamais de message rassurant.',
      [
        Candidate(speciesId: 'amanite-phalloide', score: 0.68),
        Candidate(speciesId: 'amanite-panthere', score: 0.14),
        Candidate(speciesId: 'amanite-tue-mouches', score: 0.09),
        Candidate(speciesId: 'galere-marginee', score: 0.06),
        Candidate(speciesId: 'girolle', score: 0.03),
      ],
    ),
    DemoScenario(
      'Morille ou fausse morille',
      'Deux candidats proches dont un potentiellement mortel.',
      [
        Candidate(speciesId: 'morille', score: 0.52),
        Candidate(speciesId: 'gyromitre', score: 0.41),
        Candidate(speciesId: 'trompette-de-la-mort', score: 0.04),
        Candidate(speciesId: 'pied-de-mouton', score: 0.02),
        Candidate(speciesId: 'girolle', score: 0.01),
      ],
    ),
  ];

  @override
  Future<List<Candidate>> identify(IdentificationInput input) async {
    // Petit délai pour simuler le temps d'analyse.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return scenarios[scenarioIndex % scenarios.length].candidates;
  }
}

/// Edibilité d'une espèce du catalogue intégré (utilisé hors contexte Riverpod).
Edibility? seedEdibilityOf(String id) {
  for (final s in speciesSeed) {
    if (s.id == id) return s.edibility;
  }
  return null;
}
