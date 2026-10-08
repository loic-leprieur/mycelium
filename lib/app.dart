import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/router.dart';
import 'core/theme.dart';

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
      // Lisible en plein soleil : texte 10 % plus grand que le réglage du système.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final systemScale = media.textScaler.scale(14) / 14;
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(systemScale * 1.1)),
          child: child!,
        );
      },
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
