import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sauvegarde et données : export/import d'une archive complète (DATA-2) et
/// suppression de toutes les données (DATA-4).
///
/// SQUELETTE posé par le socle commun : à remplacer par l'agent « Sauvegarde ».
class DataScreen extends ConsumerWidget {
  const DataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Sauvegarde et données')),
        body: const Center(child: Text('À venir')),
      );
}
