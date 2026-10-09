import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Texte de l'avertissement obligatoire (RM-4, cahier des charges §9).
const safetyDisclaimer =
    'Cette identification est une aide et peut être erronée. Ne consommez '
    'jamais un champignon sur la seule base de cette application : faites-le '
    'contrôler par un pharmacien ou une association mycologique.';

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    required this.color,
    this.icon = Icons.warning_amber_rounded,
    this.title,
    this.footer,
  });

  final String message;
  final String? title;

  /// Élément facultatif sous le message (lien, bouton).
  final Widget? footer;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final onColor = ThemeData.estimateBrightnessForColor(color) ==
            Brightness.dark
        ? Colors.white
        : Colors.black87;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: onColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: onColor, fontWeight: FontWeight.bold),
                  ),
                Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: onColor),
                ),
                ?footer,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Avertissement de sécurité standard, affiché sur chaque résultat d'identification.
class SafetyDisclaimer extends StatelessWidget {
  const SafetyDisclaimer({super.key});

  @override
  Widget build(BuildContext context) => InfoBanner(
        message: safetyDisclaimer,
        color: const Color(0xFFFFE082),
        footer: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
            onPressed: () => context.push('/settings/safety'),
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text("En cas d'intoxication"),
          ),
        ),
      );
}

/// Pastille de comestibilité réutilisable.
class EdibilityChip extends StatelessWidget {
  const EdibilityChip({super.key, required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(label),
        side: BorderSide(color: color),
        backgroundColor: color.withValues(alpha: 0.10),
      );
}
