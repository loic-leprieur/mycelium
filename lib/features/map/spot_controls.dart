import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/group_filter.dart';
import '../../core/rustic.dart';
import '../../core/theme.dart';
import 'location.dart';
import 'spot_filter.dart';
import 'spot_providers.dart';

/// Filtres et tri de la liste des coins (SPOT-6) : types de champignons,
/// favoris, ordre. Ils agissent aussi sur les marqueurs de la carte.
class SpotControls extends ConsumerWidget {
  const SpotControls({super.key, required this.showSortRow});

  /// Ligne « Favoris / Trier » : inutile tant qu'il n'y a qu'un seul coin.
  final bool showSortRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.read(mapGroupFilterProvider.notifier);
    final hasPosition =
        ref.watch(locationProvider.select((l) => l.value?.latLng != null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GroupFilterBar(
          counts: ref.watch(spotGroupCountsProvider),
          selected: ref.watch(mapGroupFilterProvider),
          onToggle: types.toggle,
          onClear: types.clear,
        ),
        if (showSortRow)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  avatar: const Icon(Icons.star, size: 18, color: Palette.chanterelle),
                  label: const Text('Favoris'),
                  selected: ref.watch(spotFavoritesOnlyProvider),
                  showCheckmark: false,
                  onSelected: (_) =>
                      ref.read(spotFavoritesOnlyProvider.notifier).toggle(),
                ),
                _SortMenu(
                  current: effectiveSort(
                    ref.watch(spotSortProvider),
                    hasPosition: hasPosition,
                  ),
                  hasPosition: hasPosition,
                  onSelected: ref.read(spotSortProvider.notifier).choose,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bouton « Trier : Distance » qui ouvre le menu des trois ordres possibles.
class _SortMenu extends StatelessWidget {
  const _SortMenu({
    required this.current,
    required this.hasPosition,
    required this.onSelected,
  });

  final SpotSort current;
  final bool hasPosition;
  final ValueChanged<SpotSort> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<SpotSort>(
        tooltip: 'Changer le tri',
        initialValue: current,
        onSelected: onSelected,
        itemBuilder: (_) => [
          for (final sort in SpotSort.values)
            CheckedPopupMenuItem<SpotSort>(
              value: sort,
              checked: sort == current,
              // Sans position GPS, la distance ne peut pas être calculée.
              enabled: sort != SpotSort.distance || hasPosition,
              child: Text(
                sort == SpotSort.distance && !hasPosition
                    ? 'Distance (position inconnue)'
                    : sort.menuLabel,
              ),
            ),
        ],
        child: Chip(
          avatar: const Icon(Icons.swap_vert, size: 18),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Trier : ${current.label}'),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      );
}

/// Contenu du panneau quand des coins existent mais qu'aucun ne passe les filtres.
class NoMatchingSpots extends StatelessWidget {
  const NoMatchingSpots({super.key, required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) => EmptyState(
        title: 'Aucun coin ne correspond',
        message: "Un coin apparaît sous un type dès qu'une espèce de ce type y "
            'est notée : dans la fiche du coin, ou par une récolte.',
        action: FilledButton.icon(
          onPressed: onShowAll,
          icon: const Icon(Icons.filter_alt_off),
          label: const Text('Tout afficher'),
        ),
      );
}
