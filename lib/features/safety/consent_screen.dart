import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import 'consent.dart';

/// Consentement explicite au premier lancement : l'application est une aide, non
/// fiable à 100 %. L'acceptation est journalisée (cahier des charges §9.1).
///
/// Aucune autre sortie que l'acceptation : pas de bouton retour, retour système
/// bloqué. Route : `/consent`.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _checked = false;
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await recordConsent(ref.read(databaseProvider));
      ref.invalidate(consentAcceptedProvider);
      if (mounted) context.go('/map');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'enregistrer votre accord. Réessayez."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Avant de commencer'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      children: [
                        Text(consentTitle, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 14),
                        for (final point in consentPoints)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 3, right: 10),
                                  child: Icon(
                                    Icons.circle,
                                    size: 9,
                                    color: Palette.berry,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    point,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    decoration: BoxDecoration(
                      color: Palette.paper,
                      border: Border(
                        top: BorderSide(
                          color: Palette.bark.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Material(
                          type: MaterialType.transparency,
                          child: CheckboxListTile(
                            value: _checked,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _checked = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(consentCheckboxLabel),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(60),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: (_checked && !_busy) ? _accept : null,
                          child: const Text(consentButtonLabel),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
