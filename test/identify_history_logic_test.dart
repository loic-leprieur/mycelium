import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/features/identify/history/history_logic.dart';
import 'package:mycelium/features/identify/history/place_logic.dart';
import 'package:mycelium/features/identify/history/text_fold.dart';
import 'package:mycelium/features/species/domain/species_groups.dart';

/// Point de départ : une photo prise dans la forêt de la Robertsau.
const photo = LatLng(48.612, 7.7916);

/// Un point à [meters] mètres de la photo, dans la direction [bearing] (° depuis le nord).
LatLng away(double meters, [double bearing = 0]) =>
    const Distance().offset(photo, meters, bearing);

Spot spotAt(String id, String name, LatLng at, {bool favorite = false}) => Spot(
      id: id,
      name: name,
      latitude: at.latitude,
      longitude: at.longitude,
      isFavorite: favorite,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('nearestSpot : le coin proposé pour une photo', () {
    test('renvoie le coin le plus proche, avec sa distance', () {
      final spots = [
        spotAt('a', 'Loin', away(100)),
        spotAt('b', 'Tout près', away(40, 90)),
        spotAt('c', 'Très loin', away(400, 180)),
      ];
      final nearest = nearestSpot(spots, photo);
      expect(nearest, isNotNull);
      expect(nearest!.spot.id, 'b');
      expect(nearest.meters, closeTo(40, 1));
    });

    test('rien à plus de 150 m : la photo est probablement ailleurs', () {
      expect(nearbySpotRadius, 150);
      expect(nearestSpot([spotAt('a', 'Trop loin', away(160))], photo), isNull);
    });

    test('la limite est à 150 m, bornes comprises', () {
      expect(nearestSpot([spotAt('a', 'Juste dedans', away(148))], photo)?.spot.id, 'a');
      expect(nearestSpot([spotAt('a', 'Juste dehors', away(153))], photo), isNull);
      // Rayon personnalisé : un coin à exactement la distance maximale est retenu.
      final spot = spotAt('a', 'Pile', away(70));
      final exact = nearestSpot([spot], photo, maxMeters: nearestSpot([spot], photo)!.meters);
      expect(exact?.spot.id, 'a');
    });

    test('aucun coin enregistré : aucune suggestion', () {
      expect(nearestSpot(const [], photo), isNull);
    });

    test('un coin exactement à la position de la photo (0 m)', () {
      final nearest = nearestSpot([spotAt('a', 'Ici', photo)], photo);
      expect(nearest?.spot.id, 'a');
      expect(nearest?.meters, 0);
    });
  });

  group('sortedSpots : la liste « Un autre coin… »', () {
    test('du plus proche au plus éloigné quand on a une position', () {
      final rows = sortedSpots([
        spotAt('far', 'Aaa', away(900)),
        spotAt('near', 'Zzz', away(30)),
        spotAt('mid', 'Mmm', away(300)),
      ], from: photo);
      expect(rows.map((r) => r.spot.id), ['near', 'mid', 'far']);
      expect(rows.every((r) => r.meters != null), isTrue);
      expect(rows.first.meters, closeTo(30, 1));
    });

    test('sans position : par nom, sans tenir compte des accents ni de la casse', () {
      final rows = sortedSpots([
        spotAt('1', 'Zoé', away(10)),
        spotAt('2', 'étang des mousses', away(20)),
        spotAt('3', 'Abri', away(30)),
        spotAt('4', 'Forêt du nord', away(40)),
      ]);
      expect(rows.map((r) => r.spot.name),
          ['Abri', 'étang des mousses', 'Forêt du nord', 'Zoé']);
      expect(rows.every((r) => r.meters == null), isTrue);
    });

    test('à distance égale, par nom', () {
      final rows = sortedSpots([
        spotAt('b', 'Bruyère', photo),
        spotAt('a', 'Aulnaie', photo),
      ], from: photo);
      expect(rows.map((r) => r.spot.id), ['a', 'b']);
    });

    test('liste vide', () {
      expect(sortedSpots(const [], from: photo), isEmpty);
    });
  });

  group('defaultSpotName : le nom proposé pour un nouveau coin', () {
    final day = DateTime(2026, 10, 9);

    test('un type de champignon et la date', () {
      expect(defaultSpotName(speciesId: 'cepe-de-bordeaux', speciesName: 'Cèpe de Bordeaux', at: day),
          'Cèpes – 9 oct.');
      expect(defaultSpotName(speciesId: 'cepe-des-pins', speciesName: 'Cèpe des pins', at: day),
          'Cèpes – 9 oct.');
      expect(defaultSpotName(speciesId: 'girolle', speciesName: 'Girolle', at: day),
          'Chanterelles – 9 oct.');
      expect(defaultSpotName(speciesId: 'morille', speciesName: 'Morille', at: day),
          'Morilles – 9 oct.');
      expect(defaultSpotName(speciesId: 'amanite-tue-mouches', speciesName: 'Amanite tue-mouches', at: day),
          'Amanites – 9 oct.');
    });

    test('un type fourre-tout ne dit rien : on garde le nom de l\'espèce', () {
      expect(defaultSpotName(speciesId: 'bolet-bai', speciesName: 'Bolet bai', at: day),
          'Bolet bai – 9 oct.');
      expect(defaultSpotName(speciesId: 'galere-marginee', speciesName: 'Galère marginée', at: day),
          'Galère marginée – 9 oct.');
    });

    test('espèce ajoutée par l\'utilisateur : son nom', () {
      expect(defaultSpotName(speciesId: 'id-perso', speciesName: 'Ma trouvaille', at: day),
          'Ma trouvaille – 9 oct.');
    });

    test('date au format court français', () {
      String name(DateTime at) =>
          defaultSpotName(speciesId: 'morille', speciesName: 'Morille', at: at);
      expect(name(DateTime(2026, 5, 3)), 'Morilles – 3 mai');
      expect(name(DateTime(2026, 12, 25)), 'Morilles – 25 déc.');
      expect(name(DateTime(2026, 10, 9, 23, 59)), 'Morilles – 9 oct.');
    });

    test('les noms proposés suivent les libellés du filtre par type', () {
      for (final group in [
        MushroomGroup.cepes,
        MushroomGroup.chanterelles,
        MushroomGroup.morilles,
        MushroomGroup.trompettes,
        MushroomGroup.piedsDeMouton,
        MushroomGroup.amanites,
      ]) {
        final id = speciesGroups.entries.firstWhere((e) => e.value == group).key;
        expect(
          defaultSpotName(speciesId: id, speciesName: 'x', at: day),
          startsWith(group.label),
        );
      }
    });
  });

  group('distanceLabel', () {
    test('tout près : pas de « 0 m »', () {
      expect(distanceLabel(0), 'à moins de 10 m');
      expect(distanceLabel(4), 'à moins de 10 m');
    });

    test('mètres arrondis à 10 m, puis kilomètres', () {
      expect(distanceLabel(40), 'à 40 m');
      expect(distanceLabel(148), 'à 150 m');
      expect(distanceLabel(1200), 'à 1,2 km');
    });
  });

  group('parseTop5 : ce que le modèle proposait', () {
    test('relit les propositions dans l\'ordre enregistré', () {
      final proposals = parseTop5(
        '[{"id":"girolle","score":0.617},{"id":"fausse-girolle","score":0.2},'
        '{"id":"morille","score":0.0123}]',
      );
      expect(proposals.map((p) => p.speciesId), ['girolle', 'fausse-girolle', 'morille']);
      expect(proposals.first.score, 0.617);
    });

    test('JSON illisible ou de mauvaise forme : liste vide, jamais d\'erreur', () {
      expect(parseTop5(''), isEmpty);
      expect(parseTop5('pas du json'), isEmpty);
      expect(parseTop5('{"id":"girolle","score":0.5}'), isEmpty);
      expect(parseTop5('null'), isEmpty);
      expect(parseTop5('[]'), isEmpty);
    });

    test('les entrées incomplètes ou mal typées sont ignorées', () {
      final proposals = parseTop5(
        '[{"id":"girolle"},{"score":0.4},{"id":3,"score":0.4},'
        '{"id":"morille","score":"0.4"},42,null,{"id":"cepe-de-bordeaux","score":1}]',
      );
      expect(proposals.map((p) => p.speciesId), ['cepe-de-bordeaux']);
    });

    test('un score hors de 0–1 est ramené dans l\'intervalle', () {
      final proposals = parseTop5('[{"id":"a","score":-0.2},{"id":"b","score":7}]');
      expect(proposals.map((p) => p.score), [0.0, 1.0]);
    });

    test('un score entier est accepté', () {
      expect(parseTop5('[{"id":"a","score":1}]').single.score, 1.0);
    });
  });

  test('percentLabel arrondit au pourcent entier', () {
    expect(percentLabel(0.617), '62 %');
    expect(percentLabel(0.004), '0 %');
    expect(percentLabel(1), '100 %');
    expect(percentLabel(0.146), '15 %');
    expect(percentLabel(0.5), '50 %');
  });

  group('dates', () {
    final at = DateTime(2026, 10, 9, 14, 32);

    test('court pour la liste', () => expect(shortDateTime(at), '9 oct. 2026 à 14:32'));

    test('long pour le détail',
        () => expect(longDateTime(at), 'vendredi 9 octobre 2026 à 14:32'));

    test('heure à deux chiffres', () {
      expect(shortDateTime(DateTime(2026, 1, 2, 7, 5)), '2 janv. 2026 à 07:05');
    });
  });

  group('filtre par type de l\'historique', () {
    test('les comptes suivent l\'espèce retenue, pas la proposition du modèle', () {
      final counts = historyGroupCounts([
        'cepe-de-bordeaux',
        'cepe-d-ete',
        'girolle',
        'morille',
        'id-perso',
      ]);
      expect(counts, {
        MushroomGroup.cepes: 2,
        MushroomGroup.chanterelles: 1,
        MushroomGroup.morilles: 1,
        MushroomGroup.autres: 1,
      });
    });

    test('« Espèce inconnue » n\'est dans aucun type', () {
      expect(historyGroupCounts([null, null]), isEmpty);
      expect(historyGroupCounts([null, 'girolle']), {MushroomGroup.chanterelles: 1});
      expect(historyGroupCounts(const []), isEmpty);
    });

    test('sélection vide : tout passe, y compris sans espèce', () {
      expect(matchesHistoryFilter('girolle', {}), isTrue);
      expect(matchesHistoryFilter(null, {}), isTrue);
    });

    test('un type choisi ne laisse passer que ses espèces', () {
      final cepes = {MushroomGroup.cepes};
      expect(matchesHistoryFilter('cepe-des-pins', cepes), isTrue);
      expect(matchesHistoryFilter('girolle', cepes), isFalse);
      expect(matchesHistoryFilter(null, cepes), isFalse);
    });

    test('plusieurs types : l\'un OU l\'autre', () {
      final both = {MushroomGroup.cepes, MushroomGroup.morilles};
      expect(matchesHistoryFilter('morille', both), isTrue);
      expect(matchesHistoryFilter('cepe-d-ete', both), isTrue);
      expect(matchesHistoryFilter('girolle', both), isFalse);
    });

    test('une espèce perso est dans « Autres espèces »', () {
      expect(matchesHistoryFilter('id-perso', {MushroomGroup.autres}), isTrue);
      expect(matchesHistoryFilter('id-perso', {MushroomGroup.cepes}), isFalse);
    });
  });

  test('foldAccents : minuscules sans accents', () {
    expect(foldAccents('Cèpe de Bordeaux'), 'cepe de bordeaux');
    expect(foldAccents('Girolle'), 'girolle');
    expect(foldAccents('Forêt d\'Œuvre'), 'foret d\'oeuvre');
    expect(foldAccents('Éphémère çà et là'), 'ephemere ca et la');
    expect(foldAccents(''), '');
  });
}
