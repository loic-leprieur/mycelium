import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/safety_widgets.dart';
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
        padding: const EdgeInsets.all(16),
        children: [
          const InfoBanner(
            title: 'MODE DÉMONSTRATION',
            message:
                'L\'identification réelle n\'est pas encore disponible. Les résultats '
                'ci-dessous sont fictifs et servent uniquement à tester l\'affichage. '
                'Ne vous y fiez jamais.',
            color: Color(0xFFFFB74D),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.photo_camera),
            label: const Text('Prendre une photo (bientôt)'),
          ),
          const SizedBox(height: 24),
          Text('Exemples de résultats', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < FakeIdentifier.scenarios.length; i++)
            Card(
              child: ListTile(
                enabled: !_busy,
                title: Text(FakeIdentifier.scenarios[i].label),
                subtitle: Text(FakeIdentifier.scenarios[i].description),
                trailing: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                onTap: _busy ? null : () => _run(i),
              ),
            ),
          const SizedBox(height: 16),
          const SafetyDisclaimer(),
        ],
      ),
    );
  }
}
