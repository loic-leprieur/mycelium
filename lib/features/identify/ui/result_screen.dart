import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/safety_widgets.dart';
import '../../../data/providers.dart';
import '../identifier.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.outcome});

  final IdentificationOutcome outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Résultat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (outcome.isDemo)
            InfoBanner(
              title: 'DÉMONSTRATION — résultat fictif',
              message: outcome.scenarioLabel ?? '',
              color: const Color(0xFFFFB74D),
            ),
          if (outcome.dangerousSpeciesIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoBanner(
              title: 'ATTENTION : espèce dangereuse parmi les candidats',
              message: _dangerNames(ref),
              color: const Color(0xFFC62828),
              icon: Icons.dangerous,
            ),
          ],
          const SizedBox(height: 16),
          if (outcome.isInsufficient)
            const InfoBanner(
              title: 'Identification insuffisante',
              message:
                  'Les propositions sont trop incertaines ou trop proches. Aucune '
                  'espèce ne peut être retenue. Photographiez le chapeau, le dessous, '
                  'le pied et la base, puis faites contrôler le champignon.',
              color: Color(0xFFE0E0E0),
              icon: Icons.help_outline,
            )
          else
            Text('Identification probable', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < outcome.candidates.length; i++)
            _CandidateTile(
              rank: i + 1,
              candidate: outcome.candidates[i],
              muted: outcome.isInsufficient,
            ),
          const SizedBox(height: 16),
          const SafetyDisclaimer(),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  String _dangerNames(WidgetRef ref) {
    final names = [
      for (final id in outcome.dangerousSpeciesIds)
        ref.read(speciesByIdProvider(id))?.commonName ?? id,
    ];
    return '${names.join(', ')}. Ne cueillez ni ne consommez ce champignon '
        'en cas de doute.';
  }
}

class _CandidateTile extends ConsumerWidget {
  const _CandidateTile({
    required this.rank,
    required this.candidate,
    required this.muted,
  });

  final int rank;
  final Candidate candidate;
  final bool muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final species = ref.watch(speciesByIdProvider(candidate.speciesId));
    final pct = (candidate.score * 100).round();
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: species?.edibility.color.withValues(alpha: 0.15),
          child: Text('$rank'),
        ),
        title: Text(species?.commonName ?? candidate.speciesId),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (species?.scientificName != null)
              Text(
                species!.scientificName!,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: candidate.score),
          ],
        ),
        trailing: Text(
          '$pct %',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: muted ? Colors.grey : null,
              ),
        ),
        onTap: species == null
            ? null
            : () => context.push('/species/${species.id}'),
      ),
    );
  }
}
