import '../../species/domain/species.dart';
import '../identifier.dart';

const frenchMonths = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août',
  'septembre', 'octobre', 'novembre', 'décembre',
];

/// Le [month] (1–12) est-il dans la saison [start] → [end] ? Une saison qui
/// enjambe le nouvel an (novembre → février) est gérée. Null si la saison est
/// inconnue.
bool? isInSeason(int? start, int? end, int month) {
  if (start == null || end == null) return null;
  return start <= end
      ? month >= start && month <= end
      : month >= start || month <= end;
}

/// Candidats (ID-7) dont la saison habituelle ne couvre pas [month].
///
/// Remarque informative seulement : les scores ne sont JAMAIS modifiés (une
/// pondération non validée pourrait atténuer une alerte, interdit par RM-6).
/// Les espèces toxiques ou mortelles sont exclues : « hors saison » ne doit
/// jamais laisser croire qu'elles sont écartées.
List<Species> outOfSeasonCandidates(
  List<Candidate> candidates,
  int month,
  Species? Function(String id) speciesOf,
) {
  final out = <Species>[];
  for (final c in candidates) {
    final s = speciesOf(c.speciesId);
    if (s == null || s.edibility.isDangerous) continue;
    if (isInSeason(s.seasonStart, s.seasonEnd, month) == false) out.add(s);
  }
  return out;
}
