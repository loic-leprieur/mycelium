import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/rustic.dart';
import '../../../core/theme.dart';
import '../../../data/database.dart';
import '../geo.dart';
import '../location.dart';
import '../navigation.dart';

/// Point bleu de la position GPS avec un anneau qui pulse.
class UserDot extends StatelessWidget {
  const UserDot({super.key});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2D7DD2);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: blue.withValues(alpha: .25),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .scale(begin: const Offset(.5, .5), end: const Offset(1.25, 1.25), duration: 1800.ms)
            .fadeOut(duration: 1800.ms, curve: Curves.easeIn),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}

/// Épingle d'un coin sur la carte.
class SpotPin extends StatelessWidget {
  const SpotPin({super.key, required this.spot, required this.selected});

  final Spot spot;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = spot.isFavorite ? Palette.chanterelle : Palette.berry;
    final size = selected ? 52.0 : 42.0;
    Widget pin = AnimatedContainer(
      duration: 300.ms,
      curve: Curves.easeOutBack,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Icon(
        spot.isFavorite ? Icons.star : Icons.park,
        color: spot.isFavorite ? Palette.forestDark : Palette.cream,
        size: size * .55,
      ),
    );
    if (selected) {
      pin = pin
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: 0, end: -4, duration: 700.ms, curve: Curves.easeInOut);
    }
    return pin.animate().scale(duration: 420.ms, curve: Curves.elasticOut).fadeIn(duration: 200.ms);
  }
}

/// Bandeau en haut de la carte quand la localisation n'est pas disponible.
class LocationBanner extends StatelessWidget {
  const LocationBanner({super.key, required this.state, required this.onRetry});

  final AsyncValue<LocationState> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final value = state.value;
    String? message;
    VoidCallback? action;
    String actionLabel = 'Réessayer';

    if (state.hasError) {
      message = 'Position indisponible.';
      action = onRetry;
    } else if (value != null) {
      switch (value.status) {
        case LocationStatus.serviceOff:
          message = 'Activez la localisation du téléphone pour centrer la carte sur vous.';
          actionLabel = 'Réglages';
          action = () async {
            await Geolocator.openLocationSettings();
            onRetry();
          };
        case LocationStatus.denied:
          message = 'Autorisez la localisation pour vous voir sur la carte.';
          action = onRetry;
        case LocationStatus.deniedForever:
          message = 'La localisation est refusée pour Mycelium.';
          actionLabel = 'Autoriser';
          action = () async {
            await Geolocator.openAppSettings();
            onRetry();
          };
        case LocationStatus.unavailable:
          message = 'Position indisponible sur cet appareil.';
          action = onRetry;
        case LocationStatus.ok:
          break;
      }
    }
    if (message == null) return const SizedBox.shrink();

    return Card(
      color: Palette.paper,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.location_off, color: Palette.berry),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            TextButton(onPressed: action, child: Text(actionLabel)),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: -.3, end: 0);
  }
}

/// Consigne de guidage en haut de la carte (« Dans 120 m, tournez à gauche »).
class InstructionBanner extends StatelessWidget {
  const InstructionBanner({super.key, required this.nav});

  final NavState nav;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = nav.nextStep;

    IconData icon = Icons.hourglass_top;
    String title = 'Calcul de l\'itinéraire…';
    String? subtitle;

    if (nav.arrived) {
      icon = Icons.flag_circle;
      title = 'Vous êtes arrivé !';
      subtitle = nav.target?.name;
    } else if (nav.route == null && !nav.loading) {
      icon = Icons.gps_not_fixed;
      title = 'En attente de votre position…';
    } else if (step != null) {
      icon = step.icon;
      final d = nav.distanceToNext;
      title = step.instruction;
      subtitle = d == null ? null : 'Dans ${formatDistance(d)}';
    }

    return Material(
      color: Palette.forest,
      elevation: 6,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: 300.ms,
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(icon, key: ValueKey(icon), color: Palette.chanterelle, size: 40),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Palette.sage),
                    ),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Palette.cream,
                      fontSize: 19,
                    ),
                  ),
                ],
              ),
            ),
            if (nav.rerouting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Palette.cream),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: -.4, end: 0, curve: Curves.easeOutCubic);
  }
}

/// Résumé du trajet affiché dans le panneau : distance, durée, arrêt.
class NavigationSummary extends StatelessWidget {
  const NavigationSummary({
    super.key,
    required this.nav,
    required this.onStop,
    required this.onEdit,
  });

  final NavState nav;
  final VoidCallback onStop;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spot = nav.target!;
    final remaining = nav.remaining ?? nav.route?.distance;
    final seconds = nav.remainingSeconds ?? nav.route?.duration;

    return Card(
      color: Palette.sage.withValues(alpha: .55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk, color: Palette.forestDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    spot.name,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Modifier le coin',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (nav.loading)
              const LinearProgressIndicator()
            else if (remaining != null)
              Wrap(
                spacing: 28,
                runSpacing: 6,
                children: [
                  _Figure(label: 'Distance', value: formatDistance(remaining)),
                  if (seconds != null)
                    _Figure(label: 'À pied', value: formatDuration(seconds)),
                ],
              ),
            if (nav.route?.isStraightLine ?? false)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Tracé direct : l\'itinéraire par les chemins n\'est pas disponible '
                  '(pas de connexion). Suivez la direction indiquée.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Palette.berry),
                onPressed: onStop,
                icon: const Icon(Icons.close),
                label: Text(nav.arrived ? 'Terminer' : 'Arrêter le guidage'),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: .12, end: 0);
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        AnimatedSwitcher(
          duration: 250.ms,
          child: Text(
            value,
            key: ValueKey(value),
            style: theme.textTheme.headlineSmall?.copyWith(fontSize: 26),
          ),
        ),
      ],
    );
  }
}

/// Ligne de la liste des coins.
class SpotTile extends StatelessWidget {
  const SpotTile({
    super.key,
    required this.spot,
    required this.distance,
    required this.selected,
    required this.onTap,
    required this.onEdit,
  });

  final Spot spot;
  final double? distance;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (spot.forestType != null) spot.forestType!,
      if (distance != null) 'à ${formatDistance(distance!)}',
    ].join(' · ');

    return AnimatedContainer(
      duration: 250.ms,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? Palette.sage.withValues(alpha: .6) : Palette.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? Palette.forest : Palette.bark.withValues(alpha: .18),
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        minTileHeight: 68,
        leading: CircleAvatar(
          backgroundColor: spot.isFavorite ? Palette.chanterelle : Palette.berry,
          child: Icon(
            spot.isFavorite ? Icons.star : Icons.park,
            color: spot.isFavorite ? Palette.forestDark : Palette.cream,
          ),
        ),
        title: Text(spot.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_walk, color: Palette.forest),
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Contenu vide du panneau des coins.
class NoSpots extends StatelessWidget {
  const NoSpots({super.key, required this.onAddHere, required this.onDemo});

  final VoidCallback onAddHere;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) => EmptyState(
        title: 'Aucun coin enregistré',
        message: 'Marquez l\'endroit où vous êtes, ou appuyez longuement sur la carte.',
        action: Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: onAddHere,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Ajouter ici'),
            ),
            OutlinedButton.icon(
              onPressed: onDemo,
              icon: const Icon(Icons.explore),
              label: const Text('Coins d\'exemple'),
            ),
          ],
        ),
      );
}
