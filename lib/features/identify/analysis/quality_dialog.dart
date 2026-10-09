import 'dart:io';

import 'package:flutter/material.dart';

import '../identify_flow.dart';
import 'photo_quality.dart';

/// Phrase d'explication et conseil pour chaque défaut.
String qualityIssueText(QualityIssue issue) => switch (issue) {
      QualityIssue.blurry =>
        'La photo semble floue. Stabilisez le téléphone, laissez la mise au '
            'point se faire et rapprochez-vous du champignon.',
      QualityIssue.tooDark =>
        'La photo est très sombre. Cherchez un endroit plus clair ou éclairez '
            'le champignon.',
      QualityIssue.tooBright =>
        'La photo est surexposée (trop de blanc). Placez-vous à l\'ombre ou '
            'évitez le contre-jour.',
      QualityIssue.tooSmall =>
        'La photo est trop petite pour distinguer les détails.',
    };

/// Résumé court pour une vignette ou le résultat.
String qualityIssueLabel(QualityIssue issue) => switch (issue) {
      QualityIssue.blurry => 'Photo floue',
      QualityIssue.tooDark => 'Photo trop sombre',
      QualityIssue.tooBright => 'Photo surexposée',
      QualityIssue.tooSmall => 'Photo trop petite',
    };

/// Fenêtre « photo de mauvaise qualité » : refaire ou utiliser quand même. Pas de
/// fermeture par erreur : l'utilisateur fait toujours un choix explicite.
Future<QualityChoice> askAboutPhotoQuality(
  BuildContext context,
  QualityReport report,
  String imagePath,
) async {
  final choice = await showDialog<QualityChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Photo à vérifier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(imagePath),
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
              for (final issue in report.issues)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(qualityIssueText(issue)),
                ),
              const Text(
                'Vous pouvez quand même l\'utiliser : le résultat sera '
                'simplement moins fiable.',
              ),
            ],
          ),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(QualityChoice.retake),
            child: const Text('Refaire la photo'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(QualityChoice.useAnyway),
            child: const Text('Utiliser quand même'),
          ),
        ],
      ),
    ),
  );
  return choice ?? QualityChoice.useAnyway;
}
