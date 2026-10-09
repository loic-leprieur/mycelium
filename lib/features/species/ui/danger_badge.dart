import 'package:flutter/material.dart';

import '../domain/species.dart';

/// Pastille « MORTEL » ou « TOXIQUE », à placer sur toute espèce dangereuse. Le
/// danger est écrit en toutes lettres (pas seulement une couleur) et le texte est
/// noir ou blanc selon le fond, pour rester lisible en plein soleil.
class DangerBadge extends StatelessWidget {
  const DangerBadge({super.key, required this.edibility});

  final Edibility edibility;

  @override
  Widget build(BuildContext context) {
    final color = edibility.color;
    // 0,179 : seuil où le noir et le blanc contrastent autant l'un que l'autre.
    final onColor = color.computeLuminance() > 0.179 ? Colors.black : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(edibility.icon, size: 16, color: onColor),
            const SizedBox(width: 4),
            Text(
              edibility.label.toUpperCase(),
              style: TextStyle(
                color: onColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
