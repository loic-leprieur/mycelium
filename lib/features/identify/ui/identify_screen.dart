import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/rustic.dart';
import '../../../core/safety_widgets.dart';
import '../../../core/theme.dart';
import '../../../data/providers.dart';
import '../identifier.dart';

/// Écran « Identifier ». Pour l'instant : moteur de DÉMONSTRATION uniquement.
class IdentifyScreen extends ConsumerStatefulWidget {
  const IdentifyScreen({super.key});

  @override
  ConsumerState<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends ConsumerState<IdentifyScreen> {
  bool _busy = false;

  Future<void> _run(int index) async {
    setState(() => _busy = true);
    final identifier = FakeIdentifier(scenarioIndex: index);
    final raw = await identifier.identify(const IdentificationInput());
    if (!mounted) return;
    final all = ref.read(allSpeciesProvider).value;
    final outcome = applySafetyRules(
      raw,
      edibilityOf: (id) {
        if (all == null) return seedEdibilityOf(id);
        for (final s in all) {
          if (s.id == id) return s.edibility;
        }
        return null;
      },
      isDemo: true,
      scenarioLabel: FakeIdentifier.scenarios[index].label,
    );
    setState(() => _busy = false);
    context.push('/identify/result', extra: outcome);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            child: const InfoBanner(
              title: 'MODE DÉMONSTRATION',
              message:
                  'L\'identification réelle n\'est pas encore disponible. Les résultats '
                  'ci-dessous sont fictifs et servent uniquement à tester l\'affichage. '
                  'Ne vous y fiez jamais.',
              color: Color(0xFFF0B96B),
            ),
          ).stagger(0),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Prendre une photo (bientôt)'),
            ),
          ).stagger(1),
          const SizedBox(height: 18),
          const LeafDivider(),
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
                onTap: _busy ? null : () => _run(i),
              ),
            ).stagger(i + 2),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: SafetyDisclaimer(),
          ).stagger(7),
        ],
      ),
    );
  }
}
