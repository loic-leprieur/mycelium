import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Consentement explicite au premier lancement : l'application est une aide, non
/// fiable à 100 %. L'acceptation est journalisée (cahier des charges §9.1).
///
/// SQUELETTE posé par le socle commun : à remplacer par l'agent « Sécurité ».
/// Route : `/consent`. Le branchement après l'écran d'accueil est à faire par cet agent.
class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Avant de commencer')),
        body: const Center(child: Text('À venir')),
      );
}
