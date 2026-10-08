import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/router.dart';
import 'core/theme.dart';

class MyceliumApp extends StatelessWidget {
  const MyceliumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mycelium',
      theme: buildTheme(),
      routerConfig: router,
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
