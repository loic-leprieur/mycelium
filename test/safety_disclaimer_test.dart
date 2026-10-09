import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mycelium/core/safety_widgets.dart';
import 'package:mycelium/core/theme.dart';
import 'package:mycelium/features/safety/consent_screen.dart';
import 'package:mycelium/features/safety/safety_screen.dart';

import 'support/flows.dart';
import 'support/harness.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await loadTestFonts();
  });

  testWidgets("l'avertissement garde son texte et ouvre la page intoxication", (
    t,
  ) async {
    applyScreen(t, screenCases[0]);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: Center(child: SafetyDisclaimer())),
        ),
        GoRoute(
          path: '/settings/safety',
          builder: (_, _) => const SafetyScreen(),
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: buildTheme(),
          routerConfig: router,
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await settle(t);

    expect(find.text(safetyDisclaimer), findsOneWidget);
    expect(
      t.getSize(find.text("En cas d'intoxication")).height,
      greaterThan(0),
    );
    expect(t.getSize(find.byType(TextButton)).height, greaterThanOrEqualTo(48));

    await t.tap(find.text("En cas d'intoxication"));
    await settle(t);
    expect(
      find.text('En cas de symptômes, appelez le 15 (SAMU) ou le 112'),
      findsOneWidget,
    );

    await goBack(t);
    expect(find.text(safetyDisclaimer), findsOneWidget);
  });

  testWidgets("depuis l'onglet Identifier de l'application", (t) async {
    applyScreen(t, screenCases[1]);
    final app = TestApp();
    try {
      await t.pumpWidget(app.widget);
      await tapTab(t, 'Identifier');
      await tapRevealed(
        t,
        find.text("En cas d'intoxication"),
        inside: find.byType(ListView).last,
      );
      expect(find.text('Intoxication : que faire ?'), findsOneWidget);
      await goBack(t);
      expect(find.text("En cas d'intoxication"), findsOneWidget);
    } finally {
      await app.dispose(t);
    }
  });

  for (final screen in screenCases) {
    testWidgets('consentement lisible sans dépassement : ${screen.name}', (
      t,
    ) async {
      applyScreen(t, screen);
      await t.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildTheme(),
            locale: const Locale('fr'),
            supportedLocales: const [Locale('fr')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const ConsentScreen(),
          ),
        ),
      );
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.text('Avant de commencer'), findsOneWidget);
      expect(
        t.getRect(find.byType(FilledButton)).bottom,
        lessThanOrEqualTo(screen.height),
      );
      expect(
        t.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
    });
  }
}
