import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Affiche le fond de carte en ligne. Désactivé par les tests automatisés pour
/// ne dépendre ni du réseau ni du serveur de tuiles.
final tilesEnabledProvider = Provider<bool>((ref) => true);
