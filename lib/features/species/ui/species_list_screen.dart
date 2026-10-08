import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                      label: Text(e.label),
                      selected: _filter == e,
                      onSelected: (on) =>
                          setState(() => _filter = on ? e : null),
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
                  return const Center(child: Text('Aucune espèce trouvée.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _SpeciesTile(species: shown[i]),
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
    return ListTile(
      minTileHeight: 64,
      leading: photo != null && File(photo).existsSync()
          ? CircleAvatar(backgroundImage: FileImage(File(photo)))
          : CircleAvatar(
              backgroundColor: species.edibility.color.withValues(alpha: 0.15),
              child: Icon(species.edibility.icon, color: species.edibility.color),
            ),
      title: Text(species.commonName),
      subtitle: Text(
        species.isCustom
            ? 'Fiche personnelle, non vérifiée'
            : '${species.scientificName ?? ''} · ${species.edibility.label}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/species/${species.id}'),
    );
  }
}
