/// Types de champignons regroupant plusieurs espèces : ce sont eux qu'on filtre
/// pour retrouver « les coins à cèpes », « à chanterelles », « à morilles »…
enum MushroomGroup {
  cepes('Cèpes'),
  chanterelles('Chanterelles'),
  morilles('Morilles'),
  trompettes('Trompettes'),
  piedsDeMouton('Pieds-de-mouton'),
  bolets('Autres bolets'),
  amanites('Amanites'),
  autres('Autres espèces');

  const MushroomGroup(this.label);

  final String label;
}

/// Groupe de chaque espèce du catalogue intégré. Une espèce absente d'ici (par
/// exemple une espèce ajoutée par l'utilisateur) tombe dans [MushroomGroup.autres].
/// Un test vérifie que tout le catalogue est classé.
const speciesGroups = <String, MushroomGroup>{
  'cepe-de-bordeaux': MushroomGroup.cepes,
  'cepe-d-ete': MushroomGroup.cepes,
  'cepe-des-pins': MushroomGroup.cepes,
  'girolle': MushroomGroup.chanterelles,
  'chanterelle-en-tube': MushroomGroup.chanterelles,
  'chanterelle-cendree': MushroomGroup.chanterelles,
  'morille': MushroomGroup.morilles,
  'trompette-de-la-mort': MushroomGroup.trompettes,
  'pied-de-mouton': MushroomGroup.piedsDeMouton,
  'bolet-bai': MushroomGroup.bolets,
  'bolet-a-pied-rouge': MushroomGroup.bolets,
  'bolet-granule': MushroomGroup.bolets,
  'bolet-de-satan': MushroomGroup.bolets,
  'bolet-amer': MushroomGroup.bolets,
  'amanite-phalloide': MushroomGroup.amanites,
  'amanite-panthere': MushroomGroup.amanites,
  'amanite-tue-mouches': MushroomGroup.amanites,
  'galere-marginee': MushroomGroup.autres,
  'cortinaire-des-montagnes': MushroomGroup.autres,
  'gyromitre': MushroomGroup.autres,
  'fausse-girolle': MushroomGroup.autres,
};

MushroomGroup groupOfSpecies(String speciesId) =>
    speciesGroups[speciesId] ?? MushroomGroup.autres;

/// Groupes représentés par une liste d'espèces.
Set<MushroomGroup> groupsOfSpecies(Iterable<String> speciesIds) =>
    {for (final id in speciesIds) groupOfSpecies(id)};

/// Vrai si [speciesIds] contient une espèce d'au moins un des [groups]
/// (un filtre vide laisse tout passer).
bool matchesGroups(Iterable<String> speciesIds, Set<MushroomGroup> groups) =>
    groups.isEmpty || groupsOfSpecies(speciesIds).any(groups.contains);
