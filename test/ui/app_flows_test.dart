import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:mycelium/core/rustic.dart';

import '../support/flows.dart';
import '../support/harness.dart';

/// Lance l'application sur un écran de la taille voulue, exécute [body], puis
/// nettoie (les animations répétées et la base ne doivent rien laisser).
Future<void> withApp(
  WidgetTester t,
  ScreenCase screen,
  Future<void> Function() body, {
  String initialLocation = '/map',
}) async {
  applyScreen(t, screen);
  final app = TestApp(initialLocation: initialLocation);
  try {
    // La base est peuplée AVANT d'afficher l'application : sinon ses lectures,
    // démarrées dans le temps simulé des tests, bloqueraient l'écriture.
    await app.seedSpots(t);
    await t.pumpWidget(app.widget);
    await body();
  } finally {
    await app.dispose(t);
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await loadTestFonts();
  });

  for (final screen in screenCases) {
    group(screen.name, () {
      testWidgets("carte : liste des coins et guidage à vol d'oiseau", (t) async {
        await withApp(t, screen, () => runMapFlow(t));
      });

      testWidgets('identification : alerte sur espèce mortelle', (t) async {
        await withApp(t, screen, () async {
          await settle(t);
          await runIdentifyFlow(t);
        });
      });

      testWidgets('espèces : recherche, fiche et ajout', (t) async {
        await withApp(t, screen, () async {
          await settle(t);
          await runSpeciesFlow(t);
        });
      });

      testWidgets('carnet : sortie et récolte', (t) async {
        await withApp(t, screen, () async {
          await settle(t);
          await runJournalFlow(t);
        });
      });

      testWidgets('navigation entre les 4 onglets', (t) async {
        await withApp(t, screen, () async {
          await settle(t);
          for (final tab in ['Identifier', 'Espèces', 'Carnet', 'Carte']) {
            await tapTab(t, tab);
          }
          expect(find.text('Mes coins (3)'), findsOneWidget);
        });
      });
    });
  }

  testWidgets("écran d'accueil animé puis carte", (t) async {
    await withApp(t, screenCases[1], () async {
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Mycelium'), findsOneWidget);
      expect(find.text(appSlogan), findsOneWidget);
      await t.pump(const Duration(milliseconds: 2500));
      await settle(t);
      expect(find.text('Mes coins (3)'), findsOneWidget);
    }, initialLocation: '/splash');
  });
}
