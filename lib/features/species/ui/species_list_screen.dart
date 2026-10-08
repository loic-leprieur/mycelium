import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rustic.dart';
import '../../../data/providers.dart';
import '../domain/species.dart';

class SpeciesListScreen extends ConsumerStatefulWidget {
  const SpeciesListScreen({super.key});

  @override
  ConsumerState<SpeciesListScreen> createState() => _SpeciesListScreenState();
}

class _SpeciesListScreenState extends ConsumerState<SpeciesListScreen> {
  String _query = '';
  Edibility? _filter;

  bool _matches(Species s) {
    if (_filter != null && s.edibility != _filter) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return s.commonName.toLowerCase().contains(q) ||
        (s.scientificName?.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final species = ref.watch(allSpeciesProvider);
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
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final e in Edibility.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      avatar: Icon(e.icon, size: 18, color: e.color),
                      label: Text(e.label),
                      selected: _filter == e,
                      showCheckmark: false,
                      onSelected: (on) => setState(() => _filter = on ? e : null),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: species.when(
              data: (all) {
                final shown = all.where(_matches).toList()
                  ..sort((a, b) => a.commonName.compareTo(b.commonName));
                if (shown.isEmpty) {
                  return const EmptyState(
                    title: 'Aucune espèce trouvée',
                    message: 'Essayez un autre nom ou retirez un filtre.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 96),
                  itemCount: shown.length,
                  itemBuilder: (context, i) =>
                      _SpeciesTile(species: shown[i]).stagger(i),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
            ),
          ),
        ],
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
        subtitle: Text(
          species.isCustom
              ? 'Fiche personnelle, non vérifiée'
              : '${species.scientificName ?? ''}\n${species.edibility.label}',
          style: species.isCustom || species.scientificName == null
              ? null
              : const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
        ),
        isThreeLine: !species.isCustom,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/species/${species.id}'),
      ),
    );
  }
}
