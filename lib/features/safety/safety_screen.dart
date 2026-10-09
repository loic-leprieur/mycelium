import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// « Que faire en cas d'intoxication » : numéros d'urgence et centres antipoison,
/// consultable hors ligne (cahier des charges §9.1).
///
/// SQUELETTE posé par le socle commun : à remplacer par l'agent « Sécurité ».
class SafetyScreen extends ConsumerWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Intoxication : que faire ?')),
        body: const Center(child: Text('À venir')),
      );
}
