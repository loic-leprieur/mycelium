import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/safety_widgets.dart';
import '../../../core/theme.dart';
import '../identifier.dart';
import '../identifier_provider.dart';
import '../identify_flow.dart';
import 'photo_quality.dart';
import 'quality_dialog.dart';

/// Une vue demandée à l'utilisateur.
class PhotoStep {
  const PhotoStep(this.title, this.hint);

  final String title;
  final String hint;
}

/// Vues guidées (ID-6). Chaque photo doit montrer le champignon : une photo sans
/// champignon pousserait le résultat vers « hors base ».
const photoSteps = [
  PhotoStep('Dessus du chapeau', 'Le champignon entier vu de dessus, bien éclairé.'),
  PhotoStep('Dessous du chapeau', 'Les lames, tubes ou pores sous le chapeau.'),
  PhotoStep('Pied', 'Le pied en entier, base comprise (anneau, volve).'),
  PhotoStep('Coupe', 'Le champignon coupé en deux : couleur de la chair.'),
  PhotoStep('Environnement', 'Le champignon là où il pousse, avec les arbres autour.'),
  PhotoStep('Autre vue', 'Un détail ou un autre angle utile.'),
];

const minPhotos = 2;

/// Écran « Je ne sais pas : plusieurs photos ». Renvoie l'[IdentificationOutcome]
/// (via `Navigator.pop`) ; l'écran appelant affiche le résultat.
class MultiPhotoScreen extends ConsumerStatefulWidget {
  const MultiPhotoScreen({super.key, required this.engine});

  final EmbeddingIdentifier engine;

  @override
  ConsumerState<MultiPhotoScreen> createState() => _MultiPhotoScreenState();
}

class _MultiPhotoScreenState extends ConsumerState<MultiPhotoScreen> {
  final _photos = <int, ChosenPhoto>{};
  final _quality = <int, QualityReport?>{};
  bool _busy = false;
  int _done = 0;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pick(int step, ImageSource source) async {
    final String? path;
    try {
      path = await ref.read(photoPickerProvider)(source);
    } catch (_) {
      _snack("Impossible d'accéder à la photo.");
      return;
    }
    if (path == null || !mounted) return;
    setState(() {
      _photos[step] = ChosenPhoto(path!, source);
      _quality.remove(step);
    });
    // Remarque non bloquante : la vignette signale le défaut.
    final report = await ref.read(photoQualityProvider)(path);
    if (mounted && _photos[step]?.path == path) {
      setState(() => _quality[step] = report);
    }
  }

  Future<void> _analyze() async {
    final steps = _photos.keys.toList()..sort();
    setState(() {
      _busy = true;
      _done = 0;
    });
    try {
      final outcome = await ref.read(identifyFlowProvider).identifyPhotos(
            [for (final s in steps) _photos[s]!],
            widget.engine,
            onProgress: (n) {
              if (mounted) setState(() => _done = n);
            },
          );
      if (mounted) Navigator.of(context).pop(outcome);
    } on IdentifyAnalysisError {
      _snack("L'analyse a échoué. Réessayez avec d'autres photos.");
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCamera = ref.watch(hasCameraProvider);
    final count = _photos.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Plusieurs photos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 28),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Photographiez le même champignon sous plusieurs angles : '
              'l\'analyse combine les photos. Commencez par le dessus du '
              'chapeau. Il en faut au moins $minPhotos, ${photoSteps.length} au maximum.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count photo${count > 1 ? 's' : ''} sur ${photoSteps.length}',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: count / photoSteps.length),
              ],
            ),
          ),
          for (var i = 0; i < photoSteps.length; i++)
            _StepCard(
              index: i,
              step: photoSteps[i],
              photo: _photos[i],
              quality: _quality[i],
              hasCamera: hasCamera,
              enabled: !_busy,
              onPick: (source) => _pick(i, source),
              onRemove: () => setState(() {
                _photos.remove(i);
                _quality.remove(i);
              }),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: (count >= minPhotos && !_busy) ? _analyze : null,
                  icon: const Icon(Icons.search),
                  label: Text(count >= minPhotos
                      ? 'Analyser ($count photos)'
                      : 'Analyser (encore ${minPhotos - count} photo${minPhotos - count > 1 ? 's' : ''})'),
                ),
                if (_busy)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        const LinearProgressIndicator(),
                        const SizedBox(height: 6),
                        Text('Analyse de la photo ${(_done + 1).clamp(1, count)} sur $count…'),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                const SafetyDisclaimer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.step,
    required this.photo,
    required this.quality,
    required this.hasCamera,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final int index;
  final PhotoStep step;
  final ChosenPhoto? photo;
  final QualityReport? quality;
  final bool hasCamera;
  final bool enabled;
  final void Function(ImageSource source) onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = photo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (chosen != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(chosen.path),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 64,
                        height: 64,
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  )
                else
                  CircleAvatar(
                    backgroundColor: Palette.sage,
                    child: Text('${index + 1}'),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${index + 1}. ${step.title}',
                          style: theme.textTheme.titleMedium),
                      Text(step.hint),
                      if (quality != null && quality!.hasIssues)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${quality!.issues.map(qualityIssueLabel).join(', ')} : '
                            'vous pouvez la refaire.',
                            style: const TextStyle(
                                color: Palette.berry, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
                if (chosen != null)
                  IconButton(
                    tooltip: 'Retirer cette photo',
                    onPressed: enabled ? onRemove : null,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hasCamera)
                  FilledButton.icon(
                    onPressed: enabled ? () => onPick(ImageSource.camera) : null,
                    icon: const Icon(Icons.photo_camera),
                    label: Text(chosen == null ? 'Appareil photo' : 'Refaire'),
                  ),
                OutlinedButton.icon(
                  onPressed: enabled ? () => onPick(ImageSource.gallery) : null,
                  icon: Icon(hasCamera ? Icons.photo_library : Icons.folder_open),
                  label: Text(hasCamera ? 'Galerie' : 'Choisir une photo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
