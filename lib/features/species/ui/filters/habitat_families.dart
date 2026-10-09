import 'french_text.dart';

/// Grandes familles de milieux, pour filtrer l'encyclopédie par habitat. Elles
/// reprennent les types de forêt proposés pour un coin (feuillus, conifères,
/// mixte) et y ajoutent les milieux que le catalogue mentionne.
enum HabitatFamily {
  feuillus('Feuillus'),
  coniferes('Conifères'),

  /// Espèces qui poussent aussi bien sous feuillus que sous conifères.
  mixte('Forêt mixte'),
  lisieres('Lisières et milieux ouverts'),
  boisMort('Bois mort'),

  /// Un habitat est renseigné, mais aucun mot connu n'y figure.
  autre('Autre milieu');

  const HabitatFamily(this.label);

  final String label;
}

// Les motifs s'appliquent au texte sans accents ni majuscules (voir foldAccents).

/// Feuillus : le mot lui-même, une essence (hêtre, chêne…) ou son bois (hêtraie…).
final _broadleaf = RegExp(
  r'\b(feuillus?|hetr(es?|aies?)|chen(es?|aies?)|fren(es?|aies?)|bouleaux?|'
  r'betulaies?|charm(es?|aies?)|chataign(iers?|eraies?)|tilleuls?|erables?|'
  r'aulnes?|saules?|peupliers?|noisetiers?|ormes?|robiniers?|platanes?|trembles?)\b',
);

/// Conifères : le mot lui-même, une essence (épicéa, sapin, pin…) ou son bois.
final _conifer = RegExp(
  r'\b(coniferes?|epiceas?|sapins?|pins?|melezes?|melezins?|douglas|cedres?|'
  r'pinedes?|pessieres?|sapinieres?)\b',
);

final _mixed = RegExp(r'\b(mixtes?|melangees?)\b');

final _edge = RegExp(
  r'\b(lisieres?|clairieres?|vergers?|perturbees?|haies?|talus|friches?|'
  r'bords? d[eu]s? (chemins?|routes?|sentiers?))\b',
);

final _deadWood = RegExp(r'\b(bois (morts?|pourris?)|arbres? morts?|souches?)\b');

/// Familles de milieux d'un habitat écrit en texte libre. Une espèce peut en avoir
/// plusieurs (« Feuillus et conifères » : feuillus, conifères ET forêt mixte).
///
/// Le texte est lu par mots-clés, sans comprendre les négations. Résultat :
/// - vide si l'habitat n'est pas renseigné (`null` ou blanc) ;
/// - jamais vide sinon : un habitat inconnu du lexique tombe dans
///   [HabitatFamily.autre], pour que la fiche reste trouvable.
Set<HabitatFamily> habitatFamilies(String? habitat) {
  if (habitat == null || habitat.trim().isEmpty) return const {};
  final text = foldAccents(habitat);
  final feuillus = _broadleaf.hasMatch(text);
  final coniferes = _conifer.hasMatch(text);
  final families = <HabitatFamily>{
    if (feuillus) HabitatFamily.feuillus,
    if (coniferes) HabitatFamily.coniferes,
    if ((feuillus && coniferes) || _mixed.hasMatch(text)) HabitatFamily.mixte,
    if (_edge.hasMatch(text)) HabitatFamily.lisieres,
    if (_deadWood.hasMatch(text)) HabitatFamily.boisMort,
  };
  return families.isEmpty ? const {HabitatFamily.autre} : families;
}
