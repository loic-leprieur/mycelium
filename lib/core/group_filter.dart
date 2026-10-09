import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/species/domain/species_groups.dart';

/// Sélection de types de champignons pour un filtre (vide = tout afficher).
class GroupSelection extends Notifier<Set<MushroomGroup>> {
  @override
  Set<MushroomGroup> build() => {};

  void toggle(MushroomGroup group) => state =
      state.contains(group) ? ({...state}..remove(group)) : {...state, group};

  void clear() => state = {};

  /// Retire de la sélection les types qui n'existent plus dans les données.
  void retain(Set<MushroomGroup> available) {
    final kept = state.intersection(available);
    if (kept.length != state.length) state = kept;
  }
}

/// Filtre par type de la liste et de la carte des coins.
final mapGroupFilterProvider =
    NotifierProvider<GroupSelection, Set<MushroomGroup>>(GroupSelection.new);

/// Filtre par type de l'historique des identifications.
final historyGroupFilterProvider =
    NotifierProvider<GroupSelection, Set<MushroomGroup>>(GroupSelection.new);

/// Rangée de pastilles « Tous · Cèpes (3) · Chanterelles (2) … ». N'affiche que
/// les types présents dans [counts]. Plusieurs types peuvent être cumulés.
class GroupFilterBar extends StatelessWidget {
  const GroupFilterBar({
    super.key,
    required this.counts,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  /// Nombre d'éléments (coins, identifications…) par type ; les types à 0 sont masqués.
  final Map<MushroomGroup, int> counts;
  final Set<MushroomGroup> selected;
  final ValueChanged<MushroomGroup> onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final groups = [
      for (final g in MushroomGroup.values)
        if ((counts[g] ?? 0) > 0) g,
    ];
    if (groups.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Tous'),
              selected: selected.isEmpty,
              onSelected: (_) => onClear(),
            ),
          ),
          for (final g in groups)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${g.label} (${counts[g]})'),
                selected: selected.contains(g),
                onSelected: (_) => onToggle(g),
              ),
            ),
        ],
      ),
    );
  }
}
