import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/features/map/spot_filter.dart';
import 'package:mycelium/features/species/domain/species_groups.dart';

Spot spot(String id, String name, {double lat = 48.0, double lon = 7.0, bool fav = false}) =>
    Spot(
      id: id,
      name: name,
      latitude: lat,
      longitude: lon,
      isFavorite: fav,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

// Cinq coins le long d'un méridien : « a » est le plus proche de la position
// (48,0 ; 7,0), « e » le plus éloigné.
final cepes = spot('a', 'Coin des cèpes', lat: 48.001, fav: true);
final girolles = spot('b', 'Clairière aux girolles', lat: 48.002);
final morilles = spot('c', 'Lisière des morilles', lat: 48.003, fav: true);
final mixte = spot('d', 'Étang du Schlossberg', lat: 48.004);
final vide = spot('e', 'Zone sans observation', lat: 48.005);
final all = [vide, mixte, morilles, girolles, cepes]; // volontairement en désordre

const here = LatLng(48.0, 7.0);

// Types observés dans chaque coin ; « e » n'a aucune observation.
final groupsBySpot = <String, Set<MushroomGroup>>{
  'a': {MushroomGroup.cepes},
  'b': {MushroomGroup.chanterelles},
  'c': {MushroomGroup.morilles},
  'd': {MushroomGroup.cepes, MushroomGroup.chanterelles},
};

final lastVisits = <String, DateTime>{
  'a': DateTime(2026, 9, 1),
  'b': DateTime(2026, 10, 7),
  'c': DateTime(2026, 10, 5),
};

List<String> ids(List<SpotEntry> entries) => [for (final e in entries) e.spot.id];

List<SpotEntry> run({
  LatLng? position = here,
  Set<MushroomGroup> groups = const {},
  bool favoritesOnly = false,
  SpotSort sort = SpotSort.distance,
}) =>
    filterAndSortSpots(
      spots: all,
      groupsBySpot: groupsBySpot,
      lastVisits: lastVisits,
      here: position,
      groups: groups,
      favoritesOnly: favoritesOnly,
      sort: sort,
    );

void main() {
  group('Comptes par type', () {
    test('nombre de coins par type ; un coin sans observation n\'est compté nulle part', () {
      expect(spotGroupCounts(all, groupsBySpot), {
        MushroomGroup.cepes: 2,
        MushroomGroup.chanterelles: 2,
        MushroomGroup.morilles: 1,
      });
    });

    test('plusieurs espèces du même type comptent pour un seul coin', () {
      // Le calcul part de groupsBySpot (types, pas espèces) : un coin = une fois.
      expect(spotGroupCounts([cepes], {'a': groupsOfSpecies(['cepe-d-ete', 'cepe-des-pins'])}),
          {MushroomGroup.cepes: 1});
    });

    test('un coin supprimé (observations orphelines) n\'est plus compté', () {
      final counts = spotGroupCounts([girolles], groupsBySpot);
      expect(counts, {MushroomGroup.chanterelles: 1});
    });

    test('aucun coin : aucun type', () {
      expect(spotGroupCounts(const [], groupsBySpot), isEmpty);
    });
  });

  group('Filtre par type (SPOT-6)', () {
    test('sans filtre, tous les coins passent, même sans observation', () {
      expect(ids(run(sort: SpotSort.name)), hasLength(5));
      expect(ids(run()), contains('e'));
    });

    test('un type ne garde que les coins où il a été observé', () {
      expect(ids(run(groups: {MushroomGroup.chanterelles})), unorderedEquals(['b', 'd']));
      expect(ids(run(groups: {MushroomGroup.morilles})), ['c']);
    });

    test('plusieurs types = OU, sans doublon', () {
      expect(
        ids(run(groups: {MushroomGroup.cepes, MushroomGroup.chanterelles})),
        unorderedEquals(['a', 'b', 'd']), // « d » a les deux types : une seule fois
      );
    });

    test('un type que personne n\'a observé ne laisse aucun coin', () {
      expect(run(groups: {MushroomGroup.amanites}), isEmpty);
    });

    test('un coin sans aucune observation n\'apparaît dans aucun type', () {
      for (final g in MushroomGroup.values) {
        expect(ids(run(groups: {g})), isNot(contains('e')), reason: g.label);
      }
    });

    test('chaque entrée porte ses types et sa dernière visite', () {
      final byId = {for (final e in run()) e.spot.id: e};
      expect(byId['d']!.groups, {MushroomGroup.cepes, MushroomGroup.chanterelles});
      expect(byId['b']!.lastVisit, DateTime(2026, 10, 7));
      expect(byId['e']!.groups, isEmpty);
      expect(byId['e']!.lastVisit, isNull);
    });
  });

  group('Favoris (SPOT-6)', () {
    test('ne garde que les favoris', () {
      expect(ids(run(favoritesOnly: true)), ['a', 'c']);
    });

    test('se combine avec le type : il faut être favori ET avoir le type', () {
      expect(ids(run(favoritesOnly: true, groups: {MushroomGroup.cepes})), ['a']);
      expect(ids(run(favoritesOnly: true, groups: {MushroomGroup.chanterelles})), isEmpty);
    });
  });

  group('Tris (SPOT-6)', () {
    test('par distance : les plus proches d\'abord', () {
      expect(ids(run()), ['a', 'b', 'c', 'd', 'e']);
      final distances = [for (final e in run()) e.distance!];
      expect(distances, orderedEquals([...distances]..sort()));
      expect(distances.first, closeTo(111, 5)); // 0,001° de latitude ≈ 111 m
    });

    test('par nom : alphabétique, sans tenir compte des accents ni de la casse', () {
      // « Étang » se range parmi les E, entre « Coin » et « Lisière ».
      expect(ids(run(sort: SpotSort.name)), ['b', 'a', 'd', 'c', 'e']);
    });

    test('par dernière visite : les plus récentes d\'abord, jamais visités à la fin', () {
      // b (7 oct.) > c (5 oct.) > a (1er sept.) ; d et e jamais visités, par nom.
      expect(ids(run(sort: SpotSort.lastVisit)), ['b', 'c', 'a', 'd', 'e']);
    });

    test('sans position, la distance retombe sur le nom', () {
      expect(effectiveSort(SpotSort.distance, hasPosition: false), SpotSort.name);
      expect(effectiveSort(SpotSort.distance, hasPosition: true), SpotSort.distance);
      expect(effectiveSort(SpotSort.lastVisit, hasPosition: false), SpotSort.lastVisit);
      expect(ids(run(position: null)), ids(run(sort: SpotSort.name)));
      expect(run(position: null).every((e) => e.distance == null), isTrue);
    });

    test('égalité parfaite : départagée par le nom, puis l\'identifiant', () {
      final twins = [
        spot('2', 'Même nom', lat: 48.001),
        spot('1', 'Même nom', lat: 48.001),
        spot('3', 'Autre nom', lat: 48.001),
      ];
      final sorted = filterAndSortSpots(spots: twins, here: here);
      expect([for (final e in sorted) e.spot.id], ['3', '1', '2']);
    });

    test('le tri se combine avec le filtre', () {
      final chanterelles = {MushroomGroup.chanterelles};
      expect(ids(run(groups: chanterelles, sort: SpotSort.name)), ['b', 'd']);
      expect(ids(run(groups: chanterelles, sort: SpotSort.lastVisit)), ['b', 'd']);
      expect(
        ids(run(groups: {MushroomGroup.cepes, MushroomGroup.morilles}, sort: SpotSort.lastVisit)),
        ['c', 'a', 'd'],
      );
    });

    test('ne modifie pas la liste d\'origine', () {
      final before = [...all];
      run(sort: SpotSort.name);
      expect(all, orderedEquals(before));
    });
  });

  group('Titre du panneau', () {
    test('sans filtre : « Mes coins (n) »', () {
      expect(spotListTitle(count: 5), 'Mes coins (5)');
      expect(spotListTitle(count: 0), 'Mes coins (0)');
    });

    test('favoris seuls', () {
      expect(spotListTitle(count: 2, favoritesOnly: true), 'Mes coins favoris (2)');
    });

    test('un type : le nombre de coins correspondants et le type', () {
      expect(spotListTitle(count: 2, groups: {MushroomGroup.chanterelles}),
          'Coins à chanterelles (2)');
      expect(spotListTitle(count: 1, groups: {MushroomGroup.piedsDeMouton}),
          'Coins à pieds-de-mouton (1)');
    });

    test('plusieurs types : liés par « ou », dans l\'ordre des pastilles', () {
      expect(
        spotListTitle(count: 3, groups: {MushroomGroup.chanterelles, MushroomGroup.cepes}),
        'Coins à cèpes ou chanterelles (3)',
      );
      expect(
        spotListTitle(count: 4, groups: {
          MushroomGroup.morilles,
          MushroomGroup.cepes,
          MushroomGroup.chanterelles,
        }),
        'Coins à cèpes, chanterelles ou morilles (4)',
      );
    });

    test('favoris et type ensemble', () {
      expect(
        spotListTitle(count: 1, groups: {MushroomGroup.morilles}, favoritesOnly: true),
        'Coins favoris à morilles (1)',
      );
    });
  });

  group('Textes', () {
    test('types observés sur une ligne, dans l\'ordre des pastilles', () {
      expect(groupsLine({MushroomGroup.chanterelles, MushroomGroup.cepes}),
          'Cèpes · Chanterelles');
      expect(groupsLine({MushroomGroup.morilles}), 'Morilles');
      expect(groupsLine({}), '');
    });

    test('minuscules sans accents pour trier et chercher', () {
      expect(foldText('  Étang Œuf Ça '), 'etang oeuf ca');
      expect(foldText('Cèpe de Bordeaux'), 'cepe de bordeaux');
      expect(foldText('Pied-de-mouton'), 'pied-de-mouton');
    });
  });
}
