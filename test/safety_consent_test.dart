import 'package:drift/native.dart';
import 'package:flutter/material.dart'
    show AppBar, BackButton, Checkbox, FilledButton, NavigationBar;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mycelium/data/database.dart';
import 'package:mycelium/features/safety/consent.dart';

import 'support/flows.dart';
import 'support/harness.dart';

/// Somme de contrôle (FNV-1a) du texte de consentement.
int textChecksum() {
  var h = 0x811c9dc5;
  final text = [
    consentTitle,
    ...consentPoints,
    consentCheckboxLabel,
    consentButtonLabel,
  ].join('\n');
  for (final unit in text.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// Écran de consentement affiché seul (route directe), sur l'application de test.
Future<TestApp> openApp(
  WidgetTester t,
  String location, {
  Future<void> Function(AppDatabase db)? seed,
}) async {
  applyScreen(t, screenCases[1]);
  final app = TestApp(initialLocation: location);
  if (seed != null) await t.runAsync(() => seed(app.db));
  await t.pumpWidget(app.widget);
  await settle(t);
  return app;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await loadTestFonts();
  });

  group('Consentement : journal', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('rien d\'enregistré => non accepté', () async {
      expect(await hasValidConsent(db), isFalse);
    });

    test('accepté => valide, avec date ISO et version écrites', () async {
      final at = DateTime.utc(2026, 10, 9, 12, 30);
      await recordConsent(db, now: at);
      expect(await hasValidConsent(db), isTrue);
      expect(
        await db.metaValue(consentKeyAcceptedAt),
        '2026-10-09T12:30:00.000Z',
      );
      expect(await db.metaValue(consentKeyVersion), '$consentVersion');
    });

    test('version différente => redemandé', () async {
      await recordConsent(db);
      await db.setMeta(consentKeyVersion, '${consentVersion - 1}');
      expect(await hasValidConsent(db), isFalse);
      await db.setMeta(consentKeyVersion, '${consentVersion + 1}');
      expect(await hasValidConsent(db), isFalse);
    });

    test('valeurs illisibles ou incomplètes => redemandé', () async {
      await db.setMeta(consentKeyVersion, '$consentVersion');
      expect(await hasValidConsent(db), isFalse, reason: 'sans date');
      await db.setMeta(consentKeyAcceptedAt, 'pas une date');
      expect(await hasValidConsent(db), isFalse, reason: 'date illisible');
      await db.setMeta(consentKeyAcceptedAt, '2026-10-09T10:00:00Z');
      await db.setMeta(consentKeyVersion, 'x');
      expect(await hasValidConsent(db), isFalse, reason: 'version illisible');
    });

    test('le texte ne change pas sans changer la version', () {
      // Si ce test échoue : vous avez modifié le texte de consentement. Incrémentez
      // consentVersion (consent.dart) puis mettez à jour ce couple.
      expect((consentVersion, textChecksum()), (1, expectedChecksum));
    });
  });

  group('Consentement : parcours', () {
    testWidgets('bouton désactivé tant que la case n\'est pas cochée', (
      t,
    ) async {
      final app = await openApp(t, '/consent');
      try {
        FilledButton button() => t.widget<FilledButton>(
          find.widgetWithText(FilledButton, consentButtonLabel),
        );
        expect(button().onPressed, isNull);
        await t.tap(find.byType(Checkbox));
        await t.pump();
        expect(button().onPressed, isNotNull);
        await t.tap(find.byType(Checkbox));
        await t.pump();
        expect(button().onPressed, isNull);
        expect(await app.db.metaValue(consentKeyAcceptedAt), isNull);
      } finally {
        await app.dispose(t);
      }
    });

    testWidgets('pas de contournement : ni bouton retour ni retour système', (
      t,
    ) async {
      final app = await openApp(t, '/consent');
      try {
        expect(find.byTooltip('Retour'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(BackButton),
          ),
          findsNothing,
        );
        await t.binding.handlePopRoute();
        await settle(t);
        expect(find.text(consentButtonLabel), findsOneWidget);
        expect(find.text('Mes coins (0)'), findsNothing);
      } finally {
        await app.dispose(t);
      }
    });

    testWidgets('accepter journalise puis ouvre la carte', (t) async {
      final app = await openApp(t, '/consent');
      try {
        await t.tap(find.byType(Checkbox));
        await t.pump();
        await t.tap(find.text(consentButtonLabel));
        await settle(t);
        expect(find.text(consentButtonLabel), findsNothing);
        expect(find.byType(NavigationBar), findsOneWidget);
        final at = await t.runAsync(
          () => app.db.metaValue(consentKeyAcceptedAt),
        );
        final version = await t.runAsync(
          () => app.db.metaValue(consentKeyVersion),
        );
        expect(DateTime.tryParse(at!), isNotNull);
        expect(version, '$consentVersion');
      } finally {
        await app.dispose(t);
      }
    });

    testWidgets('accueil : consentement valide => carte directement', (
      t,
    ) async {
      final app = await openApp(t, '/splash', seed: recordConsent);
      try {
        await t.pump(const Duration(milliseconds: 2500));
        await settle(t);
        expect(find.text(consentButtonLabel), findsNothing);
        expect(find.byType(NavigationBar), findsOneWidget);
      } finally {
        await app.dispose(t);
      }
    });

    testWidgets('accueil : version changée => consentement redemandé', (
      t,
    ) async {
      final app = await openApp(
        t,
        '/splash',
        seed: (db) async {
          await recordConsent(db);
          await db.setMeta(consentKeyVersion, '${consentVersion + 1}');
        },
      );
      try {
        await t.pump(const Duration(milliseconds: 2500));
        await settle(t);
        expect(find.text(consentButtonLabel), findsOneWidget);
      } finally {
        await app.dispose(t);
      }
    });

    testWidgets('accueil : un appui ne contourne pas le consentement', (
      t,
    ) async {
      final app = await openApp(t, '/splash');
      try {
        await t.tap(find.text('Mycelium'));
        await settle(t);
        expect(find.text(consentButtonLabel), findsOneWidget);
      } finally {
        await app.dispose(t);
      }
    });
  });
}

const expectedChecksum = 3576934090;
