import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rustic.dart';
import '../../../core/safety_widgets.dart';
import '../../../core/theme.dart';
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
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Hero(
                tag: 'species-${species.id}',
                child: photo != null && File(photo).existsSync()
                    ? CircleAvatar(radius: 44, backgroundImage: FileImage(File(photo)))
                    : CircleAvatar(
                        radius: 44,
                        backgroundColor: species.edibility.color.withValues(alpha: 0.16),
                        child: Icon(species.edibility.icon,
                            size: 44, color: species.edibility.color),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(species.commonName, style: theme.textTheme.headlineSmall),
                    if (species.scientificName != null)
                      Text(
                        species.scientificName!,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.w400),
                      ),
                    if (species.family != null) Text(species.family!),
                  ],
                ),
              ),
            ],
          ).stagger(0),
          const SizedBox(height: 14),
          if (species.isCustom)
            const InfoBanner(
              title: 'Fiche personnelle, non vérifiée',
              message:
                  'Cette fiche a été ajoutée par vous. L\'application ne garantit '
                  'ni son exactitude ni la comestibilité de cette espèce.',
              color: Color(0xFFE0E0E0),
              icon: Icons.person,
            ).stagger(1)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EdibilityChip(
                  label: species.edibility.label,
                  color: species.edibility.color,
                  icon: species.edibility.icon,
                ),
                if (species.edibilityNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(species.edibilityNote!),
                  ),
                if (species.edibility.isDangerous)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/settings/safety'),
                      icon: const Icon(Icons.health_and_safety_outlined),
                      label: const Text('Intoxication : que faire ?'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Palette.berry,
                        side: const BorderSide(color: Palette.berry, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ).stagger(1),
          if (photo != null && File(photo).existsSync()) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(File(photo), height: 220, fit: BoxFit.cover),
            ).stagger(2),
          ],
          const SizedBox(height: 6),
          const LeafDivider(),
          if (species.description.isNotEmpty)
            _Section(title: 'Description', body: species.description).stagger(2),
          if (species.habitat != null)
            _Section(title: 'Habitat', body: species.habitat!).stagger(3),
          if (species.seasonLabel != null)
            _Section(title: 'Période', body: species.seasonLabel!).stagger(4),
          if (species.confusions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('⚠️ Confusions possibles', style: theme.textTheme.titleMedium).stagger(5),
            const SizedBox(height: 4),
            for (var i = 0; i < species.confusions.length; i++)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  title: Text(species.confusions[i].name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(species.confusions[i].note),
                  trailing: species.confusions[i].speciesId != null
                      ? const Icon(Icons.chevron_right)
                      : null,
                  onTap: species.confusions[i].speciesId == null
                      ? null
                      : () => context.push('/species/${species.confusions[i].speciesId}'),
                ),
              ).stagger(6 + i),
          ],
          const SizedBox(height: 16),
          const SafetyDisclaimer().stagger(8),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(height: 1.4)),
          ],
        ),
      );
}
