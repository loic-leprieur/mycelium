import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/safety_widgets.dart';
import '../../../core/theme.dart';
import '../../../data/providers.dart';
import '../identifier.dart';
import 'quality_dialog.dart';
import 'season.dart';

/// Remarques sur la photo et le contexte, sous les propositions du résultat
/// (ID-6, ID-7, ID-8). Elles informent seulement : aucune ne modifie un score
/// ni une alerte de sécurité.
class AnalysisNotes extends ConsumerWidget {
  const AnalysisNotes({super.key, required this.outcome});

  final IdentificationOutcome outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (outcome.isDemo) return const SizedBox.shrink();
    final notes = <Widget>[];

    final quality = outcome.quality;
    if (quality != null && quality.hasIssues) {
      notes.add(InfoBanner(
        title: 'Qualité de la photo',
        message: '${quality.issues.map(qualityIssueLabel).join(', ')}. Le '
            'résultat est moins fiable : refaites la photo si possible.',
        color: Palette.sage,
        icon: Icons.photo_camera_back_outlined,
      ));
    }

    if (outcome.photoCount > 1) {
      notes.add(InfoBanner(
        title: 'Résultat combiné de ${outcome.photoCount} photos',
        message: 'Plusieurs photos aident l\'analyse mais ne garantissent rien : '
            'la prudence reste la même.',
        color: Palette.sage,
        icon: Icons.collections_outlined,
      ));
    }

    // Alerte levée par une photo seule, absente du résultat combiné : on explique
    // pourquoi elle reste affichée.
    final listed = {for (final c in outcome.candidates) c.speciesId};
    final alertOnly = [
      for (final id in outcome.dangerousSpeciesIds)
        if (!listed.contains(id)) id,
    ];
    if (alertOnly.isNotEmpty) {
      final names = [
        for (final id in alertOnly) ref.watch(speciesByIdProvider(id))?.commonName ?? id,
      ];
      notes.add(InfoBanner(
        title: 'Alerte conservée',
        message: 'Une des photos évoque : ${names.join(', ')}. L\'alerte reste '
            'affichée même si les autres photos ne la confirment pas.',
        color: const Color(0xFFFFCDD2),
        icon: Icons.warning_amber_rounded,
      ));
    }

    final month = outcome.seasonMonth;
    if (month != null) {
      final out = outOfSeasonCandidates(
        outcome.candidates,
        month,
        (id) => ref.watch(speciesByIdProvider(id)),
      );
      if (out.isNotEmpty) {
        final list = out
            .map((s) => s.seasonLabel == null
                ? s.commonName
                : '${s.commonName} (${s.seasonLabel})')
            .join(', ');
        notes.add(InfoBanner(
          title: 'Saison',
          message: 'En ${frenchMonths[month - 1]}, hors saison habituelle pour : '
              '$list. Un champignon peut pousser hors saison : cette remarque '
              'ne change ni les scores ni les alertes.',
          color: Palette.sage,
          icon: Icons.event_outlined,
        ));
      }
    }

    if (notes.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final n in notes)
          Padding(padding: const EdgeInsets.only(top: 10), child: n),
      ],
    );
  }
}
