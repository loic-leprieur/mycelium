import '../domain/species.dart';

/// Catalogue de démarrage, écrit en dur.
///
/// CONTENU PROVISOIRE : à relire et valider avec un connaisseur local avant
/// toute diffusion (cahier des charges §4.4, §9). Rédaction originale, sans
/// texte ni photo de tiers, pour ne pas dépendre de licences.
const List<Species> speciesSeed = [
  // --- Comestibles : bolets ---
  Species(
    id: 'cepe-de-bordeaux',
    commonName: 'Cèpe de Bordeaux',
    scientificName: 'Boletus edulis',
    family: 'Boletaceae',
    edibility: Edibility.good,
    description:
        'Chapeau brun à brun roux, lisse, chair blanche qui ne change pas de couleur. '
        'Pied trapu, renflé, blanc à brunâtre, orné d\'un fin réseau blanc au sommet. '
        'Tubes blancs puis jaune verdâtre sous le chapeau.',
    habitat: 'Feuillus et conifères (épicéas, sapins, hêtres, chênes).',
    seasonStart: 6,
    seasonEnd: 11,
    confusions: [
      Confusion(
        name: 'Bolet amer',
        speciesId: 'bolet-amer',
        note: 'Tubes qui rosissent, réseau brun sombre sur le pied, goût très amer.',
      ),
      Confusion(
        name: 'Bolet de Satan',
        speciesId: 'bolet-de-satan',
        note: 'Pied rouge à réseau rouge, chair qui bleuit à la coupe. Toxique.',
      ),
    ],
  ),
  Species(
    id: 'cepe-d-ete',
    commonName: 'Cèpe d\'été',
    scientificName: 'Boletus reticulatus',
    family: 'Boletaceae',
    edibility: Edibility.good,
    description:
        'Chapeau brun clair, souvent craquelé par temps sec. Pied avec un réseau '
        'blanc couvrant une grande partie de sa hauteur.',
    habitat: 'Feuillus, surtout chênes et hêtres.',
    seasonStart: 5,
    seasonEnd: 9,
    confusions: [
      Confusion(
        name: 'Bolet amer',
        speciesId: 'bolet-amer',
        note: 'Tubes qui rosissent, réseau brun sur le pied, goût très amer.',
      ),
    ],
  ),
  Species(
    id: 'cepe-des-pins',
    commonName: 'Cèpe des pins',
    scientificName: 'Boletus pinophilus',
    family: 'Boletaceae',
    edibility: Edibility.good,
    description:
        'Chapeau brun rouge à brun acajou, pied trapu brun rougeâtre avec un '
        'réseau de même teinte.',
    habitat: 'Conifères, parfois feuillus acides.',
    seasonStart: 6,
    seasonEnd: 11,
    confusions: [
      Confusion(
        name: 'Bolet amer',
        speciesId: 'bolet-amer',
        note: 'Tubes qui rosissent, goût très amer.',
      ),
    ],
  ),
  Species(
    id: 'bolet-bai',
    commonName: 'Bolet bai',
    scientificName: 'Imleria badia',
    family: 'Boletaceae',
    edibility: Edibility.good,
    description:
        'Chapeau brun marron, lisse, un peu visqueux par temps humide. Tubes '
        'jaune pâle qui bleuissent au toucher. Pied sans réseau.',
    habitat: 'Conifères surtout, parfois feuillus, sols acides.',
    seasonStart: 8,
    seasonEnd: 11,
    confusions: [
      Confusion(
        name: 'Bolet amer',
        speciesId: 'bolet-amer',
        note: 'Tubes blancs puis rosés, pied à réseau brun, goût amer.',
      ),
    ],
  ),
  Species(
    id: 'bolet-a-pied-rouge',
    commonName: 'Bolet à pied rouge',
    scientificName: 'Neoboletus luridiformis',
    family: 'Boletaceae',
    edibility: Edibility.conditional,
    edibilityNote:
        'Comestible uniquement bien cuit : toxique cru ou peu cuit.',
    description:
        'Chapeau brun olivâtre, tubes jaunes à pores rouge orangé, chair jaune '
        'qui bleuit fortement à la coupe. Pied jaune ponctué de rouge.',
    habitat: 'Feuillus et conifères.',
    seasonStart: 6,
    seasonEnd: 10,
    confusions: [
      Confusion(
        name: 'Bolet de Satan',
        speciesId: 'bolet-de-satan',
        note:
            'Chapeau pâle blanchâtre, pied à réseau rouge, chair bleuissante. Toxique.',
      ),
    ],
  ),
  Species(
    id: 'bolet-granule',
    commonName: 'Bolet granulé',
    scientificName: 'Suillus granulatus',
    family: 'Suillaceae',
    edibility: Edibility.good,
    edibilityNote: 'Qualité gustative moyenne ; retirer la cuticule visqueuse.',
    description:
        'Chapeau jaune brun, visqueux. Pores jaunes laissant perler des gouttelettes '
        'laiteuses. Pied sans anneau, granuleux dans le haut.',
    habitat: 'Pins.',
    seasonStart: 7,
    seasonEnd: 11,
  ),

  // --- Comestibles : chanterelles et assimilés ---
  Species(
    id: 'girolle',
    commonName: 'Girolle',
    scientificName: 'Cantharellus cibarius',
    family: 'Cantharellaceae',
    edibility: Edibility.good,
    description:
        'Entièrement jaune d\'œuf. Dessous formé de plis ramifiés (fausses lames) '
        'décurrents sur le pied. Odeur fruitée d\'abricot. Chair blanche, fibreuse.',
    habitat: 'Feuillus et conifères, sols acides, mousse.',
    seasonStart: 6,
    seasonEnd: 10,
    confusions: [
      Confusion(
        name: 'Fausse girolle',
        speciesId: 'fausse-girolle',
        note: 'Orange vif, vraies lames fines et serrées, chair molle, sans odeur d\'abricot.',
      ),
      Confusion(
        name: 'Clitocybes orangés poussant sur bois',
        note: 'Toxiques, vraies lames, poussent en touffes sur le bois.',
      ),
    ],
  ),
  Species(
    id: 'chanterelle-en-tube',
    commonName: 'Chanterelle en tube',
    scientificName: 'Craterellus tubaeformis',
    family: 'Cantharellaceae',
    edibility: Edibility.good,
    description:
        'Chapeau brun jaunâtre en entonnoir, pied creux jaune orangé, dessous à plis '
        'grisâtres. Pousse en groupes dans la mousse.',
    habitat: 'Conifères, sols humides et moussus.',
    seasonStart: 9,
    seasonEnd: 12,
  ),
  Species(
    id: 'chanterelle-cendree',
    commonName: 'Chanterelle cendrée',
    scientificName: 'Craterellus cinereus',
    family: 'Cantharellaceae',
    edibility: Edibility.good,
    description:
        'Petit entonnoir gris brun à noirâtre, dessous à plis gris cendré. '
        'Proche de la trompette de la mort.',
    habitat: 'Feuillus, sols calcaires ou riches.',
    seasonStart: 8,
    seasonEnd: 11,
  ),
  Species(
    id: 'trompette-de-la-mort',
    commonName: 'Trompette de la mort',
    scientificName: 'Craterellus cornucopioides',
    family: 'Cantharellaceae',
    edibility: Edibility.good,
    description:
        'En forme de trompette creuse, brun noir à gris, surface extérieure '
        'lisse à légèrement ridée. Odeur agréable de fruits secs.',
    habitat: 'Feuillus, souvent hêtres et chênes, sols humides.',
    seasonStart: 8,
    seasonEnd: 11,
  ),

  // --- Comestibles : pied-de-mouton, morilles ---
  Species(
    id: 'pied-de-mouton',
    commonName: 'Pied-de-mouton',
    scientificName: 'Hydnum repandum',
    family: 'Hydnaceae',
    edibility: Edibility.good,
    description:
        'Chapeau crème à orangé, irrégulier. Dessous couvert de petits aiguillons '
        'blancs, fragiles, qui se détachent facilement (pas de lames ni de tubes).',
    habitat: 'Feuillus et conifères.',
    seasonStart: 8,
    seasonEnd: 11,
  ),
  Species(
    id: 'morille',
    commonName: 'Morille',
    scientificName: 'Morchella spp.',
    family: 'Morchellaceae',
    edibility: Edibility.conditional,
    edibilityNote: 'Toxique crue : toujours bien cuite. Ne jamais consommer en excès.',
    description:
        'Chapeau creusé d\'alvéoles, entièrement creux, fixé directement au pied '
        'creux (coupée en deux, tout est creux).',
    habitat: 'Lisières, zones perturbées, frênes, vergers, sols calcaires.',
    seasonStart: 3,
    seasonEnd: 5,
    confusions: [
      Confusion(
        name: 'Fausse morille (gyromitre)',
        speciesId: 'gyromitre',
        note:
            'Chapeau cérébriforme (plissé, non alvéolé), chair cotonneuse à la coupe. Toxique, potentiellement mortelle.',
      ),
    ],
  ),

  // --- Toxiques et mortels ---
  Species(
    id: 'amanite-phalloide',
    commonName: 'Amanite phalloïde',
    scientificName: 'Amanita phalloides',
    family: 'Amanitaceae',
    edibility: Edibility.deadly,
    description:
        'Chapeau vert olive à jaunâtre, lames blanches, anneau, pied bulbeux dans une '
        'volve (sac) à la base. Responsable de la majorité des intoxications mortelles.',
    habitat: 'Feuillus, surtout chênes et hêtres.',
    seasonStart: 7,
    seasonEnd: 11,
    confusions: [
      Confusion(
        name: 'Russules vertes, agarics',
        note: 'Toujours vérifier la base du pied : déterrer entièrement le champignon.',
      ),
    ],
  ),
  Species(
    id: 'amanite-panthere',
    commonName: 'Amanite panthère',
    scientificName: 'Amanita pantherina',
    family: 'Amanitaceae',
    edibility: Edibility.toxic,
    description:
        'Chapeau brun parsemé de verrues blanches, lames blanches, anneau, bulbe '
        'à la base avec bourrelets.',
    habitat: 'Feuillus et conifères.',
    seasonStart: 6,
    seasonEnd: 11,
  ),
  Species(
    id: 'amanite-tue-mouches',
    commonName: 'Amanite tue-mouches',
    scientificName: 'Amanita muscaria',
    family: 'Amanitaceae',
    edibility: Edibility.toxic,
    description:
        'Chapeau rouge vif couvert de verrues blanches, lames blanches, anneau, '
        'base du pied bulbeuse avec bourrelets.',
    habitat: 'Bouleaux, épicéas, sols acides.',
    seasonStart: 7,
    seasonEnd: 11,
  ),
  Species(
    id: 'galere-marginee',
    commonName: 'Galère marginée',
    scientificName: 'Galerina marginata',
    family: 'Hymenogastraceae',
    edibility: Edibility.deadly,
    description:
        'Petit champignon brun miel poussant en touffes sur le bois mort, avec un '
        'anneau fragile. Contient les mêmes toxines que l\'amanite phalloïde.',
    habitat: 'Bois mort de conifères et de feuillus.',
    seasonStart: 5,
    seasonEnd: 11,
    confusions: [
      Confusion(
        name: 'Pholiote changeante, collybies sur bois',
        note: 'Ne jamais cueillir de petits champignons bruns poussant sur le bois.',
      ),
    ],
  ),
  Species(
    id: 'cortinaire-des-montagnes',
    commonName: 'Cortinaire des montagnes',
    scientificName: 'Cortinarius rubellus',
    family: 'Cortinariaceae',
    edibility: Edibility.deadly,
    edibilityNote:
        'Toxine à effet retardé (plusieurs jours) : atteinte des reins. Souvent diagnostiquée trop tard.',
    description:
        'Chapeau conique orange roux, lames brun rouille, cortine (voile fin) '
        'sur le pied. Forte odeur de radis.',
    habitat: 'Conifères, sols acides et moussus, en montagne.',
    seasonStart: 8,
    seasonEnd: 11,
  ),
  Species(
    id: 'gyromitre',
    commonName: 'Fausse morille (gyromitre)',
    scientificName: 'Gyromitra esculenta',
    family: 'Discinaceae',
    edibility: Edibility.deadly,
    edibilityNote: 'Toxique, même cuite : potentiellement mortelle.',
    description:
        'Chapeau brun rouge sombre, cérébriforme (plis comme un cerveau), '
        'non alvéolé. Pied court, chair cotonneuse, non creuse en totalité.',
    habitat: 'Conifères, sols sableux, au printemps.',
    seasonStart: 3,
    seasonEnd: 6,
    confusions: [
      Confusion(
        name: 'Morille',
        speciesId: 'morille',
        note: 'Chapeau alvéolé et entièrement creux chez la vraie morille.',
      ),
    ],
  ),
  Species(
    id: 'bolet-de-satan',
    commonName: 'Bolet de Satan',
    scientificName: 'Rubroboletus satanas',
    family: 'Boletaceae',
    edibility: Edibility.toxic,
    description:
        'Chapeau blanchâtre à gris, pied renflé jaune orangé à réseau rouge vif, '
        'pores rouges, chair qui bleuit. Odeur désagréable avec l\'âge.',
    habitat: 'Feuillus, sols calcaires et chauds ; rare.',
    seasonStart: 7,
    seasonEnd: 9,
    confusions: [
      Confusion(
        name: 'Cèpes et bolets à pied rouge',
        speciesId: 'bolet-a-pied-rouge',
        note: 'Chapeau pâle, réseau rouge sur le pied : ne pas cueillir en cas de doute.',
      ),
    ],
  ),
  Species(
    id: 'bolet-amer',
    commonName: 'Bolet amer',
    scientificName: 'Tylopilus felleus',
    family: 'Boletaceae',
    edibility: Edibility.inedible,
    edibilityNote: 'Très amer : un seul exemplaire gâche tout un plat.',
    description:
        'Ressemble à un cèpe, mais les tubes virent au rose et le pied porte un '
        'réseau brun sombre.',
    habitat: 'Conifères, sols acides.',
    seasonStart: 7,
    seasonEnd: 10,
    confusions: [
      Confusion(
        name: 'Cèpe de Bordeaux',
        speciesId: 'cepe-de-bordeaux',
        note: 'Tubes blancs puis jaunes, réseau blanc au sommet du pied.',
      ),
    ],
  ),
  Species(
    id: 'fausse-girolle',
    commonName: 'Fausse girolle',
    scientificName: 'Hygrophoropsis aurantiaca',
    family: 'Hygrophoropsidaceae',
    edibility: Edibility.inedible,
    description:
        'Orange vif, vraies lames fines et serrées (la girolle a des plis épais), '
        'chair molle, sans odeur d\'abricot.',
    habitat: 'Conifères, sols pauvres.',
    seasonStart: 8,
    seasonEnd: 11,
    confusions: [
      Confusion(
        name: 'Girolle',
        speciesId: 'girolle',
        note: 'Plis épais et ramifiés, chair ferme, odeur d\'abricot.',
      ),
    ],
  ),
];
