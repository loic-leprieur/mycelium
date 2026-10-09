import 'dart:convert';

import 'package:intl/intl.dart';

import '../../species/domain/species_groups.dart';

/// Probabilité d'une espèce hors de la base à partir de laquelle on le signale
/// (résultat d'identification et détail d'une identification enregistrée).
const unknownScoreNoteThreshold = 0.15;

/// Une proposition du modèle, relue depuis `top5Json`.
typedef ModelProposal = ({String speciesId, double score});

/// Lit le top 5 enregistré (`[{"id": "girolle", "score": 0.81}, …]`). Tolérant :
/// un JSON illisible, ou une entrée incomplète, est ignoré plutôt que de faire
/// échouer l'écran.
List<ModelProposal> parseTop5(String json) {
  final Object? data;
  try {
    data = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (data is! List) return const [];
  final proposals = <ModelProposal>[];
  for (final entry in data) {
    if (entry is! Map) continue;
    final id = entry['id'];
    final score = entry['score'];
    if (id is! String || score is! num) continue;
    proposals.add((speciesId: id, score: score.toDouble().clamp(0.0, 1.0)));
  }
  return proposals;
}

/// Score en pourcentage entier : 0,617 donne « 62 % ».
String percentLabel(double score) => '${(score * 100).round()} %';

/// « 9 oct. 2026 à 14:32 » (liste).
String shortDateTime(DateTime at) =>
    DateFormat("d MMM y 'à' HH:mm", 'fr').format(at);

/// « vendredi 9 octobre 2026 à 14:32 » (détail).
String longDateTime(DateTime at) =>
    DateFormat("EEEE d MMMM y 'à' HH:mm", 'fr').format(at);

/// Nombre d'identifications par type de champignon, d'après l'espèce que
/// l'utilisateur a retenue. Une identification sans espèce (« Je ne sais
/// pas ») n'est dans aucun type.
Map<MushroomGroup, int> historyGroupCounts(Iterable<String?> chosenSpeciesIds) {
  final counts = <MushroomGroup, int>{};
  for (final id in chosenSpeciesIds) {
    if (id == null) continue;
    final group = groupOfSpecies(id);
    counts[group] = (counts[group] ?? 0) + 1;
  }
  return counts;
}

/// Vrai si une identification passe le filtre par type (sélection vide = tout).
/// Sans espèce retenue, elle n'apparaît que lorsque aucun type n'est choisi.
bool matchesHistoryFilter(String? chosenSpeciesId, Set<MushroomGroup> selected) =>
    matchesGroups(chosenSpeciesId == null ? const [] : [chosenSpeciesId], selected);
