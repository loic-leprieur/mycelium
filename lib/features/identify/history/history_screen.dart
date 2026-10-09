import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/group_filter.dart';
import '../../../core/rustic.dart';
import '../../../core/theme.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import 'history_logic.dart';
import 'stored_photo.dart';

/// Historique des identifications enregistrées, avec leur photo, leur emplacement
/// et un filtre par type de champignon (« mes cèpes », « mes chanterelles »…).
class IdentificationHistoryScreen extends ConsumerStatefulWidget {
  const IdentificationHistoryScreen({super.key});

  @override
  ConsumerState<IdentificationHistoryScreen> createState() =>
      _IdentificationHistoryScreenState();
}

class _IdentificationHistoryScreenState
    extends ConsumerState<IdentificationHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Quand un type n'a plus aucune identification (suppression, espèce corrigée),
    // il quitte la sélection : on ne reste pas bloqué sur un filtre vide.
    ref.listenManual(identificationsProvider, (_, next) {
      final all = next.value;
      if (all == null) return;
      final available = historyGroupCounts(all.map((i) => i.chosenSpeciesId)).keys.toSet();
      ref.read(historyGroupFilterProvider.notifier).retain(available);
    });
  }

  @override
  Widget build(BuildContext context) {
    final identifications = ref.watch(identificationsProvider);
    final selected = ref.watch(historyGroupFilterProvider);
    final filter = ref.read(historyGroupFilterProvider.notifier);
    final spots = {
      for (final s in ref.watch(spotsProvider).value ?? const <Spot>[]) s.id: s,
    };

    final known = identifications.value;
    final shown = known == null
        ? const <Identification>[]
        : [
            for (final i in known)
              if (matchesHistoryFilter(i.chosenSpeciesId, selected)) i,
          ];
    final title = known == null || known.isEmpty
        ? 'Mes identifications'
        : selected.isEmpty
            ? 'Mes identifications (${known.length})'
            : 'Mes identifications (${shown.length} sur ${known.length})';

    return Scaffold(
      appBar: AppBar(
        // Le nombre reste lisible sur un petit écran : le titre rétrécit plutôt
        // que d'être coupé.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(title),
        ),
      ),
      body: identifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Impossible de lire l\'historique.', textAlign: TextAlign.center),
          ),
        ),
        data: (all) {
          if (all.isEmpty) {
            return const EmptyState(
              title: 'Aucune identification enregistrée',
              message: 'Identifiez un champignon puis choisissez son espèce : la photo, '
                  'la date et l\'endroit seront gardés ici, même sans réseau.',
            );
          }
          return Column(
            children: [
              const SizedBox(height: 8),
              GroupFilterBar(
                counts: historyGroupCounts(all.map((i) => i.chosenSpeciesId)),
                selected: selected,
                onToggle: filter.toggle,
                onClear: filter.clear,
              ),
              Expanded(
                child: shown.isEmpty
                    ? EmptyState(
                        title: 'Aucun résultat pour ce filtre',
                        message: 'Aucune de vos identifications ne correspond aux '
                            'types choisis.',
                        action: FilledButton(
                          onPressed: filter.clear,
                          child: const Text('Tout afficher'),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        itemCount: shown.length,
                        itemBuilder: (context, i) => _HistoryTile(
                          identification: shown[i],
                          spotName: spots[shown[i].spotId]?.name,
                        ).stagger(i),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Une identification : miniature, espèce retenue, date, coin, et ce que le
/// modèle proposait (traçabilité, RM-3).
class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.identification, required this.spotName});

  final Identification identification;
  final String? spotName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chosenId = identification.chosenSpeciesId;
    final String title;
    if (chosenId == null) {
      title = 'Espèce inconnue';
    } else {
      title = ref.watch(speciesByIdProvider(chosenId))?.commonName ?? 'Espèce supprimée';
    }

    final top = parseTop5(identification.top5Json).firstOrNull;
    final topName = top == null
        ? null
        : ref.watch(speciesByIdProvider(top.speciesId))?.commonName ?? top.speciesId;
    final muted = theme.textTheme.bodySmall?.copyWith(color: Colors.black54);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/identify/history/${identification.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              StoredPhoto(
                path: identification.photoPath,
                width: 76,
                height: 76,
                cacheWidth: 200,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(shortDateTime(identification.createdAt)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: spotName == null ? Colors.black45 : Palette.forest,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            spotName ?? 'Sans coin',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (top != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Le modèle proposait : $topName ${percentLabel(top.score)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
