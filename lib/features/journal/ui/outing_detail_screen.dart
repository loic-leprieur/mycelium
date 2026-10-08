import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/rustic.dart';
import '../../../core/theme.dart';
import '../../../data/database.dart';
import '../../../data/photo_store.dart';
import '../../../data/providers.dart';
import 'harvest_form_sheet.dart';

class OutingDetailScreen extends ConsumerWidget {
  const OutingDetailScreen({super.key, required this.outingId});

  final String outingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outing = ref.watch(outingProvider(outingId)).value;
    final harvests = ref.watch(harvestsProvider(outingId)).value ?? const <Harvest>[];
    final spots = ref.watch(spotsProvider).value ?? const [];
    final theme = Theme.of(context);

    if (outing == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final spotName =
        spots.where((s) => s.id == outing.spotId).map((s) => s.name).firstOrNull;

    final totalPieces = harvests.fold<int>(0, (sum, h) => sum + (h.quantityCount ?? 0));
    final totalGrams = harvests.fold<int>(0, (sum, h) => sum + (h.weightGrams ?? 0));

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
                  content: const Text('Les récoltes et leurs photos seront supprimées.'),
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
                for (final h in harvests) {
                  await deletePhoto(h.photoPath);
                }
                await ref.read(databaseProvider).deleteOuting(outingId);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showHarvestForm(context, outingId),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une récolte'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
        children: [
          Text(
            DateFormat.yMMMMEEEEd('fr').format(outing.startedAt),
            style: theme.textTheme.titleLarge,
          ).stagger(0),
          const SizedBox(height: 4),
          Text(spotName ?? 'Lieu non précisé'),
          if (outing.durationMin != null) Text('Durée : ${outing.durationMin} min'),
          if (outing.notes != null) ...[
            const SizedBox(height: 12),
            Text(outing.notes!),
          ],
          if (harvests.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Totals(pieces: totalPieces, grams: totalGrams).stagger(1),
          ],
          const SizedBox(height: 20),
          Text('Récolte', style: theme.textTheme.titleMedium),
          if (harvests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Aucune récolte enregistrée.'),
            ),
          for (var i = 0; i < harvests.length; i++)
            _HarvestCard(harvest: harvests[i]).stagger(i + 2),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.pieces, required this.grams});

  final int pieces;
  final int grams;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (pieces > 0) formatPieces(pieces),
      if (grams > 0) formatWeight(grams),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Palette.sage.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.scale, color: Palette.forestDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              parts.isEmpty ? 'Récolte' : 'Total : ${parts.join(' · ')}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _HarvestCard extends ConsumerWidget {
  const _HarvestCard({required this.harvest});

  final Harvest harvest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final species = ref.watch(speciesByIdProvider(harvest.speciesId));
    final photo = harvest.photoPath;
    final hasPhoto = photo != null && File(photo).existsSync();

    final details = [
      if (harvest.weightGrams != null) formatWeight(harvest.weightGrams!),
      if (harvest.notes != null) harvest.notes!,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasPhoto)
            GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  insetPadding: const EdgeInsets.all(12),
                  clipBehavior: Clip.antiAlias,
                  child: InteractiveViewer(child: Image.file(File(photo))),
                ),
              ),
              child: Image.file(File(photo), height: 170, fit: BoxFit.cover),
            ),
          ListTile(
            title: Text(
              species?.commonName ?? harvest.speciesId,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: details.isEmpty ? null : Text(details),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (harvest.quantityCount != null)
                  Text('× ${harvest.quantityCount}', style: theme.textTheme.titleMedium),
                IconButton(
                  tooltip: 'Retirer',
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    await deletePhoto(harvest.photoPath);
                    await ref.read(databaseProvider).deleteHarvest(harvest.id);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
