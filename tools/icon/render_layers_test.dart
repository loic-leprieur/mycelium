// Rend les deux calques de l'icône de l'application (1024×1024) à partir du
// champignon dessiné dans le code (`MorelLogo`, le même que l'écran d'accueil) :
//
//   flutter test tools/icon/render_layers_test.dart
//
// puis `python3 tools/icon/make_icons.py` génère toutes les tailles de toutes
// les plateformes. Hors du dossier `test/` : ne tourne pas avec `flutter test`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycelium/core/rustic.dart';
import 'package:mycelium/core/theme.dart';

const _canvas = 1024.0;

/// Taille du champignon dans l'icône (part du côté) : il reste dans la zone
/// sûre des icônes adaptatives et des icônes « maskable ».
const _logoSize = 680.0;

void main() {
  testWidgets("rend les calques de l'icône", (tester) async {
    tester.view.physicalSize = const Size(_canvas, _canvas);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final out = Directory('tools/icon/layers')..createSync(recursive: true);

    Future<void> render(Widget child, String name) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: SizedBox(width: _canvas, height: _canvas, child: child),
          ),
        ),
      );
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    // Fond : le dégradé de l'écran d'accueil.
    await render(
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Palette.forestDark, Palette.forest, Palette.moss],
          ),
        ),
      ),
      'background',
    );

    // Premier plan : le champignon seul, sur fond transparent.
    await render(
      const Center(child: MorelLogo(size: _logoSize)),
      'foreground',
    );
  });
}
