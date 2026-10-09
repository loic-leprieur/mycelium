import 'package:flutter/material.dart';

import '../../../../core/group_filter.dart';
import '../../domain/species.dart';
import '../../domain/species_groups.dart';
import 'habitat_families.dart';
import 'season.dart';
import 'species_filters.dart';

/// Panneau « Filtres » de l'encyclopédie : comestibilité, saison, habitat et type.
/// Replié par défaut pour laisser la place à la liste sur un petit écran ; son
/// sous-titre rappelle les critères en cours.
class SpeciesFiltersPanel extends StatelessWidget {
  const SpeciesFiltersPanel({
    super.key,
    required this.filters,
    required this.currentMonth,
    required this.groupTotals,
    required this.habitatTotals,
    required this.expanded,
    required this.onExpansionChanged,
    required this.onToggleEdibility,
    required this.onMonth,
    required this.onToggleHabitat,
    required this.onToggleGroup,
    required this.onClearGroups,
  });

  final SpeciesFilters filters;

  /// Mois en cours (1–12) : celui de « En saison ce mois-ci ».
  final int currentMonth;

  /// Nombre d'espèces par type et par famille d'habitat ; les valeurs à 0 ne
  /// sont pas proposées.
  final Map<MushroomGroup, int> groupTotals;
  final Map<HabitatFamily, int> habitatTotals;

  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<Edibility> onToggleEdibility;

  /// Mois choisi (1–12), ou `null` pour retirer le critère de saison.
  final ValueChanged<int?> onMonth;
  final ValueChanged<HabitatFamily> onToggleHabitat;
  final ValueChanged<MushroomGroup> onToggleGroup;
  final VoidCallback onClearGroups;

  /// Valeur renvoyée par la fenêtre des mois pour « Toute l'année ».
  static const _allYear = 0;

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choisir un mois'),
        children: [
          for (final month in [_allYear, for (var m = 1; m <= 12; m++) m])
            SimpleDialogOption(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              onPressed: () => Navigator.pop(ctx, month),
              child: Text(
                month == _allYear ? 'Toute l\'année' : capitalMonth(month),
                style: TextStyle(
                  fontWeight: month == (filters.month ?? _allYear)
                      ? FontWeight.w800
                      : FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
    if (picked != null) onMonth(picked == _allYear ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final count = filters.criteriaCount;
    final summary = filters.summary;
    final month = filters.month;
    // Un mois choisi à la main, autre que le mois en cours (déjà couvert par
    // « En saison ce mois-ci »).
    final otherMonth = month != null && month != currentMonth ? month : null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.tune),
        title: Text(
          count == 0 ? 'Filtres' : 'Filtres ($count)',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          summary.isEmpty ? 'Comestibilité, saison, habitat, type' : summary.join(' · '),
        ),
        childrenPadding: const EdgeInsets.only(bottom: 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Section(
            title: 'Comestibilité',
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final e in Edibility.values)
                  FilterChip(
                    avatar: Icon(e.icon, size: 18, color: e.color),
                    label: Text(e.label),
                    selected: filters.edibilities.contains(e),
                    showCheckmark: false,
                    onSelected: (_) => onToggleEdibility(e),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Saison',
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilterChip(
                  label: const Text('En saison ce mois-ci'),
                  selected: month == currentMonth,
                  onSelected: (on) => onMonth(on ? currentMonth : null),
                ),
                FilterChip(
                  label: Text(otherMonth == null ? 'Un autre mois…' : capitalMonth(otherMonth)),
                  selected: otherMonth != null,
                  onSelected: (_) => _pickMonth(context),
                ),
              ],
            ),
          ),
          if (habitatTotals.values.any((n) => n > 0))
            _Section(
              title: 'Habitat',
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final family in HabitatFamily.values)
                    if ((habitatTotals[family] ?? 0) > 0)
                      FilterChip(
                        label: Text('${family.label} (${habitatTotals[family]})'),
                        selected: filters.habitats.contains(family),
                        onSelected: (_) => onToggleHabitat(family),
                      ),
                ],
              ),
            ),
          if (groupTotals.values.any((n) => n > 0))
            _Section(
              title: 'Type de champignon',
              // La barre de types a déjà sa propre marge à gauche et à droite.
              inset: false,
              child: GroupFilterBar(
                counts: groupTotals,
                selected: filters.groups,
                onToggle: onToggleGroup,
                onClear: onClearGroups,
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.inset = true});

  final String title;
  final Widget child;
  final bool inset;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            if (inset)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child)
            else
              child,
          ],
        ),
      );
}
