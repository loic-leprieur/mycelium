import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../test/support/flows.dart';
import '../test/support/harness.dart';

/// Parcours complet sur un vrai appareil (Windows, émulateur ou téléphone
/// Android) : mêmes scénarios que les tests de widgets, mais avec le vrai
/// moteur de rendu, les vraies polices et la vraie taille d'écran.
///
///   flutter test integration_test -d windows
///   flutter test integration_test -d ID_EMULATEUR
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets("parcours complet de l'application", (t) async {
    final app = TestApp();
    try {
      // La base est peuplée AVANT d'afficher l'application (voir test/ui).
      await app.seedSpots(t);
      await t.pumpWidget(app.widget);
      await runMapFlow(t);
      await runIdentifyFlow(t);
      await runSpeciesFlow(t);
      await runJournalFlow(t);
    } finally {
      await app.dispose(t);
    }
  });
}
