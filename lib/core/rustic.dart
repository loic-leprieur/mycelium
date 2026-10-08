import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'theme.dart';

/// Champignon dessiné (chapeau, lamelles, pied, taches) : logo et illustrations.
class MushroomLogo extends StatelessWidget {
  const MushroomLogo({super.key, this.size = 96, this.cap = Palette.berry});

  final double size;
  final Color cap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _MushroomPainter(cap)),
      );
}

class _MushroomPainter extends CustomPainter {
  _MushroomPainter(this.cap);

  final Color cap;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // Pied
    final stem = Path()
      ..moveTo(w * .38, h * .50)
      ..quadraticBezierTo(w * .34, h * .80, w * .30, h * .94)
      ..quadraticBezierTo(w * .50, h * 1.0, w * .70, h * .94)
      ..quadraticBezierTo(w * .66, h * .80, w * .62, h * .50)
      ..close();
    canvas.drawPath(stem, Paint()..color = Palette.cream);
    canvas.drawPath(
      stem,
      Paint()
        ..color = Palette.bark.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .025,
    );

    // Chapeau
    final capPath = Path()
      ..moveTo(w * .05, h * .55)
      ..quadraticBezierTo(w * .05, h * .08, w * .50, h * .08)
      ..quadraticBezierTo(w * .95, h * .08, w * .95, h * .55)
      ..quadraticBezierTo(w * .50, h * .66, w * .05, h * .55)
      ..close();
    canvas.drawPath(capPath, Paint()..color = cap);
    canvas.drawPath(
      capPath,
      Paint()
        ..color = Palette.forestDark.withValues(alpha: .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .025,
    );

    // Taches
    final dot = Paint()..color = Palette.cream;
    canvas.drawCircle(Offset(w * .30, h * .33), w * .065, dot);
    canvas.drawCircle(Offset(w * .55, h * .24), w * .08, dot);
    canvas.drawCircle(Offset(w * .72, h * .42), w * .055, dot);
    canvas.drawCircle(Offset(w * .45, h * .46), w * .04, dot);
  }

  @override
  bool shouldRepaint(_MushroomPainter old) => old.cap != cap;
}

/// Feuille décorative pour les en-têtes.
class LeafDivider extends StatelessWidget {
  const LeafDivider({super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Divider(color: Palette.bark.withValues(alpha: .25))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.eco, size: 18, color: Palette.moss),
          ),
          Expanded(child: Divider(color: Palette.bark.withValues(alpha: .25))),
        ],
      );
}

/// État vide animé : un champignon qui flotte doucement.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MushroomLogo(size: 92)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: -5, end: 5, duration: 1600.ms, curve: Curves.easeInOut)
                .rotate(begin: -.012, end: .012, duration: 1600.ms),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ).animate().fadeIn(duration: 450.ms).slideY(begin: .08, end: 0),
      ),
    );
  }
}

extension StaggerX on Widget {
  /// Apparition en cascade pour les éléments de liste.
  Widget stagger(int index) => animate(delay: (index.clamp(0, 10) * 55).ms)
      .fadeIn(duration: 380.ms)
      .slideY(begin: .14, end: 0, duration: 420.ms, curve: Curves.easeOutCubic);
}
