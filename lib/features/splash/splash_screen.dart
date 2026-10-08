import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/rustic.dart';
import '../../core/theme.dart';

/// Écran d'accueil animé : le champignon pousse, puis on passe à la carte.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2300), () {
      if (mounted) context.go('/map');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: GestureDetector(
        onTap: () => context.go('/map'),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Palette.forestDark, Palette.forest, Palette.moss],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Feuilles qui dérivent doucement.
              for (var i = 0; i < 7; i++)
                Positioned(
                  left: 20.0 + i * 55 % 320,
                  top: 80.0 + (i * 97) % 520,
                  child: Icon(
                    Icons.eco,
                    size: 22.0 + (i % 3) * 8,
                    color: Palette.sage.withValues(alpha: .22),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true), delay: (i * 220).ms)
                      .moveY(begin: -10, end: 14, duration: (2200 + i * 150).ms, curve: Curves.easeInOut)
                      .rotate(begin: -.05, end: .08, duration: (2600 + i * 100).ms),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MorelLogo(size: 170)
                      .animate()
                      .scale(
                        begin: const Offset(.2, .2),
                        end: const Offset(1, 1),
                        duration: 900.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 300.ms),
                  const SizedBox(height: 26),
                  Text(
                    'Mycelium',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Palette.cream,
                      fontSize: 40,
                      letterSpacing: 1.5,
                    ),
                  ).animate(delay: 500.ms).fadeIn(duration: 600.ms).slideY(begin: .4, end: 0),
                  const SizedBox(height: 8),
                  Text(
                    appSlogan,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Palette.sage,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w400,
                    ),
                  ).animate(delay: 900.ms).fadeIn(duration: 600.ms),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
