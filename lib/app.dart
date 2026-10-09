import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'features/map/haptics.dart';
import 'features/settings/display/text_scale.dart';

class MyceliumApp extends StatefulWidget {
  /// [router] permet aux tests de démarrer sur un écran précis.
  const MyceliumApp({super.key, this.router});

  final GoRouter? router;

  @override
  State<MyceliumApp> createState() => _MyceliumAppState();
}

class _MyceliumAppState extends State<MyceliumApp> {
  late final GoRouter _router = widget.router ?? buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mycelium',
      theme: buildTheme(),
      routerConfig: _router,
      builder: (context, child) => _TextScaleHost(child: _HapticsHost(child: child!)),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

/// Applique la taille de texte choisie (Réglages > Affichage). « Normal » =
/// texte 10 % plus grand que le réglage du système, lisible en plein soleil.
class _TextScaleHost extends ConsumerWidget {
  const _TextScaleHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(textScaleProvider).value ?? TextScaleLevel.normal;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: appTextScaler(media.textScaler, level)),
      child: child,
    );
  }
}

/// Maintient en vie les vibrations de guidage tant que l'application tourne,
/// quel que soit l'onglet affiché.
class _HapticsHost extends ConsumerWidget {
  const _HapticsHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(guidanceHapticsProvider);
    return child;
  }
}
