import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../species/domain/species.dart';

class OutingDetailScreen extends ConsumerWidget {
  const OutingDetailScreen({super.key, required this.outingId});

  final String outingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outing = ref.watch(outingProvider(outingId)).value;
    final harvests = ref.watch(harvestsProvider(outingId)).value ?? const [];
    final spots = ref.watch(spotsProvider).value ?? const [];
    final theme = Theme.of(context);

    if (outing == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final spotName =
        spots.where((s) => s.id == outing.spotId).map((s) => s.name).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sortie'),
        actions: [
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Supprimer cette sortie ?'),
                  content: const Text('Les récoltes associées seront supprimées.'),
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
                await ref.read(databaseProvider).deleteOuting(outingId);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addHarvest(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une récolte'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            DateFormat.yMMMMEEEEd('fr').format(outing.startedAt),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(spotName ?? 'Lieu non précisé'),
          if (outing.durationMin != null) Text('Durée : ${outing.durationMin} min'),
          if (outing.notes != null) ...[
            const SizedBox(height: 12),
            Text(outing.notes!),
          ],
          const SizedBox(height: 24),
          Text('Récolte', style: theme.textTheme.titleMedium),
          if (harvests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Aucune récolte enregistrée.'),
            ),
          for (final h in harvests)
            Card(
              child: ListTile(
                title: Text(
                  ref.watch(speciesByIdProvider(h.speciesId))?.commonName ??
                      h.speciesId,
                ),
                subtitle: h.notes == null ? null : Text(h.notes!),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (h.quantityCount != null)
                      Text('× ${h.quantityCount}', style: theme.textTheme.titleMedium),
                    IconButton(
                      tooltip: 'Retirer',
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          ref.read(databaseProvider).deleteHarvest(h.id),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addHarvest(BuildContext context, WidgetRef ref) async {
    final species = ref.read(allSpeciesProvider).value ?? const <Species>[];
    final sorted = [...species]..sort((a, b) => a.commonName.compareTo(b.commonName));
    String? speciesId;
    final count = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Ajouter une récolte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: speciesId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Espèce'),
                items: [
                  for (final s in sorted)
                    DropdownMenuItem(value: s.id, child: Text(s.commonName)),
                ],
                onChanged: (v) => setState(() => speciesId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: count,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantité'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: speciesId == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && speciesId != null) {
      await ref.read(databaseProvider).addHarvest(
            HarvestsCompanion.insert(
              id: const Uuid().v4(),
              outingId: outingId,
              speciesId: speciesId!,
              quantityCount: Value(int.tryParse(count.text.trim())),
            ),
          );
    }
    count.dispose();
  }
}
