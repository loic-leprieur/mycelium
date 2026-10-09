import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'phone_dialer.dart';
import 'poison_data.dart';

/// « Que faire en cas d'intoxication » : numéros d'urgence et centres antipoison,
/// consultable hors ligne (cahier des charges §9.1). Contenu statique, repris de
/// sources officielles citées en bas de page.
class SafetyScreen extends ConsumerWidget {
  const SafetyScreen({super.key});

  Future<void> _call(BuildContext context, WidgetRef ref, PhoneEntry e) async {
    var ok = false;
    try {
      ok = await ref.read(phoneDialerProvider)(Uri(scheme: 'tel', path: e.dial));
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          "L'appel n'a pas pu être lancé depuis cet appareil. "
          'Composez le ${e.display} sur un téléphone.',
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Intoxication : que faire ?')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            children: [
              _EmergencyBanner(onCall: (e) => _call(context, ref, e)),
              const SizedBox(height: 22),
              Text('Centres antipoison', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'Joignables 24 h/24 et 7 j/7. Dès les premiers symptômes '
                '(diarrhées, vomissements, nausées, tremblements, vertiges, '
                'troubles de la vue…), appelez immédiatement un centre '
                'antipoison en précisant que vous avez mangé des champignons.',
              ),
              const SizedBox(height: 8),
              _PhoneCard(
                entry: nationalPoisonNumber,
                emphasized: true,
                onCall: () => _call(context, ref, nationalPoisonNumber),
              ),
              for (final c in poisonCentres)
                _PhoneCard(entry: c, onCall: () => _call(context, ref, c)),
              const SizedBox(height: 22),
              Text('Les bons gestes', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final (i, g) in gestures.indexed)
                _GestureTile(number: i + 1, gesture: g),
              const SizedBox(height: 18),
              Text("Le délai d'apparition", style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(onsetDelayAnses),
              Text('Source : $srcAnses', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              const Text(onsetDelayArs),
              Text('Source : $srcArs (guide destiné aux soignants)',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE082),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  notMedicalAdvice,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.black87),
                ),
              ),
              const SizedBox(height: 22),
              Text('Sources', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('Numéros et consignes vérifiés le $safetyVerifiedOn :',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              for (final s in safetySources)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SelectableText('• $s', style: theme.textTheme.bodySmall),
                ),
              const SizedBox(height: 8),
              Text('Cette page fonctionne sans connexion Internet.',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner({required this.onCall});

  final void Function(PhoneEntry) onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.berry,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'En cas de symptômes, appelez le 15 (SAMU) ou le 112',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Perte de connaissance, détresse respiratoire : appelez le 15 ou '
            'le 112 sans attendre.',
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final e in emergencyNumbers)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Palette.berry,
                    minimumSize: const Size(150, 56),
                  ),
                  onPressed: () => onCall(e),
                  icon: const Icon(Icons.call),
                  label: Text(e.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({
    required this.entry,
    required this.onCall,
    this.emphasized = false,
  });

  final PhoneEntry entry;
  final VoidCallback onCall;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: emphasized ? Palette.sage : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  SelectableText(entry.display,
                      style: theme.textTheme.titleLarge),
                ],
              ),
            ),
            IconButton.filled(
              tooltip: 'Appeler ${entry.label} ${entry.display}',
              iconSize: 28,
              constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
              onPressed: onCall,
              icon: const Icon(Icons.call),
            ),
          ],
        ),
      ),
    );
  }
}

class _GestureTile extends StatelessWidget {
  const _GestureTile({required this.number, required this.gesture});

  final int number;
  final Gesture gesture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: Palette.forest,
            child: Text('$number',
                style: const TextStyle(color: Palette.cream, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gesture.text, style: theme.textTheme.bodyLarge),
                Text('Source : ${gesture.source}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
