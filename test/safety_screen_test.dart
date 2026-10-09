import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mycelium/core/safety_widgets.dart';
import 'package:mycelium/core/theme.dart';
import 'package:mycelium/features/safety/phone_dialer.dart';
import 'package:mycelium/features/safety/poison_data.dart';
import 'package:mycelium/features/safety/safety_screen.dart';

import 'support/harness.dart';

Future<void> show(
  WidgetTester t,
  PhoneDialer dialer, {
  ScreenCase screen = const ScreenCase('page haute', 412, 6000, 1),
}) async {
  applyScreen(t, screen);
  await t.pumpWidget(
    ProviderScope(
      overrides: [phoneDialerProvider.overrideWithValue(dialer)],
      child: MaterialApp(
        theme: buildTheme(),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SafetyScreen(),
      ),
    ),
  );
  await t.pump();
}

/// Tous les textes affichés par l'écran (y compris le texte sélectionnable).
String allText(WidgetTester t) => [
  for (final w in t.widgetList<Text>(find.byType(Text))) w.data ?? '',
  for (final w in t.widgetList<SelectableText>(find.byType(SelectableText)))
    w.data ?? '',
].join('\n');

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await loadTestFonts();
  });

  testWidgets('15 et 112 sont en tête, avec leurs boutons d\'appel', (t) async {
    final called = <String>[];
    await show(t, (uri) async {
      called.add(uri.toString());
      return true;
    });
    expect(
      find.text('En cas de symptômes, appelez le 15 (SAMU) ou le 112'),
      findsOneWidget,
    );
    await t.tap(find.text('Appeler le 15 (SAMU)'));
    await t.tap(find.text('Appeler le 112'));
    expect(called, ['tel:15', 'tel:112']);
    // Le bandeau est au-dessus de tout le reste.
    expect(
      t.getTopLeft(find.text('Appeler le 15 (SAMU)')).dy,
      lessThan(t.getTopLeft(find.text('Centres antipoison')).dy),
    );
  });

  testWidgets('aucun numéro affiché hors de la liste vérifiée', (t) async {
    await show(t, (_) async => true);
    final text = allText(t);
    final found = RegExp(
      r'(?<![\d/])(?:0\d(?: \d\d){4}|0\d{9}|\d{2,3})(?![\d/])',
    ).allMatches(text).map((m) => m.group(0)!).toSet();
    // Les nombres de 2 à 3 chiffres (15, 112, années tronquées, 150 g…) restent
    // possibles : on ne retient que ceux qui ressemblent à un numéro d'appel.
    final phones = found.where(
      (n) => n.startsWith('0') || n == '15' || n == '112',
    );
    expect(phones, isNotEmpty);
    for (final n in phones) {
      expect(verifiedNumbers, contains(n), reason: 'numéro non vérifié : $n');
    }
    for (final n in verifiedNumbers) {
      expect(text, contains(n), reason: 'numéro vérifié absent : $n');
    }
  });

  test('liste officielle : 8 centres et le numéro national', () {
    expect(poisonCentres.map((c) => c.label), [
      'Angers',
      'Bordeaux',
      'Lille',
      'Lyon',
      'Marseille',
      'Nancy',
      'Paris',
      'Toulouse',
    ]);
    expect(nationalPoisonNumber.display, '01 45 42 59 59');
    for (final e in [...poisonCentres, nationalPoisonNumber]) {
      expect(e.display.replaceAll(' ', ''), e.dial, reason: e.label);
    }
  });

  testWidgets(
    'chaque geste cite sa source ; source et date de vérification affichées',
    (t) async {
      await show(t, (_) async => true);
      for (final g in gestures) {
        expect(g.source, isNotEmpty);
      }
      final text = allText(t);
      expect(text, contains('vérifiés le $safetyVerifiedOn'));
      for (final s in safetySources) {
        expect(text, contains(s));
      }
      expect(text, contains("Cette application n'est pas un avis médical"));
      expect(text, contains('Un délai long est un signe de gravité'));
    },
  );

  testWidgets(
    'appel impossible (ordinateur) : message, numéro toujours affiché',
    (t) async {
      await show(t, (_) async => false);
      await t.tap(find.text('Appeler le 15 (SAMU)'));
      await t.pump();
      expect(
        find.textContaining("L'appel n'a pas pu être lancé"),
        findsOneWidget,
      );
      expect(find.text('15'), findsNothing);
      expect(find.text('Appeler le 15 (SAMU)'), findsOneWidget);
    },
  );

  testWidgets(
    'appel en erreur (exception de la plateforme) : pas de plantage',
    (t) async {
      await show(t, (_) async => throw Exception('pas de téléphonie'));
      await t.tap(find.byTooltip('Appeler Nancy 03 83 22 50 50'));
      await t.pump();
      expect(find.textContaining('Composez le 03 83 22 50 50'), findsOneWidget);
      expect(find.byType(SelectableText), findsWidgets);
    },
  );

  for (final screen in screenCases) {
    testWidgets('mise en page sans dépassement : ${screen.name}', (t) async {
      await show(t, (_) async => true, screen: screen);
      await t.scrollUntilVisible(
        find.text('Sources'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('le texte de l\'avertissement n\'a pas changé', (t) async {
    expect(
      safetyDisclaimer,
      'Cette identification est une aide et peut être erronée. Ne consommez '
      'jamais un champignon sur la seule base de cette application : faites-le '
      'contrôler par un pharmacien ou une association mycologique.',
    );
  });
}
