import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'text_scale.dart';

/// Réglages > Affichage : taille du texte (cahier des charges §6).
class DisplayScreen extends ConsumerWidget {
  const DisplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(textScaleProvider).value ?? TextScaleLevel.normal;
    // Échelle du système seule : chaque choix montre un exemple à sa vraie taille.
    final system = MediaQuery.textScalerOf(context).scale(14) / 14 / current.factor;
    return Scaffold(
      appBar: AppBar(title: const Text('Affichage')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Taille du texte', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'Choisissez la taille la plus confortable à lire. Elle s\'ajoute au '
            'réglage de texte de votre téléphone.',
          ),
          const SizedBox(height: 10),
          RadioGroup<TextScaleLevel>(
            groupValue: current,
            onChanged: (level) {
              if (level != null) ref.read(textScaleProvider.notifier).choose(level);
            },
            child: Column(
              children: [
                for (final level in TextScaleLevel.values)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: RadioListTile<TextScaleLevel>(
                      value: level,
                      title: Text(
                        level.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Cèpe de Bordeaux',
                        textScaler: TextScaler.linear(system * level.factor),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
