import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/rustic.dart';
import '../../../core/theme.dart';
import '../../../data/providers.dart';

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outings = ref.watch(outingsProvider);
    final spots = ref.watch(spotsProvider).value ?? const [];
    final totals = ref.watch(outingTotalsProvider).value ?? const <String, OutingTotals>{};
    final dateFormat = DateFormat.yMMMMEEEEd('fr');
    return Scaffold(
      appBar: AppBar(title: const Text('Carnet')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/journal/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle sortie'),
      ),
      body: outings.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              title: 'Aucune sortie pour le moment',
              message: 'Notez vos sorties et vos récoltes : elles resteront ici, '
                  'même sans réseau.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 96),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final o = list[i];
              final spotName = spots
                  .where((s) => s.id == o.spotId)
                  .map((s) => s.name)
                  .firstOrNull;
              return Card(
                child: ListTile(
                  minTileHeight: 72,
                  leading: const CircleAvatar(
                    backgroundColor: Palette.sage,
                    child: Icon(Icons.forest, color: Palette.forestDark),
                  ),
                  title: Text(
                    dateFormat.format(o.startedAt),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(_subtitle(spotName, totals[o.id])),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/journal/${o.id}'),
                ),
              ).stagger(i);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
      ),
    );
  }
}

String _subtitle(String? spotName, OutingTotals? totals) {
  final parts = [
    spotName ?? 'Lieu non précisé',
    if (totals != null && totals.pieces > 0) formatPieces(totals.pieces),
    if (totals != null && totals.grams > 0) formatWeight(totals.grams),
  ];
  return parts.join(' · ');
}
