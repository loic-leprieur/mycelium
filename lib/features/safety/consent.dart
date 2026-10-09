import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

/// Version du texte de consentement. À INCRÉMENTER à chaque modification du texte
/// ci-dessous : le consentement est alors redemandé à tout le monde (§9.1).
const consentVersion = 1;

const consentKeyAcceptedAt = 'consent_accepted_at';
const consentKeyVersion = 'consent_version';

const consentTitle = 'Mycelium est une aide, pas une garantie.';

/// Les points affichés sur l'écran de consentement.
const consentPoints = <String>[
  "L'identification par photo n'est pas fiable à 100 %. Elle peut se tromper, "
      'surtout entre des espèces qui se ressemblent.',
  'Ne consommez jamais un champignon sur la seule base de cette application.',
  'Faites contrôler votre récolte par un pharmacien ou une association '
      'mycologique avant toute consommation.',
  'Un champignon mortel peut ressembler beaucoup à une espèce que vous '
      'connaissez bien.',
  'Un malaise après un repas de champignons : appelez le 15 ou le 112, ou un '
      'centre antipoison. La page « Intoxication : que faire ? » (dans les '
      'Réglages) donne les numéros, même sans réseau.',
  "Cette application n'est pas un avis médical.",
  'Votre accord est enregistré uniquement sur ce téléphone (date et version '
      'du texte). Rien n\'est envoyé.',
];

const consentCheckboxLabel =
    'Je comprends que Mycelium peut se tromper et que je ne dois jamais '
    'consommer un champignon sans l\'avoir fait contrôler par un pharmacien '
    'ou une association mycologique.';

const consentButtonLabel = "J'ai compris et j'accepte";

/// Le consentement en vigueur (date ET version courante) est-il enregistré ?
/// Toute valeur absente, illisible ou d'une autre version : on redemande.
Future<bool> hasValidConsent(AppDatabase db) async {
  final at = await db.metaValue(consentKeyAcceptedAt);
  final version = await db.metaValue(consentKeyVersion);
  if (at == null || DateTime.tryParse(at) == null) return false;
  return int.tryParse(version ?? '') == consentVersion;
}

/// Journalise l'acceptation (date ISO en UTC + version du texte), d'un seul bloc.
Future<void> recordConsent(AppDatabase db, {DateTime? now}) =>
    db.transaction(() async {
      await db.setMeta(
        consentKeyAcceptedAt,
        (now ?? DateTime.now()).toUtc().toIso8601String(),
      );
      await db.setMeta(consentKeyVersion, '$consentVersion');
    });

/// Le consentement en vigueur a-t-il été accepté ? Relu à chaque
/// invalidation (l'écran d'accueil le rafraîchit à chaque démarrage).
final consentAcceptedProvider = FutureProvider<bool>(
  (ref) => hasValidConsent(ref.watch(databaseProvider)),
);
