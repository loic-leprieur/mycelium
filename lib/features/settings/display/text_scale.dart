import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';

/// Clé de `appMeta` où la taille du texte est conservée.
const textScaleMetaKey = 'text_scale';

/// Taille du texte choisie dans Réglages > Affichage. Elle se MULTIPLIE au
/// réglage de texte du téléphone. « Normal » reproduit le comportement d'origine
/// de l'application (texte 10 % plus grand que le système).
enum TextScaleLevel {
  normal('normal', 'Normal', 1.1),
  large('large', 'Grand', 1.3),
  extraLarge('xlarge', 'Très grand', 1.5);

  const TextScaleLevel(this.storageValue, this.label, this.factor);

  /// Valeur écrite dans `appMeta` (et donc dans les sauvegardes).
  final String storageValue;
  final String label;
  final double factor;

  /// Relit une valeur enregistrée ; toute valeur inconnue ou absente donne [normal].
  static TextScaleLevel fromStorage(String? value) => TextScaleLevel.values
      .firstWhere((l) => l.storageValue == value, orElse: () => TextScaleLevel.normal);
}

/// Échelle de texte de l'application : celle du système × celle du niveau choisi.
TextScaler appTextScaler(TextScaler system, TextScaleLevel level) =>
    TextScaler.linear(system.scale(14) / 14 * level.factor);

/// Niveau de texte choisi, lu puis enregistré dans la base. Après une
/// restauration ou un effacement des données : `ref.invalidate(textScaleProvider)`.
class TextScaleController extends AsyncNotifier<TextScaleLevel> {
  @override
  Future<TextScaleLevel> build() async => TextScaleLevel.fromStorage(
        await ref.watch(databaseProvider).metaValue(textScaleMetaKey),
      );

  Future<void> choose(TextScaleLevel level) async {
    // Attend la fin de la lecture initiale : elle ne doit pas écraser ce choix.
    await future.then<void>((_) {}, onError: (Object _) {});
    state = AsyncData(level);
    await ref.read(databaseProvider).setMeta(textScaleMetaKey, level.storageValue);
  }
}

final textScaleProvider =
    AsyncNotifierProvider<TextScaleController, TextScaleLevel>(TextScaleController.new);
