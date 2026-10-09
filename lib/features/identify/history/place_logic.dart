import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/database.dart';
import '../../map/geo.dart';
import '../../species/domain/species_groups.dart';
import 'text_fold.dart';

/// Rayon (m) dans lequel un coin déjà enregistré est proposé comme emplacement
/// d'une identification : au-delà, c'est probablement un autre endroit.
const nearbySpotRadius = 150.0;

/// Un coin et sa distance en ligne droite (m) à une position ; null si on ne
/// connaît aucune position.
typedef SpotAt = ({Spot spot, double? meters});

/// Le coin le plus proche de [from], à au plus [maxMeters] (null s'il n'y en a
/// aucun). Ligne droite, sans réseau.
({Spot spot, double meters})? nearestSpot(
  Iterable<Spot> spots,
  LatLng from, {
  double maxMeters = nearbySpotRadius,
}) {
  ({Spot spot, double meters})? best;
  for (final spot in spots) {
    final meters = metersBetween(from, LatLng(spot.latitude, spot.longitude));
    if (meters <= maxMeters && (best == null || meters < best.meters)) {
      best = (spot: spot, meters: meters);
    }
  }
  return best;
}

/// Les coins du plus proche au plus éloigné de [from] ; sans position, par nom
/// (alphabétique, sans tenir compte des accents ni des majuscules).
List<SpotAt> sortedSpots(Iterable<Spot> spots, {LatLng? from}) {
  final rows = <SpotAt>[
    for (final spot in spots)
      (
        spot: spot,
        meters: from == null
            ? null
            : metersBetween(from, LatLng(spot.latitude, spot.longitude)),
      ),
  ];
  int byName(SpotAt a, SpotAt b) =>
      foldAccents(a.spot.name).compareTo(foldAccents(b.spot.name));
  rows.sort((a, b) {
    final da = a.meters;
    final db = b.meters;
    if (da == null || db == null) return byName(a, b);
    final byDistance = da.compareTo(db);
    return byDistance != 0 ? byDistance : byName(a, b);
  });
  return rows;
}

/// « à 40 m », « à 1,2 km » ; « à moins de 10 m » tout près (les distances sont
/// arrondies à 10 m, inutile d'afficher « 0 m »).
String distanceLabel(double meters) =>
    meters < 10 ? 'à moins de 10 m' : 'à ${formatDistance(meters)}';

/// Nom proposé pour un nouveau coin : le type de champignon et la date, par
/// exemple « Chanterelles – 9 oct. ». Pour « Autres bolets » et « Autres
/// espèces », qui ne disent rien, on garde le nom de l'espèce.
String defaultSpotName({
  required String speciesId,
  required String speciesName,
  required DateTime at,
}) {
  final group = groupOfSpecies(speciesId);
  final base = switch (group) {
    MushroomGroup.bolets || MushroomGroup.autres => speciesName,
    _ => group.label,
  };
  return '$base – ${DateFormat('d MMM', 'fr').format(at)}';
}
