/// Données de la page « Intoxication : que faire ? ». Chaque numéro et chaque
/// consigne vient d'une source officielle citée (cahier des charges §9.1).
/// Ne JAMAIS ajouter un numéro qui n'a pas été relu sur une source officielle.
library;

/// Date de la dernière vérification des numéros et consignes, affichée à l'écran.
const safetyVerifiedOn = '9 octobre 2026';

/// Urgences : SAMU et numéro européen (ANSES et Service-Public.fr).
const emergencyNumbers = <PhoneEntry>[
  PhoneEntry('15', 'Appeler le 15 (SAMU)', '15'),
  PhoneEntry('112', 'Appeler le 112', '112'),
];

/// Numéro national des centres antipoison (ORFILA), publié par
/// centres-antipoison.net et par l'ANSES (04/09/2025).
const nationalPoisonNumber = PhoneEntry(
  '01 45 42 59 59',
  'Numéro national des centres antipoison',
  '0145425959',
);

/// Les huit centres antipoison, 24 h/24 et 7 j/7 : mêmes numéros sur
/// centres-antipoison.net (page mise à jour le 24/09/2026) et Service-Public.fr
/// (10/10/2025).
const poisonCentres = <PhoneEntry>[
  PhoneEntry('02 41 48 21 21', 'Angers', '0241482121'),
  PhoneEntry('05 56 96 40 80', 'Bordeaux', '0556964080'),
  PhoneEntry('08 00 59 59 59', 'Lille', '0800595959'),
  PhoneEntry('04 72 11 69 11', 'Lyon', '0472116911'),
  PhoneEntry('04 91 75 25 25', 'Marseille', '0491752525'),
  PhoneEntry('03 83 22 50 50', 'Nancy', '0383225050'),
  PhoneEntry('01 40 05 48 48', 'Paris', '0140054848'),
  PhoneEntry('05 61 77 74 47', 'Toulouse', '0561777447'),
];

/// Tous les numéros que l'écran a le droit d'afficher.
final verifiedNumbers = <String>{
  for (final e in [...emergencyNumbers, nationalPoisonNumber, ...poisonCentres])
    e.display,
};

class PhoneEntry {
  const PhoneEntry(this.display, this.label, this.dial);

  /// Numéro tel qu'affiché (avec espaces).
  final String display;
  final String label;

  /// Chiffres à composer (`tel:`).
  final String dial;
}

/// Un geste recommandé et la source qui le dit.
class Gesture {
  const Gesture(this.text, this.source);

  final String text;
  final String source;
}

const srcAnses = 'Anses, 04/09/2025';
const srcCap = 'Centres antipoison, centres-antipoison.net';
const srcArs = 'ARS Normandie, 2016';

const gestures = <Gesture>[
  Gesture(
    'Appelez immédiatement un centre antipoison en précisant que vous avez '
    'mangé des champignons.',
    srcAnses,
  ),
  Gesture(
    "Même sans symptôme, si vous avez un doute sur ce qui a été mangé, appelez : "
    "n'attendez pas d'être malade.",
    srcCap,
  ),
  Gesture(
    "Notez l'heure du ou des derniers repas et l'heure d'apparition des "
    'premiers signes.',
    srcAnses,
  ),
  Gesture(
    'Conservez les restes de la cueillette (champignons non consommés) pour '
    "identification. Gardez aussi, si possible, les restes du plat et les "
    'épluchures crues.',
    '$srcAnses ; $srcArs',
  ),
  Gesture(
    'Si vous avez photographié votre récolte avant la cuisson, montrez la photo : '
    'elle aide à choisir le traitement.',
    srcAnses,
  ),
  Gesture(
    'Ne faites pas vomir la personne. Ne lui faites ni manger ni boire : le lait '
    "n'est pas un antidote.",
    srcCap,
  ),
  Gesture(
    "Préparez ce qu'on vous demandera : adresse et téléphone, état de la personne, "
    "ce qui a été mangé et à quelle heure, âge, poids, antécédents et "
    'traitements, premiers soins donnés.',
    srcCap,
  ),
];

/// Délai d'apparition des symptômes (ANSES ; ARS Normandie pour le repère de 6 h).
const onsetDelayAnses =
    "Les symptômes apparaissent le plus souvent quelques heures après le repas, "
    "mais parfois plus de 12 heures après. L'état de la personne peut "
    's\'aggraver rapidement.';

const onsetDelayArs =
    "Un délai long est un signe de gravité : au-delà de 6 heures entre le repas "
    "et les premiers signes digestifs, l'intoxication est potentiellement grave "
    "et nécessite une hospitalisation. Ce repère n'est pas fiable si plusieurs "
    "espèces ou plusieurs repas sont en cause : appelez dans tous les cas, "
    "quel que soit le délai.";

const notMedicalAdvice =
    "Cette application n'est pas un avis médical. Ces consignes résument des "
    "sources officielles et ne remplacent ni un médecin, ni le 15, ni un centre "
    'antipoison.';

const safetySources = <String>[
  'Association des centres antipoison et de toxicovigilance : centres-antipoison.net '
      '(accueil, mise à jour le 24/09/2026 ; « Premiers secours »)',
  'Anses : « Intoxications liées à la cueillette de champignons : restez '
      'vigilants ! », 04/09/2025 (anses.fr)',
  "Service-Public.fr : « Cueillette et consommation de champignons : attention "
      "aux risques d'intoxication ! », 10/10/2025",
  "ARS Normandie : « Prise en charge des intoxications par les champignons en "
      "Normandie », janvier 2016 (guide destiné aux soignants)",
];
