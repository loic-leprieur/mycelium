import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'bioclip_identifier.dart';
import 'identifier.dart';

/// Moteur d'identification réel de cette version de l'application.
///
/// - `null` : le modèle n'est pas embarqué => mode démonstration seulement ;
/// - une erreur : le modèle est là mais n'a pas pu démarrer (affichée à l'écran,
///   jamais remplacée par de faux résultats) ;
/// - sinon le moteur BioCLIP, chargé une fois.
final identifierProvider = FutureProvider<Identifier?>((ref) async {
  if (!await BioClipIdentifier.isBundled()) return null;
  final engine = await BioClipIdentifier.load();
  ref.onDispose(engine.dispose);
  return engine;
});

/// Choix d'une photo (appareil photo ou galerie) : renvoie son chemin, ou null
/// si l'utilisateur annule. Remplaçable dans les tests, où aucune fenêtre
/// système ne peut s'ouvrir.
typedef PhotoPicker = Future<String?> Function(ImageSource source);

final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => (source) async {
    // Photo réduite à 1600 px : suffisante pour le modèle (224 px) et rapide à décoder.
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 92,
    );
    return file?.path;
  },
);
