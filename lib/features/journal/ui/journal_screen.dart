import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/providers.dart';

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outings = ref.watch(outingsProvider);
    final spots = ref.watch(spotsProvider).value ?? const [];
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aucune sortie pour le moment.\nAjoutez votre première sortie !',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final o = list[i];
              final spotName = spots
                  .where((s) => s.id == o.spotId)
                  .map((s) => s.name)
                  .firstOrNull;
              return ListTile(
                minTileHeight: 64,
                leading: const CircleAvatar(child: Icon(Icons.forest)),
                title: Text(dateFormat.format(o.startedAt)),
                subtitle: Text(spotName ?? 'Lieu non précisé'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/journal/${o.id}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
      ),
    );
  }
}
