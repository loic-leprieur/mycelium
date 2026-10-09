import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/group_filter.dart';
import '../../../core/rustic.dart';
import '../../../data/providers.dart';
import '../domain/species.dart';
import '../domain/species_groups.dart';
import 'danger_badge.dart';
import 'deadly_section.dart';
import 'filters/filters_panel.dart';
import 'filters/habitat_families.dart';
import 'filters/species_filters.dart';

/// Horloge de l'encyclopédie, pour « En saison ce mois-ci ». Remplaçable dans les tests.
final speciesClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Types de champignons cochés dans l'encyclopédie. Sélection propre à cet écran
/// (elle disparaît avec lui) : elle ne se mélange pas à celles de la carte et de
/// l'historique.
final speciesGroupFilterProvider =
    NotifierProvider.autoDispose<GroupSelection, Set<MushroomGroup>>(GroupSelection.new);

class SpeciesListScreen extends ConsumerStatefulWidget {
  const SpeciesListScreen({super.key});

  @override
  ConsumerState<SpeciesListScreen> createState() => _SpeciesListScreenState();
}

class _SpeciesListScreenState extends ConsumerState<SpeciesListScreen> {
  /// Critères en cours, hors types (ceux-ci sont dans [speciesGroupFilterProvider]).
  SpeciesFilters _filters = const SpeciesFilters();
  bool _panelOpen = false;
  bool _deadlyOpen = true;

  void _update(SpeciesFilters next) => setState(() => _filters = next);

  /// Retire tous les critères ; la recherche par nom est conservée.
  void _reset() {
    ref.read(speciesGroupFilterProvider.notifier).clear();
    _update(SpeciesFilters(query: _filters.query));
  }

  @override
  Widget build(BuildContext context) {
    final species = ref.watch(allSpeciesProvider);
    final filters = _filters.copyWith(groups: ref.watch(speciesGroupFilterProvider));
    return Scaffold(
      appBar: AppBar(title: const Text('Espèces')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/species/add'),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Ajouter une espèce'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher un champignon…',
              ),
              onChanged: (v) => _update(_filters.copyWith(query: v)),
            ),
          ),
          Expanded(
            child: species.when(
              data: (all) => _buildList(all, filters),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Species> all, SpeciesFilters filters) {
    final selection = ref.read(speciesGroupFilterProvider.notifier);
    final outcome = applyFilters(all, filters);
    final shown = sortedByName(outcome.shown);
    // La rubrique des espèces mortelles ne s'affiche que sur la liste complète.
    final deadly = filters.isNarrowed
        ? const <Species>[]
        : sortedByName(all.where((s) => !s.isCustom && s.edibility == Edibility.deadly));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SpeciesFiltersPanel(
            filters: filters,
            currentMonth: ref.watch(speciesClockProvider)().month,
            groupTotals: groupCounts(all),
            habitatTotals: habitatCounts(all),
            expanded: _panelOpen,
            onExpansionChanged: (open) => _panelOpen = open,
            onToggleEdibility: (e) =>
                _update(_filters.copyWith(edibilities: toggled(_filters.edibilities, e))),
            onMonth: (month) => _update(
              month == null ? _filters.copyWith(clearMonth: true) : _filters.copyWith(month: month),
            ),
            onToggleHabitat: (h) =>
                _update(_filters.copyWith(habitats: toggled(_filters.habitats, h))),
            onToggleGroup: selection.toggle,
            onClearGroups: selection.clear,
          ),
        ),
        if (filters.hasCriteria)
          SliverToBoxAdapter(
            child: _ResultsBar(shown: shown.length, total: all.length, onReset: _reset),
          ),
        if (outcome.unknown > 0)
          SliverToBoxAdapter(
            child: _UnknownNotice(
              count: outcome.unknown,
              included: filters.includeUnknown,
              onToggle: () =>
                  _update(_filters.copyWith(includeUnknown: !_filters.includeUnknown)),
            ),
          ),
        if (deadly.isNotEmpty)
          SliverToBoxAdapter(
            child: DeadlySection(
              species: deadly,
              expanded: _deadlyOpen,
              onExpansionChanged: (open) => _deadlyOpen = open,
            ),
          ),
        if (shown.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              title: 'Aucune espèce ne correspond',
              message: filters.hasCriteria
                  ? 'Modifiez la recherche ou réinitialisez les filtres.'
                  : 'Essayez un autre nom.',
            ),
          )
        else
          SliverList.builder(
            itemCount: shown.length,
            itemBuilder: (context, i) => KeyedSubtree(
              key: ValueKey(shown[i].id),
              child: _SpeciesTile(species: shown[i]).stagger(i),
            ),
          ),
        // Dégage le dernier élément du bouton « Ajouter une espèce ».
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

/// « 12 espèces sur 22 » et le bouton qui retire tous les critères.
class _ResultsBar extends StatelessWidget {
  const _ResultsBar({required this.shown, required this.total, required this.onReset});

  final int shown;
  final int total;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 8, 0),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(
              '$shown ${shown <= 1 ? 'espèce' : 'espèces'} sur $total',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Réinitialiser les filtres'),
            ),
          ],
        ),
      );
}

/// Les fiches sans habitat ou sans saison ne peuvent pas être comparées à ces
/// critères : on le dit, au lieu de les faire disparaître sans un mot.
class _UnknownNotice extends StatelessWidget {
  const _UnknownNotice({required this.count, required this.included, required this.onToggle});

  final int count;
  final bool included;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final one = count == 1;
    final cards = one
        ? '1 fiche sans information d\'habitat ou de saison'
        : '$count fiches sans information d\'habitat ou de saison';
    final state = included
        ? (one ? 'est affichée malgré ces filtres.' : 'sont affichées malgré ces filtres.')
        : (one ? 'est masquée par ces filtres.' : 'sont masquées par ces filtres.');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('$cards $state')),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onToggle,
                child: Text(included ? 'Masquer' : 'Afficher'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeciesTile extends StatelessWidget {
  const _SpeciesTile({required this.species});

  final Species species;

  @override
  Widget build(BuildContext context) {
    final photo = species.photoPath;
    const latinStyle = TextStyle(fontStyle: FontStyle.italic, fontSize: 13);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minTileHeight: 72,
        leading: Hero(
          tag: 'species-${species.id}',
          child: photo != null && File(photo).existsSync()
              ? CircleAvatar(radius: 26, backgroundImage: FileImage(File(photo)))
              : CircleAvatar(
                  radius: 26,
                  backgroundColor: species.edibility.color.withValues(alpha: 0.16),
                  child: Icon(species.edibility.icon, color: species.edibility.color),
                ),
        ),
        title: Text(species.commonName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: species.isCustom
            ? const Text('Fiche personnelle, non vérifiée')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (species.scientificName != null)
                    Text(species.scientificName!, style: latinStyle),
                  // Toute espèce toxique ou mortelle porte sa pastille d'avertissement.
                  if (species.edibility.isDangerous)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: DangerBadge(edibility: species.edibility),
                    )
                  else
                    Text(species.edibility.label, style: latinStyle),
                ],
              ),
        isThreeLine: !species.isCustom,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/species/${species.id}'),
      ),
    );
  }
}
