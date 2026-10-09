import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../species/domain/species.dart';
import '../species/domain/species_groups.dart';
import 'spot_filter.dart';
import 'spot_visits.dart';

/// Nom d'une espèce ; une espèce personnelle supprimée depuis n'est plus connue.
String _speciesName(WidgetRef ref, String speciesId) =>
    ref.watch(speciesByIdProvider(speciesId))?.commonName ?? 'Espèce supprimée';

/// « Espèces observées » dans un coin (SPOT-4) : la liste avec la date de la
/// dernière observation, le retrait d'une espèce et l'ajout depuis
/// l'encyclopédie. Les changements sont remontés au formulaire, qui les écrit
/// en base à l'enregistrement.
class SpotSpeciesSection extends ConsumerWidget {
  const SpotSpeciesSection({
    super.key,
    required this.seen,
    required this.onAdd,
    required this.onRemove,
  });

  /// Identifiant d'espèce -> date de la dernière observation.
  final Map<String, DateTime> seen;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Les plus récemment vues d'abord.
    final ids = seen.keys.toList()
      ..sort((a, b) {
        final c = seen[b]!.compareTo(seen[a]!);
        return c != 0 ? c : a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Espèces observées', style: Theme.of(context).textTheme.titleMedium),
        if (ids.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Aucune espèce notée pour ce coin. Elles s\'ajoutent aussi quand '
              'vous notez une récolte ou confirmez une identification ici.',
            ),
          ),
        for (final id in ids)
          _SeenSpeciesTile(
            speciesId: id,
            seenAt: seen[id]!,
            onRemove: () => onRemove(id),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await pickSpecies(context, exclude: seen.keys.toSet());
            if (picked != null) onAdd(picked);
          },
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une espèce'),
        ),
      ],
    );
  }
}

class _SeenSpeciesTile extends ConsumerWidget {
  const _SeenSpeciesTile({
    required this.speciesId,
    required this.seenAt,
    required this.onRemove,
  });

  final String speciesId;
  final DateTime seenAt;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = _speciesName(ref, speciesId);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        minTileHeight: 64,
        leading: const CircleAvatar(
          backgroundColor: Palette.sage,
          child: Icon(Icons.eco, color: Palette.forestDark),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('Dernière observation : ${shortDate(seenAt)}'),
        trailing: IconButton(
          tooltip: 'Retirer $name',
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

/// Fenêtre de choix d'une espèce de l'encyclopédie (catalogue et espèces
/// personnelles), hors celles de [exclude]. Renvoie son identifiant, ou null si
/// on referme sans choisir.
Future<String?> pickSpecies(BuildContext context, {required Set<String> exclude}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SpeciesPickerSheet(exclude: exclude),
    );

class _SpeciesPickerSheet extends ConsumerStatefulWidget {
  const _SpeciesPickerSheet({required this.exclude});

  final Set<String> exclude;

  @override
  ConsumerState<_SpeciesPickerSheet> createState() => _SpeciesPickerSheetState();
}

class _SpeciesPickerSheetState extends ConsumerState<_SpeciesPickerSheet> {
  String _query = '';

  bool _matches(Species s, String folded) =>
      !widget.exclude.contains(s.id) &&
      (folded.isEmpty ||
          foldText(s.commonName).contains(folded) ||
          foldText(s.scientificName ?? '').contains(folded));

  @override
  Widget build(BuildContext context) {
    final folded = foldText(_query);
    final species = [
      for (final s in ref.watch(allSpeciesProvider).value ?? const <Species>[])
        if (_matches(s, folded)) s,
    ]..sort((a, b) => foldText(a.commonName).compareTo(foldText(b.commonName)));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Quelle espèce avez-vous vue ?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Rechercher un champignon…',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: species.isEmpty
                  ? const Center(child: Text('Aucune espèce trouvée.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: species.length,
                      itemBuilder: (context, i) => ListTile(
                        minTileHeight: 60,
                        title: Text(
                          species[i].commonName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(groupOfSpecies(species[i].id).label),
                        onTap: () => Navigator.of(context).pop(species[i].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sorties faites à ce coin (SPOT-5) : dernière visite, puis la liste des
/// sorties, de la plus récente à la plus ancienne, avec le résumé de leurs
/// récoltes. Un appui ouvre la sortie dans le carnet.
class SpotVisitsSection extends ConsumerStatefulWidget {
  const SpotVisitsSection({super.key, required this.spotId});

  final String spotId;

  @override
  ConsumerState<SpotVisitsSection> createState() => _SpotVisitsSectionState();
}

class _SpotVisitsSectionState extends ConsumerState<SpotVisitsSection> {
  /// Nombre de sorties montrées avant « Voir les autres » : le bouton
  /// d'enregistrement du formulaire reste ainsi à portée de main.
  static const _collapsedCount = 5;

  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final outings = ref.watch(outingsProvider).value;
    final visits = [
      for (final o in outings ?? const <Outing>[])
        if (o.spotId == widget.spotId) o,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final shown = _showAll ? visits : visits.take(_collapsedCount).toList();
    final hidden = visits.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sorties à ce coin', style: Theme.of(context).textTheme.titleMedium),
        // Rien tant que le carnet n'est pas lu : pas de « Jamais visité » à tort.
        if (outings != null) ...[
          const SizedBox(height: 4),
          Text(visitLabel(visits.isEmpty ? null : visits.first.startedAt)),
        ],
        if (outings != null && visits.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Aucune sortie enregistrée pour ce coin. Créez-en une depuis le '
              'Carnet en choisissant ce coin.',
            ),
          ),
        const SizedBox(height: 6),
        for (final outing in shown) _VisitTile(outing: outing),
        if (hidden > 0)
          TextButton(
            onPressed: () => setState(() => _showAll = true),
            child: Text(hidden == 1 ? "Voir l'autre sortie" : 'Voir les $hidden autres sorties'),
          ),
      ],
    );
  }
}

class _VisitTile extends ConsumerWidget {
  const _VisitTile({required this.outing});

  final Outing outing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final harvests = ref.watch(harvestsProvider(outing.id)).value;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        minTileHeight: 64,
        leading: const CircleAvatar(
          backgroundColor: Palette.sage,
          child: Icon(Icons.forest, color: Palette.forestDark),
        ),
        title: Text(
          DateFormat.yMMMMEEEEd('fr').format(outing.startedAt),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: harvests == null
            ? null
            : Text(harvestSummary(harvests, (id) => _speciesName(ref, id))),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/journal/${outing.id}'),
      ),
    );
  }
}
