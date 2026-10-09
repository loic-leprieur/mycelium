import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/photo_store.dart';

/// Photo enregistrée en base ([path] : chemin relatif, ou ancien chemin absolu).
///
/// Le fichier est cherché une seule fois (pas à chaque reconstruction de la
/// liste). S'il a disparu ou ne peut pas être lu, un repli propre s'affiche à la
/// place : l'identification reste consultable sans sa photo.
class StoredPhoto extends StatefulWidget {
  const StoredPhoto({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.cacheWidth,
    this.radius = 14,
    this.zoomable = false,
    this.missingMessage,
  });

  final String path;
  final double? width;
  final double? height;

  /// Largeur de décodage : une miniature n'a pas besoin de la photo en pleine
  /// définition (économise la mémoire dans une longue liste).
  final int? cacheWidth;
  final double radius;

  /// Un appui ouvre la photo en grand, que l'on peut agrandir au doigt.
  final bool zoomable;

  /// Texte affiché quand la photo est introuvable (sinon, une icône seule).
  final String? missingMessage;

  @override
  State<StoredPhoto> createState() => _StoredPhotoState();
}

class _StoredPhotoState extends State<StoredPhoto> {
  late Future<File?> _file = resolveStoredPhoto(widget.path);

  @override
  void didUpdateWidget(StoredPhoto old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _file = resolveStoredPhoto(widget.path);
  }

  Widget _frame(Widget child) => SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRRect(borderRadius: BorderRadius.circular(widget.radius), child: child),
      );

  Widget _missing() => _frame(
        ColoredBox(
          color: Palette.sage.withValues(alpha: .5),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image_not_supported_outlined, color: Palette.bark),
                  if (widget.missingMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(widget.missingMessage!, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<File?>(
        future: _file,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _frame(ColoredBox(color: Palette.sage.withValues(alpha: .35)));
          }
          final file = snapshot.data;
          if (file == null) return _missing();
          final image = Image.file(
            file,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
            cacheWidth: widget.cacheWidth,
            gaplessPlayback: true,
            semanticLabel: 'Photo du champignon',
            errorBuilder: (_, _, _) => _missing(),
          );
          final framed = _frame(image);
          if (!widget.zoomable) return framed;
          return GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                insetPadding: const EdgeInsets.all(12),
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(child: Image.file(file)),
              ),
            ),
            child: framed,
          );
        },
      );
}
