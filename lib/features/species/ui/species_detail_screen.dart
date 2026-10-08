import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/safety_widgets.dart';
import '../../../data/providers.dart';

class SpeciesDetailScreen extends ConsumerWidget {
  const SpeciesDetailScreen({super.key, required this.speciesId});

  final String speciesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observe la liste pour se mettre à jour quand une espèce personnalisée change.
    ref.watch(allSpeciesProvider);
    final species = ref.watch(speciesByIdProvider(speciesId));
    if (species == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Espèce introuvable.')),
      );
    }
    final theme = Theme.of(context);
    final photo = species.photoPath;
    return Scaffold(
      appBar: AppBar(
        title: Text(species.commonName),
        actions: [
          if (species.isCustom)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Supprimer cette fiche ?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Supprimer'),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await ref.read(databaseProvider).deleteCustomSpecies(species.id);
                  if (context.mounted) context.pop();
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (photo != null && File(photo).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(photo), height: 220, fit: BoxFit.cover),
            ),
          if (species.scientificName != null) ...[
            const SizedBox(height: 12),
            Text(
              species.scientificName!,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          if (species.family != null) Text(species.family!),
          const SizedBox(height: 12),
          if (species.isCustom)
            const InfoBanner(
              title: 'Fiche personnelle, non vérifiée',
              message:
                  'Cette fiche a été ajoutée par vous. L\'application ne garantit '
                  'ni son exactitude ni la comestibilité de cette espèce.',
              color: Color(0xFFE0E0E0),
              icon: Icons.person,
            )
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: EdibilityChip(
                label: species.edibility.label,
                color: species.edibility.color,
                icon: species.edibility.icon,
              ),
            ),
            if (species.edibilityNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(species.edibilityNote!),
              ),
          ],
          const SizedBox(height: 16),
          if (species.description.isNotEmpty) ...[
            Text('Description', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(species.description),
            const SizedBox(height: 16),
          ],
          if (species.habitat != null) ...[
            Text('Habitat', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(species.habitat!),
            const SizedBox(height: 16),
          ],
          if (species.seasonLabel != null) ...[
            Text('Période', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(species.seasonLabel!),
            const SizedBox(height: 16),
          ],
          if (species.confusions.isNotEmpty) ...[
            Text('⚠️ Confusions possibles', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final c in species.confusions)
              Card(
                child: ListTile(
                  title: Text(c.name),
                  subtitle: Text(c.note),
                  trailing: c.speciesId != null
                      ? const Icon(Icons.chevron_right)
                      : null,
                  onTap: c.speciesId == null
                      ? null
                      : () => context.push('/species/${c.speciesId}'),
                ),
              ),
          ],
          const SizedBox(height: 16),
          const SafetyDisclaimer(),
        ],
      ),
    );
  }
}
