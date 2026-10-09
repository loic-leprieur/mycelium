import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../data/database.dart';

/// Date de la sortie la plus récente de chaque coin (SPOT-5). Les sorties
/// sans coin sont ignorées.
Map<String, DateTime> lastVisitBySpot(Iterable<Outing> outings) {
  final last = <String, DateTime>{};
  for (final outing in outings) {
    final spotId = outing.spotId;
    if (spotId == null) continue;
    final seen = last[spotId];
    if (seen == null || outing.startedAt.isAfter(seen)) {
      last[spotId] = outing.startedAt;
    }
  }
  return last;
}

/// Date courte : « 5 oct. 2026 ».
String shortDate(DateTime date) => DateFormat.yMMMd('fr').format(date);

/// « Dernière visite : 5 oct. 2026 », ou « Jamais visité ».
String visitLabel(DateTime? lastVisit) => lastVisit == null
    ? 'Jamais visité'
    : 'Dernière visite : ${shortDate(lastVisit)}';

/// Résumé des récoltes d'une sortie : « Cèpe de Bordeaux, Girolle · 5 pièces ·
/// 850 g ». [nameOf] donne le nom d'une espèce à partir de son identifiant.
String harvestSummary(
  Iterable<Harvest> harvests,
  String Function(String speciesId) nameOf,
) {
  if (harvests.isEmpty) return 'Aucune récolte';
  final names = <String>{for (final h in harvests) nameOf(h.speciesId)};
  final pieces = harvests.fold<int>(0, (sum, h) => sum + (h.quantityCount ?? 0));
  final grams = harvests.fold<int>(0, (sum, h) => sum + (h.weightGrams ?? 0));
  return [
    names.join(', '),
    if (pieces > 0) formatPieces(pieces),
    if (grams > 0) formatWeight(grams),
  ].join(' · ');
}
