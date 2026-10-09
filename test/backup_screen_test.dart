import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mycelium/core/theme.dart';
import 'package:mycelium/data/backup/backup_format.dart';
import 'package:mycelium/data/backup/backup_providers.dart';
import 'package:mycelium/data/backup/backup_system.dart';
import 'package:mycelium/data/providers.dart';
import 'package:mycelium/features/settings/data/data_screen.dart';

import 'backup_support.dart';
import 'support/harness.dart';

/// Système simulé : aucune feuille de partage ni fenêtre de fichier réelle.
class FakeSystem extends BackupSystem {
  FakeSystem(this.docs, this.work);

  final Directory docs;
  final Directory work;
  BackupDelivery outcome = BackupDelivery.shared;
  File? toPick;
  final delivered = <String>[];

  @override
  Future<Directory> photosDirectory() async => docs;

  @override
  Future<Directory> workDirectory() async => work;

  @override
  Future<BackupDelivery> deliver(File archive, {Rect? origin}) async {
    delivered.add(archive.path);
    return outcome;
  }

  @override
  Future<File?> pickArchive() async => toPick;
}

final _now = DateTime(2026, 10, 9, 12);

void main() {
  late Install app;
  late FakeSystem system;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await loadTestFonts();
  });

  /// Les lectures de base et de fichiers sont réelles : elles passent par
  /// `runAsync`, y compris la création et le nettoyage de l'installation.
  void widgetTest(String name, Future<void> Function(WidgetTester t) body) {
    testWidgets(name, (t) async {
      app = (await t.runAsync(Install.create))!;
      app.use();
      system = FakeSystem(app.docs, app.work);
      try {
        await body(t);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        await t.runAsync(app.dispose);
      }
    });
  }

  Future<void> pumpUntil(WidgetTester t, Finder finder, {int tries = 150}) async {
    for (var i = 0; i < tries && finder.evaluate().isEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> open(WidgetTester t) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    applyScreen(t, const ScreenCase('haut', 412, 1500));
    final router = GoRouter(initialLocation: '/settings/data', routes: [
      GoRoute(path: '/settings/data', builder: (_, _) => const DataScreen()),
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Text('ACCUEIL'))),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) => app.db),
        backupSystemProvider.overrideWithValue(system),
        backupClockProvider.overrideWithValue(() => _now),
      ],
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
    ));
    await settle(t);
  }

  widgetTest('jamais sauvegardé : alerte affichée', (t) async {
    await open(t);
    expect(find.text('Dernière sauvegarde : jamais'), findsOneWidget);
    expect(find.text('Pensez à sauvegarder'), findsOneWidget);
    expect(find.textContaining('VOS COINS ET VOS POSITIONS GPS'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Créer une sauvegarde'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Restaurer une sauvegarde'), findsOneWidget);
    expect(find.text('Supprimer toutes mes données'), findsWidgets);
  });

  widgetTest('sauvegarde récente : date affichée, pas d\'alerte ; ancienne : alerte', (t) async {
    await t.runAsync(() => app.service().markBackupDone(DateTime(2026, 10, 7, 9)));
    await open(t);
    expect(find.textContaining('7 octobre 2026'), findsOneWidget);
    expect(find.textContaining('il y a 2 jours'), findsOneWidget);
    expect(find.text('Pensez à sauvegarder'), findsNothing);

    await t.runAsync(() => app.service().markBackupDone(DateTime(2026, 10, 1)));
    await settle(t);
    expect(find.text('Pensez à sauvegarder'), findsOneWidget);
  });

  widgetTest('créer une sauvegarde : avertissement, partage, date enregistrée', (t) async {
    await t.runAsync(() => seed(app));
    await open(t);
    await t.tap(find.widgetWithText(FilledButton, 'Créer une sauvegarde'));
    await settle(t);
    expect(find.textContaining('Ne le partagez avec personne'), findsOneWidget);
    await t.tap(find.text('Continuer'));
    await pumpUntil(t, find.text('Sauvegarde terminée'));
    expect(system.delivered, hasLength(1));
    expect(system.delivered.single, endsWith('mycelium-sauvegarde-2026-10-09.zip'));
    expect(find.textContaining('2 coins'), findsWidgets);
    await t.tap(find.text('OK'));
    await settle(t);
    expect(find.text('Pensez à sauvegarder'), findsNothing);
    expect(await t.runAsync(() => app.service().lastBackupAt()), isNotNull);
  });

  widgetTest('partage fermé sans rien choisir : aucune sauvegarde comptée', (t) async {
    system.outcome = BackupDelivery.cancelled;
    await open(t);
    await t.tap(find.widgetWithText(FilledButton, 'Créer une sauvegarde'));
    await settle(t);
    await t.tap(find.text('Continuer'));
    await pumpUntil(t, find.text('Sauvegarde non enregistrée'));
    expect(await t.runAsync(() => app.service().lastBackupAt()), isNull);
    expect(system.work.existsSync() ? system.work.listSync() : [], isEmpty);
  });

  group('restauration', () {
    /// Archive d'un autre appareil, créée dans [archiveDir].
    Future<File> makeArchive(WidgetTester t) async {
      final source = (await t.runAsync(Install.create))!;
      source.use();
      final file = await t.runAsync(() async {
        await seed(source);
        return (await source.service().createArchive(outputDir: source.work, now: _now)).file;
      });
      final copy = await t.runAsync(() => file!.copy('${app.work.path}/source.zip'));
      await t.runAsync(source.dispose);
      app.use();
      return copy!;
    }

    widgetTest('fusion par défaut : récapitulatif puis données ajoutées', (t) async {
      system.toPick = await makeArchive(t);
      await open(t);
      await t.tap(find.widgetWithText(OutlinedButton, 'Restaurer une sauvegarde'));
      await pumpUntil(t, find.text('Restaurer cette sauvegarde ?'));
      expect(find.text('2 coins, 1 sortie, 3 récoltes, 1 identification, 1 espèce personnelle, 5 photos'), findsOneWidget);
      expect(find.text('Fusionner'), findsOneWidget);
      expect(find.text('Remplacer tout'), findsOneWidget);
      await t.tap(find.text('Restaurer'));
      await pumpUntil(t, find.text('Restauration terminée'));
      expect(find.textContaining('Ajouté'), findsOneWidget);
      final spots = await t.runAsync(() => app.db.select(app.db.spots).get());
      expect(spots, hasLength(2));
      expect(app.photo('harvest_photos/h3.jpg').existsSync(), isTrue);
    });

    widgetTest('remplacer tout demande une seconde confirmation', (t) async {
      system.toPick = await makeArchive(t);
      await t.runAsync(() => seed(app));
      await open(t);
      await t.tap(find.widgetWithText(OutlinedButton, 'Restaurer une sauvegarde'));
      await pumpUntil(t, find.text('Restaurer cette sauvegarde ?'));
      await t.tap(find.text('Remplacer tout'));
      await t.pump();
      await t.tap(find.text('Restaurer'));
      await settle(t);
      expect(find.text('Tout remplacer ?'), findsOneWidget);
      await t.tap(find.text('Annuler'));
      await settle(t);
      expect(find.text('Restauration terminée'), findsNothing);
    });

    widgetTest('fichier invalide : message d\'erreur lisible', (t) async {
      system.toPick = File('${app.work.path}/nimporte.zip')..writeAsBytesSync(bytesOf(1, 3000));
      await open(t);
      await t.tap(find.widgetWithText(OutlinedButton, 'Restaurer une sauvegarde'));
      await pumpUntil(t, find.text('Cette sauvegarde ne peut pas être restaurée'));
      expect(find.textContaining('n\'est pas une sauvegarde Mycelium'), findsOneWidget);
    });

    widgetTest('sélection annulée : rien ne se passe', (t) async {
      await open(t);
      await t.tap(find.widgetWithText(OutlinedButton, 'Restaurer une sauvegarde'));
      await settle(t);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  widgetTest('supprimer : double confirmation avec le mot SUPPRIMER, puis retour à l\'accueil', (t) async {
    await t.runAsync(() => seed(app));
    await open(t);
    await t.tap(find.widgetWithText(OutlinedButton, 'Supprimer toutes mes données'));
    await settle(t);
    expect(find.text('Supprimer toutes vos données ?'), findsOneWidget);
    await t.tap(find.text('Continuer'));
    await settle(t);

    final confirm = find.widgetWithText(FilledButton, 'Tout supprimer');
    expect(t.widget<FilledButton>(confirm).onPressed, isNull);
    await t.enterText(find.byType(TextField), 'supp');
    await t.pump();
    expect(t.widget<FilledButton>(confirm).onPressed, isNull);
    await t.enterText(find.byType(TextField), 'SUPPRIMER');
    await t.pump();
    expect(t.widget<FilledButton>(confirm).onPressed, isNotNull);
    await t.tap(confirm);
    await pumpUntil(t, find.text('ACCUEIL'));

    final left = await t.runAsync(() => tables(app.db));
    for (final e in left!.entries) {
      expect(e.value, isEmpty, reason: e.key);
    }
    expect(Directory('${app.docs.path}/harvest_photos').existsSync(), isFalse);
    expect(photoFolders, hasLength(3));
  });

  widgetTest('supprimer : annuler à la première étape ne change rien', (t) async {
    await t.runAsync(() => seed(app));
    await open(t);
    await t.tap(find.widgetWithText(OutlinedButton, 'Supprimer toutes mes données'));
    await settle(t);
    await t.tap(find.text('Annuler'));
    await settle(t);
    expect(await t.runAsync(() => app.db.select(app.db.spots).get()), hasLength(2));
  });
}
