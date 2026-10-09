import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mycelium/app.dart';
import 'package:mycelium/core/group_filter.dart';
import 'package:mycelium/core/router.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/data/providers.dart';
import 'package:mycelium/features/identify/identifier_provider.dart';
import 'package:mycelium/features/map/location.dart';
import 'package:mycelium/features/map/map_config.dart';
import 'package:mycelium/features/map/spot_filter.dart';
import 'package:mycelium/features/map/ui/map_screen.dart';
import 'package:mycelium/features/map/ui/map_widgets.dart';
import 'package:mycelium/features/species/domain/species_groups.dart';

import 'spot_support.dart';
import 'support/harness.dart';

const _cepes = 'Coin des cèpes (test)';
const _girolles = 'Clairière aux girolles (test)';
const _morilles = 'Lisière des morilles (test)';
const _vide = 'Zone sans observation';

Finder _inMap(Finder f) => find.descendant(of: find.byType(MapScreen), matching: f);

/// Pastille du panneau. La rangée des types défile : une pastille sortie de
/// l'écran existe encore, d'où `skipOffstage: false`.
Finder _chip(String label) =>
    _inMap(find.widgetWithText(FilterChip, label, skipOffstage: false));

/// Appuie sur une pastille du panneau (amenée à l'écran si elle est hors de la
/// rangée visible).
Future<void> _tapChip(WidgetTester t, String label) async {
  await t.ensureVisible(_chip(label));
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(_chip(label));
  await settle(t);
}

bool _selected(WidgetTester t, String label) => t.widget<FilterChip>(_chip(label)).selected;

/// Noms des coins affichés dans la liste, dans l'ordre.
List<String> _listed(WidgetTester t) =>
    [for (final w in t.widgetList<SpotTile>(find.byType(SpotTile))) w.spot.name];

/// Identifiants des coins posés sur la carte.
List<String> _pins(WidgetTester t) {
  final layer = t.widget<MarkerLayer>(find.byType(MarkerLayer));
  return [
    for (final m in layer.markers)
      if (m.key case ValueKey<String>(:final value) when value.startsWith('pin-'))
        value.substring(4),
  ];
}

Future<void> _chooseSort(WidgetTester t, String menuLabel) async {
  await t.tap(find.byType(PopupMenuButton<SpotSort>));
  await settle(t);
  await t.tap(find.widgetWithText(CheckedPopupMenuItem<SpotSort>, menuLabel));
  await settle(t);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await loadTestFonts();
  });

  group('Panneau des coins', () {
    testWidgets('chaque coin montre ses types et sa dernière visite', (t) async {
      await withSpotApp(t, (app) async {
        expect(find.text('Mes coins (4)'), findsOneWidget);

        // Types observés (SPOT-4), dans l'ordre des pastilles.
        expect(find.text('Cèpes · Chanterelles'), findsOneWidget); // coin des cèpes
        expect(find.text('Chanterelles'), findsOneWidget); // clairière
        expect(find.text('Morilles'), findsOneWidget); // lisière

        // Dernière visite (SPOT-5) : la plus récente, ou « Jamais visité ».
        expect(find.text('Dernière visite : 5 oct. 2026'), findsOneWidget); // cèpes
        expect(find.text('Dernière visite : 28 sept. 2026'), findsOneWidget); // clairière
        expect(find.text('Dernière visite : 7 oct. 2026'), findsOneWidget); // lisière
        expect(find.text('Jamais visité'), findsOneWidget); // zone sans observation
      });
    });

    testWidgets('les pastilles donnent le nombre de coins par type', (t) async {
      await withSpotApp(t, (app) async {
        expect(_chip('Cèpes (1)'), findsOneWidget);
        expect(_chip('Chanterelles (2)'), findsOneWidget);
        expect(_chip('Morilles (1)'), findsOneWidget);
        // Aucun coin à trompettes : pas de pastille inutile.
        expect(_inMap(find.textContaining('Trompettes')), findsNothing);
        expect(_selected(t, 'Tous'), isTrue);
      });
    });

    testWidgets('filtrer « Chanterelles » ne garde que les bons coins, liste et carte', (t) async {
      await withSpotApp(t, (app) async {
        expect(_listed(t), hasLength(4));
        expect(_pins(t), unorderedEquals(['seed-0', 'seed-1', 'seed-2', 'seed-3']));

        await _tapChip(t, 'Chanterelles (2)');

        expect(find.text('Coins à chanterelles (2)'), findsOneWidget);
        expect(find.text('Mes coins (4)'), findsNothing);
        expect(_listed(t), [_cepes, _girolles]); // du plus proche au plus lointain
        expect(_selected(t, 'Chanterelles (2)'), isTrue);
        expect(_selected(t, 'Tous'), isFalse);
        // La carte montre les mêmes coins que la liste.
        expect(_pins(t), unorderedEquals(['seed-0', 'seed-1']));
      });
    });

    testWidgets('plusieurs types = OU ; « Tous » efface la sélection', (t) async {
      await withSpotApp(t, (app) async {
        await _tapChip(t, 'Morilles (1)');
        expect(_listed(t), [_morilles]);
        expect(find.text('Coins à morilles (1)'), findsOneWidget);

        await _tapChip(t, 'Cèpes (1)');
        expect(find.text('Coins à cèpes ou morilles (2)'), findsOneWidget);
        expect(_listed(t), [_cepes, _morilles]);
        expect(_pins(t), unorderedEquals(['seed-0', 'seed-2']));

        await _tapChip(t, 'Tous');
        expect(find.text('Mes coins (4)'), findsOneWidget);
        expect(_listed(t), hasLength(4));
        expect(_pins(t), hasLength(4));
        expect(_selected(t, 'Tous'), isTrue);
      });
    });

    testWidgets('désélectionner un type le retire du filtre', (t) async {
      await withSpotApp(t, (app) async {
        await _tapChip(t, 'Chanterelles (2)');
        await _tapChip(t, 'Chanterelles (2)');
        expect(find.text('Mes coins (4)'), findsOneWidget);
        expect(_selected(t, 'Tous'), isTrue);
      });
    });

    testWidgets('un coin sans observation n\'est visible qu\'avec « Tous »', (t) async {
      await withSpotApp(t, (app) async {
        expect(_listed(t), contains(_vide));
        for (final label in ['Cèpes (1)', 'Chanterelles (2)', 'Morilles (1)']) {
          await _tapChip(t, label);
          expect(_listed(t), isNot(contains(_vide)), reason: label);
          expect(_pins(t), isNot(contains('seed-3')), reason: label);
          await _tapChip(t, label);
        }
        expect(_listed(t), contains(_vide));
      });
    });

    testWidgets('aucun coin ne correspond : message et « Tout afficher »', (t) async {
      await withSpotApp(t, (app) async {
        await _tapChip(t, 'Morilles (1)');
        // La lisière n'est pas un favori.
        await _tapChip(t, 'Favoris');

        expect(find.text('Aucun coin ne correspond'), findsOneWidget);
        expect(find.text('Coins favoris à morilles (0)'), findsOneWidget);
        expect(_listed(t), isEmpty);
        expect(_pins(t), isEmpty);

        await t.tap(find.text('Tout afficher'));
        await settle(t);
        expect(find.text('Aucun coin ne correspond'), findsNothing);
        expect(find.text('Mes coins (4)'), findsOneWidget);
        expect(_listed(t), hasLength(4));
        expect(_selected(t, 'Tous'), isTrue);
        expect(t.widget<FilterChip>(_chip('Favoris')).selected, isFalse);
      });
    });

    testWidgets('le filtre « Favoris » seul, puis combiné avec un type', (t) async {
      await withSpotApp(t, (app) async {
        await _tapChip(t, 'Favoris');
        expect(find.text('Mes coins favoris (1)'), findsOneWidget);
        expect(_listed(t), [_cepes]);
        expect(_pins(t), ['seed-0']);

        // Favori ET chanterelles : le coin des cèpes a aussi des girolles.
        await _tapChip(t, 'Chanterelles (2)');
        expect(find.text('Coins favoris à chanterelles (1)'), findsOneWidget);
        expect(_listed(t), [_cepes]);

        // Favori ET morilles : aucun.
        await _tapChip(t, 'Chanterelles (2)');
        await _tapChip(t, 'Morilles (1)');
        expect(_listed(t), isEmpty);
        expect(find.text('Aucun coin ne correspond'), findsOneWidget);
      });
    });

    testWidgets('le coin guidé reste sur la carte même si le filtre l\'écarte', (t) async {
      await withSpotApp(t, (app) async {
        await t.tap(find.text(_morilles));
        await settle(t);
        expect(find.text('Guidage en cours'), findsOneWidget);

        final container = ProviderScope.containerOf(t.element(find.byType(MapScreen)));
        container.read(mapGroupFilterProvider.notifier).toggle(MushroomGroup.chanterelles);
        await settle(t);

        // seed-2 (morilles) n'a pas de chanterelles, mais on s'y rend.
        expect(_pins(t), unorderedEquals(['seed-0', 'seed-1', 'seed-2']));
      });
    });

    testWidgets('un type qui disparaît des données quitte la sélection', (t) async {
      await withSpotApp(t, (app) async {
        await _tapChip(t, 'Morilles (1)');
        expect(_listed(t), [_morilles]);

        // La seule observation de morilles est retirée.
        await t.runAsync(() => app.db.unmarkSpecies('seed-2', 'morille'));
        await settle(t);

        expect(_inMap(find.textContaining('Morilles')), findsNothing);
        expect(find.text('Mes coins (4)'), findsOneWidget);
        expect(find.text('Aucun coin ne correspond'), findsNothing);
        expect(_selected(t, 'Tous'), isTrue);
        expect(_listed(t), hasLength(4));
      });
    });

    testWidgets('une espèce ajoutée en base fait apparaître le coin dans le type', (t) async {
      await withSpotApp(t, (app) async {
        expect(_chip('Chanterelles (2)'), findsOneWidget);
        await t.runAsync(() => app.db.markSpeciesSeen('seed-3', 'chanterelle-cendree', day(10, 8)));
        await settle(t);

        expect(_chip('Chanterelles (3)'), findsOneWidget);
        await _tapChip(t, 'Chanterelles (3)');
        expect(_listed(t), contains(_vide));
      });
    });
  });

  group('Tris', () {
    testWidgets('par défaut : les plus proches d\'abord', (t) async {
      await withSpotApp(t, (app) async {
        expect(find.text('Trier : Distance'), findsOneWidget);
        expect(_listed(t), [_cepes, _girolles, _morilles, _vide]);
      });
    });

    testWidgets('par nom, puis par dernière visite', (t) async {
      await withSpotApp(t, (app) async {
        await _chooseSort(t, 'Nom (de A à Z)');
        expect(find.text('Trier : Nom'), findsOneWidget);
        expect(_listed(t), [_girolles, _cepes, _morilles, _vide]);

        await _chooseSort(t, 'Dernière visite (les plus récentes)');
        expect(find.text('Trier : Dernière visite'), findsOneWidget);
        // Lisière (7 oct.), coin des cèpes (5 oct.), clairière (28 sept.), puis
        // le coin jamais visité.
        expect(_listed(t), [_morilles, _cepes, _girolles, _vide]);

        await _chooseSort(t, 'Distance (les plus proches)');
        expect(_listed(t), [_cepes, _girolles, _morilles, _vide]);
      });
    });

    testWidgets('le tri se combine avec le filtre par type', (t) async {
      await withSpotApp(t, (app) async {
        await _tapChip(t, 'Chanterelles (2)');
        await _chooseSort(t, 'Nom (de A à Z)');
        expect(_listed(t), [_girolles, _cepes]);
        expect(find.text('Coins à chanterelles (2)'), findsOneWidget);
      });
    });

    testWidgets('boutons de filtre et de tri : cibles tactiles de 48 dp au moins', (t) async {
      await withSpotApp(t, (app) async {
        for (final f in [_chip('Favoris'), find.byType(PopupMenuButton<SpotSort>), _chip('Tous')]) {
          final size = t.getSize(f);
          expect(size.height, greaterThanOrEqualTo(48), reason: '$f');
          expect(size.width, greaterThanOrEqualTo(48), reason: '$f');
        }
      });
    });

    testWidgets('un seul coin : pas de commandes de tri inutiles', (t) async {
      await withSpotApp(t, (app) async {
        expect(find.text('Mes coins (1)'), findsOneWidget);
        expect(find.byType(PopupMenuButton<SpotSort>), findsNothing);
        expect(_chip('Favoris'), findsNothing);
      }, seed: (db) async {
        await db.deleteSpot('seed-1');
        await db.deleteSpot('seed-2');
      });
    });
  });

  testWidgets('sans position GPS : tri par nom, distance grisée dans le menu', (t) async {
    applyScreen(t, tallWindow);
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await t.runAsync(() async {
        for (final (i, name) in [_cepes, _girolles, _morilles].indexed) {
          await db.upsertSpot(SpotsCompanion.insert(
            id: 'seed-$i',
            name: name,
            latitude: 48.61 + i / 100,
            longitude: 7.79,
            createdAt: day(10, 8),
            updatedAt: day(10, 8),
          ));
        }
        await seedSpotData(db);
      });
      await t.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) => db),
          locationProvider.overrideWith(
            (ref) => Stream.value(const LocationState(LocationStatus.denied)),
          ),
          tilesEnabledProvider.overrideWithValue(false),
          identifierProvider.overrideWith((ref) async => null),
        ],
        child: MyceliumApp(router: buildRouter(initialLocation: '/map')),
      ));
      await settle(t);

      // « Distance » est le tri par défaut, mais faute de position c'est le nom.
      expect(find.text('Trier : Nom'), findsOneWidget);
      expect(_listed(t), [_girolles, _cepes, _morilles, _vide]);
      expect(t.widgetList<SpotTile>(find.byType(SpotTile)).every((w) => w.distance == null), isTrue);

      await t.tap(find.byType(PopupMenuButton<SpotSort>));
      await settle(t);
      final distance = t.widget<CheckedPopupMenuItem<SpotSort>>(
        find.widgetWithText(CheckedPopupMenuItem<SpotSort>, 'Distance (position inconnue)'),
      );
      expect(distance.enabled, isFalse);
      final name = t.widget<CheckedPopupMenuItem<SpotSort>>(
        find.widgetWithText(CheckedPopupMenuItem<SpotSort>, 'Nom (de A à Z)'),
      );
      expect(name.enabled, isTrue);
      expect(name.checked, isTrue);
    } finally {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      await t.runAsync(db.close);
    }
  });
}
