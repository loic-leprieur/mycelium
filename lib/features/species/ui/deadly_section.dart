import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/species.dart';

/// Rubrique « Espèces mortelles à connaître » (cahier des charges §9.1), en tête
/// de la liste : les fiches mortelles du catalogue, repliables d'un geste.
class DeadlySection extends StatelessWidget {
  const DeadlySection({
    super.key,
    required this.species,
    required this.expanded,
    required this.onExpansionChanged,
  });

  /// Espèces mortelles, déjà triées.
  final List<Species> species;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    final color = Edibility.deadly.color;
    final count = species.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFFFDEEEE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: ExpansionTile(
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: color,
        collapsedIconColor: color,
        leading: Icon(Edibility.deadly.icon, color: color),
        title: Text(
          'Espèces mortelles à connaître',
          style: TextStyle(fontWeight: FontWeight.w800, color: color),
        ),
        subtitle: Text('$count ${count <= 1 ? 'espèce' : 'espèces'} : ne jamais en consommer'),
        children: [
          for (final s in species)
            ListTile(
              minTileHeight: 56,
              title: Text(s.commonName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: s.scientificName == null
                  ? null
                  : Text(
                      s.scientificName!,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/species/${s.id}'),
            ),
        ],
      ),
    );
  }
}
