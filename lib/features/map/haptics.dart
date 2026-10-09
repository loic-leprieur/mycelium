import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation.dart';

/// Vibrations de guidage (MAP-9) : à l'approche d'un coin, le téléphone vibre
/// lentement à partir de [hapticStartDistance], de plus en plus vite et de plus
/// en plus fort, jusqu'aux derniers mètres où un signal d'arrivée retentit.
/// Permet de marcher sans regarder l'écran. Fonctionne sans réseau.

/// Distance (m) à partir de laquelle les vibrations commencent.
const hapticStartDistance = 50.0;

/// Distance (m) des « derniers mètres » : cadence maximale, puis signal d'arrivée.
/// Sous cette valeur le GPS (≈ 5 m de précision) ne permet plus de faire mieux.
const hapticFinalDistance = 5.0;

/// Distance (m) au-delà de laquelle le signal d'arrivée est réarmé : évite de
/// le rejouer en boucle quand le GPS oscille autour des derniers mètres.
const hapticRearmDistance = 15.0;

/// Intervalle entre deux vibrations à [hapticStartDistance] (les plus espacées).
const hapticSlowestInterval = Duration(milliseconds: 3000);

/// Intervalle entre deux vibrations dans les derniers mètres (les plus rapprochées).
const hapticFastestInterval = Duration(milliseconds: 300);

/// Pas du minuteur de guidage. Les intervalles sont arrondis à ce pas.
const _tick = Duration(milliseconds: 100);

/// Intervalle entre deux vibrations pour une distance donnée (m), ou `null`
/// au-delà de [hapticStartDistance] (aucune vibration).
///
/// Progression linéaire : 3 s à 50 m, 0,3 s à 5 m et en deçà.
Duration? hapticIntervalFor(double meters) {
  if (meters > hapticStartDistance) return null;
  final t = ((meters - hapticFinalDistance) /
          (hapticStartDistance - hapticFinalDistance))
      .clamp(0.0, 1.0);
  final slow = hapticSlowestInterval.inMicroseconds;
  final fast = hapticFastestInterval.inMicroseconds;
  return Duration(microseconds: (fast + (slow - fast) * t).round());
}

/// Intensité d'une vibration (0 = légère, loin ; 1 = forte, très proche).
double hapticIntensityFor(double meters) {
  final t = ((meters - hapticFinalDistance) /
          (hapticStartDistance - hapticFinalDistance))
      .clamp(0.0, 1.0);
  return 1 - t;
}

/// Moteur de vibration du téléphone. Isolé derrière une interface pour les tests
/// et pour pouvoir changer de mécanisme (ex. plugin dédié sur Android).
abstract class Haptics {
  /// Une impulsion d'intensité [intensity] (0–1).
  Future<void> pulse(double intensity);

  /// Signal d'arrivée : motif distinct, fort et court.
  Future<void> arrival();
}

/// Retour haptique natif de Flutter : Taptic Engine sur iPhone, vibreur sur
/// Android. Sans effet (et sans erreur) sur ordinateur.
class PlatformHaptics implements Haptics {
  const PlatformHaptics();

  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  Future<void> _strong() => _android
      ? HapticFeedback.vibrate()
      : HapticFeedback.heavyImpact();

  @override
  Future<void> pulse(double intensity) async {
    try {
      if (_android) {
        // Android n'a qu'une vibration « standard » vraiment perceptible.
        await HapticFeedback.vibrate();
      } else if (intensity < .34) {
        await HapticFeedback.lightImpact();
      } else if (intensity < .67) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      // Pas de moteur haptique (ordinateur, simulateur) : on ignore.
    }
  }

  @override
  Future<void> arrival() async {
    try {
      // Trois impulsions fortes, nettement plus espacées que les plus rapides
      // du guidage (0,3 s) pour qu'on les distingue.
      for (var i = 0; i < 3; i++) {
        if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 220));
        await _strong();
      }
    } catch (_) {
      // Idem.
    }
  }
}

/// Chef d'orchestre des vibrations : à appeler à chaque changement de distance.
///
/// Un minuteur à pas fixe relit la dernière distance connue. Le GPS n'émet une
/// position que tous les 4 m : les vibrations doivent donc continuer entre deux
/// positions, et leur cadence s'ajuster dès qu'une nouvelle distance arrive.
class GuidanceHaptics {
  GuidanceHaptics(this._haptics);

  final Haptics _haptics;

  Timer? _timer;
  double? _distance;
  Duration _sinceLastPulse = Duration.zero;

  /// Signal d'arrivée déjà joué : silence jusqu'à ce qu'on s'éloigne.
  bool _arrivedPlayed = false;

  /// Vrai quand le minuteur tourne (on est dans la zone de vibration).
  @visibleForTesting
  bool get running => _timer != null;

  /// Met à jour l'état du guidage. [distance] est la distance en ligne droite
  /// au coin (m), `null` tant que la position GPS est inconnue.
  void update({
    required bool active,
    required double? distance,
    required bool enabled,
  }) {
    if (!active || !enabled || distance == null) {
      // Un nouveau guidage doit pouvoir rejouer le signal d'arrivée.
      if (!active) _arrivedPlayed = false;
      _stop();
      return;
    }
    _distance = distance;

    if (distance > hapticRearmDistance) _arrivedPlayed = false;

    if (distance <= hapticFinalDistance) {
      // Derniers mètres : un seul signal d'arrivée, puis silence.
      _stop();
      if (!_arrivedPlayed) {
        _arrivedPlayed = true;
        unawaited(_haptics.arrival());
      }
      return;
    }

    if (_arrivedPlayed) {
      // Entre 5 et 15 m après l'arrivée : on reste silencieux (hystérésis).
      _stop();
      return;
    }

    if (distance > hapticStartDistance) {
      _stop();
      return;
    }

    if (_timer == null) {
      // Entrée dans la zone : première vibration immédiate.
      _sinceLastPulse = Duration.zero;
      _pulse();
      _timer = Timer.periodic(_tick, (_) => _onTick());
    }
  }

  void _onTick() {
    final d = _distance;
    final interval = d == null ? null : hapticIntervalFor(d);
    if (interval == null) {
      _stop();
      return;
    }
    _sinceLastPulse += _tick;
    if (_sinceLastPulse >= interval) {
      _sinceLastPulse = Duration.zero;
      _pulse();
    }
  }

  void _pulse() {
    final d = _distance;
    if (d == null) return;
    unawaited(_haptics.pulse(hapticIntensityFor(d)));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => _stop();
}

final hapticsProvider = Provider<Haptics>((ref) => const PlatformHaptics());

/// Interrupteur « Vibrations de guidage » (actif par défaut).
class HapticsEnabled extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final hapticsEnabledProvider =
    NotifierProvider<HapticsEnabled, bool>(HapticsEnabled.new);

/// Relie le guidage aux vibrations. À lire une fois à la racine de l'application
/// pour que les vibrations continuent quand on change d'onglet.
final guidanceHapticsProvider = Provider<GuidanceHaptics>((ref) {
  final controller = GuidanceHaptics(ref.read(hapticsProvider));

  void sync() {
    final nav = ref.read(navigationProvider);
    controller.update(
      active: nav.active,
      distance: nav.distance,
      enabled: ref.read(hapticsEnabledProvider),
    );
  }

  ref.listen(navigationProvider, (_, _) => sync());
  ref.listen(hapticsEnabledProvider, (_, _) => sync());
  ref.onDispose(controller.dispose);
  sync();
  return controller;
});
