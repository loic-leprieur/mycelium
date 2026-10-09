import 'package:flutter/material.dart';

import '../identifier.dart';

/// Remarques sur la qualité de la photo et sur le contexte (mois, type de forêt),
/// affichées sous les propositions du résultat (ID-7, ID-8).
///
/// SQUELETTE posé par le socle commun, déjà inséré dans l'écran de résultat :
/// à remplacer par l'agent « Analyse d'image ». N'affiche rien pour l'instant.
class AnalysisNotes extends StatelessWidget {
  const AnalysisNotes({super.key, required this.outcome});

  final IdentificationOutcome outcome;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
