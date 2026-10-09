import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/rustic.dart';
import '../../../core/safety_widgets.dart';
import '../../../core/theme.dart';
import '../identifier.dart';
import '../identifier_provider.dart';
import '../identify_flow.dart';

/// Écran « Identifier » : photo -> analyse locale -> résultat (ID-1, ID-2).
///
/// Sans le modèle embarqué, seuls les exemples de DÉMONSTRATION sont proposés.
class IdentifyScreen extends ConsumerStatefulWidget {
  const IdentifyScreen({super.key});

  @override
  ConsumerState<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends ConsumerState<IdentifyScreen> {
  bool _busy = false;

  /// L'appareil photo n'est géré que sur téléphone ; sur ordinateur, on choisit
  /// un fichier.
  bool get _hasCamera => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runDemo(int index) async {
    setState(() => _busy = true);
    final outcome = await ref.read(identifyFlowProvider).demo(index);
    if (!mounted) return;
    setState(() => _busy = false);
    context.push('/identify/result', extra: outcome);
  }

  Future<void> _photo(ImageSource source, Identifier engine) async {
    try {
      final outcome = await ref.read(identifyFlowProvider).captureAndIdentify(
            source,
            engine,
            onPhotoChosen: () {
              if (mounted) setState(() => _busy = true);
            },
          );
      if (mounted) context.push('/identify/result', extra: outcome);
    } on IdentifyCancelled {
      // Fenêtre fermée : rien à faire.
    } on IdentifyPhotoError {
      _snack("Impossible d'accéder à la photo.");
    } on IdentifyAnalysisError {
      _snack("L'analyse de la photo a échoué. Réessayez avec une autre photo.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final engine = ref.watch(identifierProvider);
    final real = engine.value;
    final demoOnly = engine.hasValue && real == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Identifier')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 28),
        children: [
          Center(
            child: const MushroomLogo(size: 86)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: -4, end: 4, duration: 1700.ms, curve: Curves.easeInOut),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _EngineBanner(engine: engine),
          ).stagger(0),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_hasCamera)
                  FilledButton.icon(
                    onPressed: (real == null || _busy)
                        ? null
                        : () => _photo(ImageSource.camera, real),
                    icon: const Icon(Icons.photo_camera),
                    label: Text(demoOnly ? 'Prendre une photo (bientôt)' : 'Prendre une photo'),
                  ),
                if (_hasCamera) const SizedBox(height: 10),
                if (_hasCamera)
                  OutlinedButton.icon(
                    onPressed: (real == null || _busy)
                        ? null
                        : () => _photo(ImageSource.gallery, real),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Choisir dans la galerie'),
                  )
                else
                  FilledButton.icon(
                    onPressed: (real == null || _busy)
                        ? null
                        : () => _photo(ImageSource.gallery, real),
                    icon: const Icon(Icons.folder_open),
                    label: Text(demoOnly ? 'Choisir une photo (bientôt)' : 'Choisir une photo'),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push('/identify/history'),
                  icon: const Icon(Icons.history),
                  label: const Text('Mes identifications'),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: Column(
                      children: [
                        LinearProgressIndicator(),
                        SizedBox(height: 6),
                        Text('Analyse de la photo sur l\'appareil…'),
                      ],
                    ),
                  )
                else if (real != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Pour de meilleurs résultats : le champignon entier, bien '
                      'éclairé, photographié de dessus puis par-dessous.',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ).stagger(1),
          const SizedBox(height: 18),
          const LeafDivider(),
          if (real == null)
            ..._demoExamples(theme, startIndex: 2)
          else
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text('Exemples fictifs (démonstration)', style: theme.textTheme.titleMedium),
                subtitle: const Text('Résultats inventés, pour voir comment s\'affiche une alerte.'),
                children: _demoExamples(theme, startIndex: 0, withTitle: false),
              ),
            ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: SafetyDisclaimer(),
          ).stagger(7),
        ],
      ),
    );
  }

  List<Widget> _demoExamples(
    ThemeData theme, {
    required int startIndex,
    bool withTitle = true,
  }) =>
      [
        if (withTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
            child: Text('Exemples de résultats', style: theme.textTheme.titleMedium),
          ),
        for (var i = 0; i < FakeIdentifier.scenarios.length; i++)
          Card(
            child: ListTile(
              enabled: !_busy,
              minTileHeight: 76,
              leading: CircleAvatar(
                backgroundColor: Palette.sage,
                child: Icon(
                  [Icons.forest, Icons.wb_sunny, Icons.warning_amber, Icons.grass][i % 4],
                  color: Palette.forestDark,
                ),
              ),
              title: Text(FakeIdentifier.scenarios[i].label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(FakeIdentifier.scenarios[i].description),
              trailing: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_circle_outline, color: Palette.forest),
              onTap: _busy ? null : () => _runDemo(i),
            ),
          ).stagger(startIndex + i),
      ];
}

/// État du moteur d'identification : chargement, prêt, absent ou en erreur.
class _EngineBanner extends StatelessWidget {
  const _EngineBanner({required this.engine});

  final AsyncValue<Identifier?> engine;

  @override
  Widget build(BuildContext context) {
    if (engine.hasError) {
      return const InfoBanner(
        title: 'Identification indisponible',
        message: 'Le modèle d\'identification n\'a pas pu démarrer. Aucun '
            'résultat ne sera affiché plutôt qu\'un résultat douteux.',
        color: Color(0xFFC62828),
        icon: Icons.error_outline,
      );
    }
    if (engine.isLoading) {
      return const InfoBanner(
        title: 'Chargement du modèle…',
        message: 'Préparation de l\'identification sur l\'appareil (quelques secondes).',
        color: Palette.sage,
        icon: Icons.hourglass_top,
      );
    }
    if (engine.value == null) {
      return const InfoBanner(
        title: 'MODE DÉMONSTRATION',
        message: 'L\'identification réelle n\'est pas installée dans cette version. '
            'Les résultats ci-dessous sont fictifs et servent uniquement à '
            'tester l\'affichage. Ne vous y fiez jamais.',
        color: Color(0xFFF0B96B),
      );
    }
    return const InfoBanner(
      title: 'Identification sur l\'appareil',
      message: 'La photo est analysée sur votre téléphone, sans réseau, et n\'en '
          'sort jamais. C\'est une aide : elle peut se tromper.',
      color: Palette.sage,
      icon: Icons.offline_bolt,
    );
  }
}
