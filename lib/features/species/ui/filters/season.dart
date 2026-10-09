import '../../domain/species.dart';

/// Les douze mois, en minuscules (« en octobre »).
const monthNames = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// « Octobre » : le mois [month] (1–12) avec une majuscule, pour les boutons.
String capitalMonth(int month) {
  final name = monthNames[month - 1];
  return '${name[0].toUpperCase()}${name.substring(1)}';
}

/// Vrai si [month] (1–12) tombe dans la saison qui va de [start] à [end] (mois
/// compris). Une saison qui finit « avant » de commencer passe par le Nouvel An :
/// novembre → février couvre novembre, décembre, janvier et février.
bool monthInSeason(int month, {required int start, required int end}) =>
    start <= end ? month >= start && month <= end : month >= start || month <= end;

bool _isMonth(int value) => value >= 1 && value <= 12;

/// La saison de [species] couvre-t-elle le mois [month] (1–12) ? `null` quand la
/// fiche n'indique pas de saison (fiche personnelle) ou quand ses mois sont
/// invalides : on ne dit jamais qu'une espèce est « de saison » sans le savoir.
bool? speciesInSeason(Species species, int month) {
  final start = species.seasonStart;
  final end = species.seasonEnd;
  if (start == null || end == null || !_isMonth(start) || !_isMonth(end)) return null;
  return monthInSeason(month, start: start, end: end);
}
