# Mycelium — Cahier des charges V0.1

> Statut : **brouillon V0.1** — 8 octobre 2026
> Les points marqués **[À VALIDER]** sont des hypothèses à confirmer. Les points marqués **[À VÉRIFIER]** sont des éléments juridiques/techniques à contrôler avant tout engagement (licences, réglementation).

---

## 1. Vision du produit

> **Un assistant de cueillette de champignons, utilisable en forêt sans réseau, qui permet d'identifier un champignon par photo, de mémoriser ses coins et ses sorties, et de consulter des informations de sécurité.**

### 1.1 Principes directeurs

1. **Local-first / hors connexion par défaut.** Tout ce qui est utile en forêt fonctionne sans réseau : carte, GPS, photo, identification, fiches, carnet.
2. **Confidentialité absolue des coins.** Les emplacements restent sur l'appareil de l'utilisateur. Aucune dimension communautaire, aucun partage public. Un coin à champignons est un secret.
3. **La sécurité avant tout.** L'identification par IA est une *aide*, jamais une décision alimentaire. L'application ne dit jamais « vous pouvez le manger ».
4. **Simplicité.** Pensée d'abord pour un amateur passionné (le père de l'auteur), pas pour un mycologue expert ni pour un débutant total.
5. **Maîtrise des coûts et des licences.** Aucune dépendance bloquante à une API payante à l'usage ou à une licence incompatible avec une commercialisation.

### 1.2 Périmètre : ce qui est explicitement **hors** périmètre

| Hors périmètre | Raison |
|---|---|
| Réseau social, observations publiques, partage entre amis | Décision produit : pas de dimension communautaire |
| Carte des observations d'autres utilisateurs | Décision produit : uniquement ses propres emplacements |
| Carte de « zones favorables » issue de données tierces | Idem (peut revenir comme *conseil météo* en V2, pas comme carte) |
| Modération de contenu | Conséquence de l'absence de contenu utilisateur public |

Conséquence importante : **pas de modération, pas de RGPD « communautaire », surface d'attaque et coûts serveur très réduits.**

---

## 2. Contexte et objectifs

### 2.1 Objectifs

| # | Objectif | Horizon |
|---|---|---|
| O1 | Fournir à un cueilleur amateur un outil fiable pour mémoriser ses coins et ses sorties | V1 |
| O2 | Identifier un champignon par photo, **hors connexion** | V1 |
| O3 | Pouvoir être publié sur les stores si la maturité, les coûts et les licences le permettent | Après V1 |

### 2.2 Phasage du projet

1. **Phase « usage familial »** — l'application est installée sur le téléphone du père (et de proches). Pas de contrainte commerciale, mais on **construit dès le départ** en respectant les licences et la sécurité, pour ne rien avoir à refaire.
2. **Phase « publication »** — décision go/no-go conditionnée à : qualité de l'identification mesurée, licences validées, risque juridique évalué, coût d'exploitation connu (voir §14).

---

## 3. Utilisateurs cibles

La question de la cible n'ayant pas été tranchée, hypothèse de travail **[À VALIDER]** :

**Cible principale : cueilleur amateur régulier, francophone, dans les Vosges et en Alsace**, connaissant déjà quelques espèces courantes (cèpes, girolles, pieds-de-mouton…), souhaitant mémoriser ses coins et être aidé pour les espèces douteuses.

### Personas

**Persona 1 — « Le passionné » (utilisateur zéro : le père)**
- 60–75 ans, connaît bien sa forêt, cueille toute la saison.
- Smartphone utilisé simplement. Besoins : gros boutons, texte lisible, peu d'écrans, pas de compte à créer.
- Veut : retrouver ses coins, noter ce qu'il y a trouvé, vérifier une espèce douteuse.
- Risque : sur-confiance dans l'outil → le design doit empêcher cela.

**Persona 2 — « Le débutant curieux »**
- 25–45 ans, famille, premières sorties.
- Veut apprendre à reconnaître. **Risque élevé** : peut consommer sur la seule foi de l'app.
- Le produit doit pousser vers la **vérification par un pharmacien / une association mycologique** avant toute consommation.

> Le persona 2 est celui qui rend la publication risquée. Il détermine le niveau d'exigence des avertissements (§9).

---

## 4. Fonctionnalités

Légende : 🟢 V1 · 🟡 V2 · ⚪ V3 / plus tard

### 4.1 Carte et position

| ID | Fonctionnalité | Prio |
|---|---|---|
| MAP-1 | Carte centrée sur la position GPS en temps réel (point + cercle de précision), bouton « me recentrer » | 🟢 |
| MAP-2 | Télécharger des zones de carte pour usage hors connexion (sélection d'une zone rectangulaire, choix du niveau de détail, affichage de la taille) | 🟢 |
| MAP-3 | Afficher uniquement **ses propres** coins et ses sorties sur la carte | 🟢 |
| MAP-4 | Recherche d'un lieu (en ligne ; hors ligne limité à ses propres coins) | 🟢 |
| MAP-5 | **Guidage à pied vers un coin** : un clic sur un coin (liste ou carte) trace l'itinéraire par les chemins, avec consigne de la prochaine manœuvre, distance et durée restantes, recalcul si l'on s'écarte, détection d'arrivée. Sans réseau : tracé direct avec cap et distance | 🟢 |
| MAP-8 | Liste des coins à côté de la carte (panneau déplaçable sur téléphone, colonne latérale sur grand écran), triée par distance | 🟢 |
| MAP-6 | Fond de carte topographique/forestier (chemins, courbes de niveau) | 🟡 |
| MAP-7 | Enregistrement d'une trace GPS pendant une sortie | 🟡 |

### 4.2 Mes coins

| ID | Fonctionnalité | Prio |
|---|---|---|
| SPOT-1 | Créer un coin : nom, position (GPS actuel ou pointé sur la carte), type de forêt, notes, photos | 🟢 |
| SPOT-2 | Modifier / supprimer un coin | 🟢 |
| SPOT-3 | Marquer un coin favori ⭐ | 🟢 |
| SPOT-4 | Associer des espèces observées à un coin (liste issue de l'encyclopédie) | 🟢 |
| SPOT-5 | Afficher la dernière visite et l'historique des visites | 🟢 |
| SPOT-6 | Filtrer/trier les coins (favoris, espèce, distance, dernière visite) | 🟢 |
| SPOT-7 | Verrouillage de l'app par biométrie / code (les coins sont sensibles) | 🟡 |

### 4.3 Identification par photo (fonction centrale)

| ID | Fonctionnalité | Prio |
|---|---|---|
| ID-1 | Prendre une photo (ou en choisir une dans la galerie) et obtenir **les 5 espèces les plus probables** avec un score | 🟢 |
| ID-2 | Fonctionnement **100 % hors connexion** (modèle embarqué) | 🟢 |
| ID-3 | Affichage systématique de l'avertissement de sécurité et des **confusions dangereuses** de chaque candidat | 🟢 |
| ID-4 | Seuil d'incertitude : si le meilleur score est trop bas ou si les candidats sont trop proches → « Identification impossible / insuffisante » (jamais de réponse forcée) | 🟢 |
| ID-5 | Sauvegarder le résultat dans une sortie ou un coin (l'utilisateur confirme ou corrige l'espèce) | 🟢 |
| ID-6 | Mode « Je ne sais pas » : guidage multi-photos (chapeau, dessous, pied, coupe, environnement, arbre voisin) pour affiner | 🟡 |
| ID-7 | Prise en compte du contexte (mois, type de forêt, altitude) pour pondérer le résultat | 🟡 |
| ID-8 | Mesure de qualité embarquée : alerte si la photo est floue / mal cadrée | 🟡 |

### 4.4 Encyclopédie des espèces

| ID | Fonctionnalité | Prio |
|---|---|---|
| ENC-1 | Liste + recherche (nom vernaculaire, nom latin) | 🟢 |
| ENC-2 | Filtres : comestibilité, saison, habitat | 🟢 |
| ENC-3 | Fiche : nom(s), nom scientifique, famille, description (chapeau/pied/lames ou tubes/chair/odeur), habitat, période, comestibilité, **confusions dangereuses**, photos | 🟢 |
| ENC-4 | Disponible entièrement hors connexion | 🟢 |
| ENC-5 | Mise à jour du contenu par téléchargement (versionné) | 🟡 |
| ENC-6 | Mode « débutant » : n'affiche que des espèces courantes | ⚪ |
| ENC-7 | **Ajouter ses propres espèces** : nom, photo(s) et description saisis par l’utilisateur ; stockées localement, signalées « ajoutée par moi », modifiables/supprimables | 🟢 |

Couverture initiale (**décidée**) : **espèces de forêt** des Vosges et d'Alsace, pas d'espèces des prés/champs.

- **Comestibles prioritaires (liste confirmée)** : chanterelles (girolle, chanterelle en tube, chanterelle cendrée), bolets (les plus communs : cèpe de Bordeaux, cèpe d’été, cèpe des pins, bolet bai, bolet à pied rouge, bolet granulé ; liste à affiner avec le père), trompettes de la mort, pieds-de-mouton, morilles.
- **Toxiques/mortels les plus connus** : au minimum amanite phalloïde, amanite panthère, amanite tue-mouches, galère marginée, cortinaire des montagnes, et les sosies dangereux des espèces ci-dessus (ex. fausse girolle, fausse morille/gyromitre, bolet de Satan, bolet amer).
- Ordre de grandeur visé pour la V1 : **~25–40 fiches**, extensible. Les fiches des espèces dangereuses sont incluses même si le modèle IA ne les couvre pas (§11).
- Les toxiques proposés sont validés. Le père peut compléter la base avec les sosies locaux qu’il connaît via ENC-7 (espèces personnalisées).
- Les espèces ajoutées par l’utilisateur n’ont pas de statut de sécurité vérifié : elles affichent « fiche personnelle, non vérifiée » et ne participent jamais à l’identification IA (§11).

### 4.5 Carnet de cueillette

| ID | Fonctionnalité | Prio |
|---|---|---|
| LOG-1 | Créer une sortie : date, lieu (coin existant ou position), durée, notes | 🟢 |
| LOG-2 | Ajouter une récolte : espèce + quantité (nombre et/ou poids) + photos | 🟢 |
| LOG-3 | Liste chronologique des sorties, consultation hors connexion | 🟢 |
| LOG-4 | Statistiques simples : nb de sorties, espèces observées, quantités par an | 🟡 |
| LOG-5 | Météo associée à la sortie (récupérée si réseau disponible) | 🟡 |
| LOG-6 | Export du carnet (CSV / GPX / archive) | 🟡 |

### 4.6 Conditions favorables et météo

| ID | Fonctionnalité | Prio |
|---|---|---|
| METEO-1 | Météo actuelle et pluviométrie récente sur un coin | 🟡 |
| METEO-2 | Score « conditions favorables » par espèce (pluie, température, humidité, saison) présenté comme **estimation** | 🟡 |
| METEO-3 | Calibrage du score avec l'historique personnel de l'utilisateur | ⚪ |

### 4.7 Réglementation

| ID | Fonctionnalité | Prio |
|---|---|---|
| REG-1 | Page d'information générale : règles nationales de base, date de dernière vérification, sources citées | 🟡 |
| REG-2 | Réglementation locale géolocalisée (alerte de zone) | ⚪ — dépend de sources fiables et maintenues **[À VÉRIFIER]** |

### 4.8 Compte, sauvegarde et synchronisation

Sans dimension communautaire, **le compte n'est pas nécessaire en V1**. Proposition **[À VALIDER]** :

| ID | Fonctionnalité | Prio |
|---|---|---|
| DATA-1 | Aucune création de compte en V1 : tout est stocké sur l'appareil | 🟢 |
| DATA-2 | Export/import manuel d'une archive complète (sauvegarde, changement de téléphone) | 🟢 |
| DATA-3 | Sauvegarde/synchronisation optionnelle chiffrée de bout en bout, compte facultatif | 🟡 |
| DATA-4 | Suppression complète des données (locales et distantes) | 🟢 |

Avantage : pas de serveur à exploiter en V1 = coût d'exploitation ≈ 0 et RGPD minimal.

---

## 5. Parcours utilisateur principaux

### P1 — Enregistrer un coin en forêt (sans réseau)
1. Ouvrir l'app → carte centrée sur la position.
2. Bouton **« + Nouveau coin »** → position GPS pré-remplie.
3. Saisir un nom, prendre 1–3 photos, cocher les espèces.
4. Enregistrer → le coin apparaît sur la carte. *(aucun réseau requis)*

### P2 — Identifier un champignon
1. Bouton **« Identifier »** → appareil photo.
2. Photo → analyse locale (< 3 s cible).
3. Écran résultat : top 5, scores, avertissement, confusions dangereuses.
4. L'utilisateur choisit « C'est ça » / « Autre » / « Je ne sais pas » → rattaché à la sortie en cours.

### P3 — Préparer une sortie
1. Ouvrir « Mes coins » → choisir un coin favori.
2. Télécharger la zone de carte (Wi-Fi).
3. Consulter la météo/conditions (V2).

### P4 — Clore une sortie
1. Récapitulatif : coins visités, espèces récoltées, quantités.
2. Ajout de notes/photos → enregistrement dans le carnet.

---

## 6. Maquettes textuelles des écrans (V1)

**Navigation principale — 4 onglets** : 🗺️ Carte · 📷 Identifier · 📚 Espèces · 📓 Carnet

```text
┌ CARTE ──────────────────────────┐
│ [recherche]                  [⚙]│
│                                 │
│        (carte, position ●)      │
│      ⭐ Coin A      📍 Coin B     │
│                                 │
│ [⬇ Zone hors ligne]  [+ Coin]   │
└─────────────────────────────────┘

┌ IDENTIFIER ─────────────────────┐
│       [  📷  Prendre une photo ]│
│       [  🖼  Depuis la galerie ]│
│  ⚠ Aide à l'identification      │
│    uniquement. Ne mangez jamais │
│    un champignon sur cette seule│
│    base.                        │
└─────────────────────────────────┘

┌ RÉSULTAT ───────────────────────┐
│ [photo]                         │
│ 1. Bolet bai          81 %      │
│ 2. Cèpe de Bordeaux    9 %      │
│ 3. Bolet à chair jaune 4 %      │
│ ⚠ Confusions possibles : …      │
│ [Voir la fiche] [Enregistrer]   │
│ ⚠ Faites vérifier avant         │
│   toute consommation.           │
└─────────────────────────────────┘

┌ FICHE COIN ─────────────────────┐
│ ⭐ Forêt A                       │
│ 48.xxxx, 7.xxxx   [Y aller]     │
│ 🍄 Cèpes · Girolles             │
│ Dernière visite : 05/10/2026    │
│ Notes… Photos…                  │
│ [Modifier] [Supprimer]          │
└─────────────────────────────────┘
```

Contraintes d'interface : cibles tactiles ≥ 48 dp, tailles de police réglables, contraste élevé (lisible en plein soleil), mode une main.

---

## 7. Règles métier

| ID | Règle |
|---|---|
| RM-1 | Un coin possède obligatoirement un nom et une position. |
| RM-2 | Une sortie peut être rattachée à 0 ou 1 coin. Une récolte appartient à exactement une sortie. |
| RM-3 | Une espèce d'une récolte est celle **choisie/validée par l'utilisateur**, jamais celle de l'IA par défaut. Le résultat IA est conservé séparément (traçabilité). |
| RM-4 | **Aucune** formulation de l'application n'indique qu'un champignon « est comestible » à l'issue d'une identification photo. La comestibilité n'est montrée que sur la fiche espèce, avec ses réserves. |
| RM-5 | Si le score du meilleur candidat < seuil S1 ou si l'écart avec le 2ᵉ < seuil S2 → message « identification insuffisante ». Valeurs initiales à fixer par mesure (§11). |
| RM-6 | Si l'un des candidats du top 5 est **mortel ou gravement toxique**, un bandeau d'alerte rouge s'affiche, quel que soit son rang et son score. |
| RM-7 | Les coordonnées ne quittent jamais l'appareil, sauf sauvegarde chiffrée activée explicitement (DATA-3). |
| RM-8 | Chaque donnée réglementaire / météo affiche sa source et sa date de dernière mise à jour. |
| RM-9 | Les photos sont stockées localement ; leurs métadonnées EXIF GPS ne sont pas diffusées si une exportation est faite sans consentement. |

Échelle de comestibilité **[À VALIDER]** : 🟢 bon comestible · 🟡 comestible sous conditions (cuisson, etc.) · ⚪ sans intérêt / non comestible · 🟠 toxique · 🔴 mortel.

---

## 8. Modèle de données (local, SQLite)

```text
Spot            (id, name, lat, lon, forest_type, notes, is_favorite,
                 created_at, updated_at)
Outing          (id, spot_id?, started_at, duration_min, notes, weather_json?)
Harvest         (id, outing_id, species_id, quantity_count?, weight_g?, notes)
Photo           (id, file_path, taken_at, lat?, lon?,
                 spot_id?, outing_id?, harvest_id?)
Identification  (id, photo_id, model_version, top5_json, chosen_species_id?,
                 created_at)
Species         (id, is_custom, common_name_fr, scientific_name?, family?, edibility,
                 description_json, habitat, season_start, season_end,
                 content_version)
SpeciesConfusion(species_id, confused_with_species_id, danger_note)
SpeciesPhoto    (id, species_id, file_path, author, license, source_url)  -- espèces personnalisées : author = utilisateur
SpotSpecies     (spot_id, species_id, last_seen_at)
OfflineRegion   (id, name, bbox, zoom_min, zoom_max, size_bytes, downloaded_at)
AppMeta         (key, value)   -- versions de contenu, de modèle, de schéma
```

Remarques :
- `SpeciesPhoto` contient **auteur, licence et source** : indispensable pour la conformité (§14).
- Identifiants en UUID pour permettre une synchronisation future sans refonte.
- Migrations de schéma versionnées dès le départ.

---

## 9. Sécurité et responsabilité

La partie la plus critique du produit. Une erreur d'identification peut conduire à une intoxication grave.

### 9.1 Exigences produit
- Avertissement visible avant **chaque** identification et sur chaque résultat (pas seulement à l'installation).
- Consentement explicite au premier lancement (« outil d'aide, non fiable à 100 % »), journalisé.
- Recommandation constante de **faire contrôler la récolte par un pharmacien ou une association mycologique**.
- Rubrique « Que faire en cas d'intoxication » avec le numéro du centre antipoison et le 15 / 112, accessible hors ligne.
- Mise en avant des **espèces mortelles** (Amanites, Galère marginée, etc.) dans l'encyclopédie.
- Aucun vocabulaire qui valide la consommation (« bon à manger », « sûr »).

### 9.2 Exigences juridiques **[À VÉRIFIER]**
- Mentions légales, CGU limitant la responsabilité (limites de validité à examiner : une clause ne dispense pas d'un devoir d'information).
- Avis d'un juriste avant publication, ainsi que l'état de l'assurance responsabilité civile « éditeur d'application ».
- Conformité stores : politique Apple/Google sur les applications de santé/sécurité alimentaire.

### 9.3 Sécurité technique
- Données locales : chiffrement au repos des coins (clé protégée par Keystore/Keychain) **[À VALIDER]**.
- Verrouillage optionnel par biométrie.
- Aucune télémétrie qui contienne des coordonnées. Analytics, si présents : anonymes, désactivables.

---

## 10. Architecture technique

### 10.1 Choix : Flutter / Dart (décision d'origine confirmée)

```text
┌─────────────────────────────────────────────┐
│                Flutter / Dart                │
│   Présentation (widgets, état)              │
│   Domaine (cas d'usage, règles métier)      │
│   Données (repositories)                    │
└───────┬───────────────┬──────────────┬──────┘
        │               │              │
   SQLite/Drift     Carte hors     Inférence
   + fichiers       ligne          embarquée
   (photos)         (MapLibre +    (TFLite / LiteRT
                    tuiles locales)  ou ONNX)
```

- **Architecture** : feature-based + couches (présentation / domaine / données). Gestion d'état : Riverpod **[À VALIDER]**.
- **Base locale** : SQLite via **Drift** (migrations, requêtes typées, flux réactifs).
- **Position** : `geolocator` ; **caméra** : `camera` / `image_picker`.
- **Backend** : **aucun en V1**. Supabase (PostgreSQL + Storage + Auth) réservé à la sauvegarde optionnelle de la V2.
- **Cible** : Android et iOS ; versions minimales à confirmer d'après la documentation Flutter en vigueur au démarrage du développement **[À VÉRIFIER]**.

### 10.2 Cartographie hors ligne

Points à trancher **[À VÉRIFIER]** avant de coder :

| Sujet | Point d'attention |
|---|---|
| Moteur de carte | `flutter_map` (raster/vectoriel simple) ou `maplibre` (vectoriel, meilleur hors ligne). |
| Source des tuiles | Le serveur de tuiles public d'OpenStreetMap **interdit le téléchargement massif**. Il faut un fournisseur dont les conditions autorisent le **cache hors ligne et l'usage commercial**, ou héberger ses propres tuiles (format PMTiles/MBTiles) à partir de données OSM (licence ODbL, attribution obligatoire). |
| Itinéraire à pied | Le prototype utilise le serveur public « foot » de routing.openstreetmap.de (usage léger, réseau requis). Pour un guidage **hors ligne** et une diffusion commerciale : moteur de routage embarqué (ex. données de chemins OSM prétraitées pour la zone Vosges/Alsace) ou service dont les conditions l'autorisent. À arbitrer avant publication. |
| France | Les fonds IGN (Géoplateforme) sont une option naturelle pour le forestier/topographique ; conditions d'usage à relire. |
| Volume | Une région complète représente des centaines de Mo ; prévoir sélection de zone, estimation de taille, gestion de l'espace. |

### 10.3 Données et contenus de l'encyclopédie

- Contenu **embarqué dans l'app** (base SQLite pré-remplie + images compressées), versionné, mis à jour via les mises à jour de l'app en V1.
- Sources candidates pour les textes/noms : **TAXREF / INPN** (référentiel taxonomique français), rédaction originale pour les fiches (évite les problèmes de droits).
- Sources candidates pour les photos : photos propres, **Wikimedia Commons**, **iNaturalist** — chaque photo a sa propre licence (CC0, CC BY, CC BY-SA, CC BY-NC…). Les licences **NC (non commerciale) sont à exclure** si on vise une commercialisation.

---

## 11. Identification par IA

### 11.1 Architecture

```text
Photo ─► prétraitement (recadrage, redimensionnement)
      ─► modèle de classification embarqué
      ─► top 5 (espèce, score)
      ─► règles de sécurité (RM-4/5/6)
      ─► écran résultat + fiches + confusions
```

- **Embarqué (V1)** : requis par l'exigence hors connexion. Format **TFLite/LiteRT** (cross-platform avec Flutter) ou ONNX Runtime. Les mécanismes natifs (Core ML / Vision côté iOS) sont une alternative, mais imposent du code spécifique par plateforme.
- **API cloud** : écartée en V1 (hors ligne impossible, coût à l'usage, dépendance). Pourrait servir plus tard de **second avis** quand le réseau est présent.

### 11.2 Le vrai risque du projet : le modèle et ses données

Le modèle est le composant le plus incertain, techniquement **et** juridiquement.

| Question | Détail |
|---|---|
| Où trouver un modèle ? | (a) entraîner/affiner soi-même à partir d'un jeu de données ; (b) réutiliser un modèle open source existant ; (c) service tiers (écarté : hors ligne + coûts). |
| Quelles données d'entraînement ? | Jeux de données publics de référence en reconnaissance de champignons (ex. *Danish Fungi*, jeux issus de challenges FungiCLEF), photos iNaturalist/Mushroom Observer. **Chaque jeu a sa licence** ; l'entraînement sur des données sous licence non commerciale peut interdire l'usage commercial du modèle résultant **[À VÉRIFIER, point bloquant pour la publication]**. |
| Quelle fiabilité ? | La reconnaissance de champignons en conditions réelles est difficile (espèces proches, photos amateurs). Il ne faut pas supposer une précision de 87 % : **elle doit être mesurée**. |
| Taille du modèle | Contrainte de poids de l'application et de temps d'inférence (viser < 50 Mo et < 2–3 s sur un téléphone de milieu de gamme). |

### 11.3 Évaluation (critères d'acceptation du modèle)

Jeu de test **réel**, photographié par l'utilisateur et son père, en conditions de forêt, séparé de l'entraînement.

| Indicateur | Cible indicative **[À VALIDER]** |
|---|---|
| Top-1 sur les espèces couvertes | à mesurer, objectif ≥ 80 % |
| Top-5 sur les espèces couvertes | à mesurer, objectif ≥ 95 % |
| Taux de **faux « sûrs »** sur les espèces toxiques (une toxique prise pour une comestible en top-1) | le plus proche possible de 0 ; bloquant pour publication |
| Espèce hors couverture → proposition « inconnue » | à mesurer (classe « autre / hors base ») |
| Latence sur milieu de gamme | < 3 s |

Règle clé : **le modèle ne doit jamais sembler sûr de lui sur une espèce qu'il ne connaît pas.** Prévoir une classe « hors base » et/ou une mesure d'incertitude.

### 11.4 Approche recommandée

1. **V1 : sortir le produit sans IA** (le reste de l'application a de la valeur seul) pendant que l'on prototype le modèle en parallèle.
2. Prototype de modèle sur un sous-ensemble d'espèces courantes (ex. 30–50 espèces) pour évaluer la faisabilité réelle.
3. Intégration en V1.5/V2 si les indicateurs sont atteints.

> **Décision :** la V1 est livrée **sans compte et sans IA réelle**. L'identification reste la fonction centrale du produit, mais le développement est découpé pour que l'incertitude du modèle ne bloque pas la livraison.
>
> **Démo d'identification avec données en dur (décidée) :** dès la V1, les écrans Identifier et Résultat sont construits avec un **faux moteur** (`FakeIdentifier`) qui renvoie des résultats prédéfinis (top 5 + scores). Il sert à valider l'interface, les avertissements et les règles de sécurité (RM-4/5/6) avec le père. Le moteur est caché derrière une interface (`Identifier`) pour brancher le vrai modèle sans toucher à l'UI. **Cette démo doit être clairement marquée « démonstration »** dans toute version distribuée : un résultat factice ne doit jamais être pris pour une vraie identification.

---

## 12. Fonctionnement hors connexion

| Fonction | Hors ligne ? | Remarque |
|---|---|---|
| Carte (zones téléchargées) | ✅ | zones à télécharger avant |
| Carte (zones non téléchargées) | ❌ | message clair à l'utilisateur |
| GPS | ✅ | ne dépend pas du réseau |
| Coins, sorties, récoltes, photos | ✅ | base locale |
| Identification | ✅ | modèle embarqué |
| Encyclopédie | ✅ | embarquée |
| Recherche de lieu | ⚠️ | limitée à ses coins |
| Météo | ❌ | dernière valeur en cache |
| Sauvegarde cloud (V2) | ❌ | file d'attente, reprise automatique |

Principe : **la base locale est la source de vérité.** L'éventuelle synchronisation (V2) est une réplication chiffrée, pas une dépendance.

---

## 13. Vie privée et RGPD

Grâce au fonctionnement local :
- Données personnelles traitées en V1 : **uniquement sur l'appareil** → pas de traitement côté éditeur.
- Si publication : politique de confidentialité simple, fiche stores (Apple « Privacy Nutrition Label », Google « Data safety »).
- Si sauvegarde cloud (V2) : base légale = consentement, chiffrement de bout en bout, droit à l'effacement (DATA-4), hébergement dans l'UE.
- La position GPS est une donnée sensible : demande de permission contextualisée, usage en arrière-plan uniquement pour l'enregistrement de trace (V2), avec indicateur visible.

---

## 14. Coûts, licences et conformité (condition de la commercialisation)

Checklist à passer **avant** la publication :

| Élément | Question | Statut |
|---|---|---|
| Comptes éditeur | Apple Developer Program (abonnement annuel) ; Google Play (frais unique) | À prévoir |
| Fond de carte | Conditions d'usage hors ligne + commercial ? Attribution ? | [À VÉRIFIER] |
| Données OSM | Attribution ODbL affichée | [À VÉRIFIER] |
| Photos d'espèces | Licence de chaque image, attribution dans l'app, aucune NC | [À VÉRIFIER] |
| Textes encyclopédie | Rédaction originale ou licence compatible (attention aux CC BY-SA : obligation de partager sous la même licence) | [À VÉRIFIER] |
| Modèle IA | Licence du modèle de départ et des données d'entraînement : usage commercial autorisé ? | [À VÉRIFIER — bloquant] |
| Librairies Flutter | Licences (MIT/BSD/Apache OK ; GPL à éviter) — audit automatique `flutter pub deps` + vérif manuelle | À faire en continu |
| Météo (V2) | API avec offre gratuite/commerciale ? limites d'appels ? | [À VÉRIFIER] |
| Responsabilité | CGU, mentions légales, assurance, avis juridique | [À VÉRIFIER] |
| Coût d'exploitation V1 | ≈ 0 (pas de serveur) hors comptes développeur | OK |

---

## 15. Tests

| Niveau | Contenu |
|---|---|
| Unitaires | règles métier (RM-1 à RM-9), calculs de scores, seuils d'incertitude |
| Base de données | migrations, intégrité, performances avec 10 000 observations |
| Widgets / intégration | parcours P1–P4 |
| Hors ligne | mode avion complet : toutes les fonctions listées en §12 |
| Appareils | au moins 1 téléphone Android milieu de gamme + 1 iPhone ancien supporté |
| IA | jeu de test réel (§11.3), non-régression à chaque nouveau modèle |
| Terrain | sorties de test avec l'utilisateur zéro, en conditions réelles (soleil, gants, batterie faible) |
| Accessibilité | tailles de police, contraste, lecteur d'écran |
| Sécurité | vérification que les coordonnées ne sont jamais transmises |

---

## 16. Découpage MVP / V2 / V3

### V1 — « Le carnet de terrain » (hors connexion, sans compte)
Carte + GPS + zones hors ligne · Coins (CRUD, favoris, photos) · Carnet de sorties et récoltes · Encyclopédie embarquée avec recherche et filtres · Rubrique sécurité/intoxication · Export/import de sauvegarde.

### V1.5 — « Identification »
Intégration du modèle embarqué (top 5, seuils d'incertitude, alertes espèces dangereuses), selon les critères de §11.3.

### V2 — « Aide à la décision »
Météo et conditions favorables · statistiques · mode « Je ne sais pas » multi-photos · sauvegarde chiffrée optionnelle · trace GPS · verrouillage biométrique · réglementation générale.

### V3 — « Maturité commerciale »
Réglementation géolocalisée · recommandations personnelles basées sur l'historique · mises à jour de contenu à distance · éventuel modèle économique (voir §18).

---

## 17. Déploiement iOS (puis Android)

**Plateforme prioritaire : iPhone** (appareil du père). Android viendra ensuite avec la même base de code.

1. **Décision : pas de compte Apple Developer payant pendant la phase familiale / V1** (budget V1 = 0 €). Conséquence : **pas de TestFlight**. Avec un simple identifiant Apple gratuit, l'app installée sur l'iPhone **expire au bout de 7 jours** et doit être réinstallée (limite de 3 apps ; à re-vérifier). Il faut donc un mécanisme de ré-installation (voir ci-dessous). Le compte payant ne devient nécessaire que pour TestFlight/App Store, c'est-à-dire pour la publication (§14).
2. **Le poste de développement est sous Windows** : Flutter ne peut pas compiler pour iOS sous Windows. Décision : **build cloud gratuit si possible, sinon MacBook** (dans un second temps). Options à comparer **[À VÉRIFIER]** :
   - **GitHub Actions** (runners macOS) : gratuit sur dépôt public ; limité (minutes macOS fortement décomptées) sur dépôt privé ;
   - **Codemagic** : offre gratuite mensuelle pour projets personnels, quota de minutes à vérifier ;
   - **MacBook + Xcode** : installation directe sur l'iPhone branché en USB avec l'identifiant Apple gratuit.
3. **Installation sur l'iPhone du père sans compte payant** — trois pistes à évaluer **[À VÉRIFIER]**, par ordre de pertinence :
   - **A. MacBook + Xcode** : fiable, mais réinstallation tous les 7 jours, iPhone branché.
   - **B. IPA non signé (build cloud) + outil de sideloading** type AltStore/SideStore, qui re-signe avec l'identifiant gratuit et rafraîchit automatiquement tant que l'iPhone et le PC/Mac se voient sur le même Wi-Fi. Fonctionne depuis Windows. Zone grise vis-à-vis des conditions d'Apple, à évaluer.
   - **C. Version web installable (PWA)** : aucune signature nécessaire, mais le stockage local de Safari est moins fiable (risque de perte de données) et le hors ligne est plus limité. À réserver à des démos de l'interface, **pas** au stockage des coins du père.
4. **Pendant le développement**, on itère sur l'interface avec Android (émulateur), Windows ou Web. GPS, caméra et mode hors ligne **doivent être testés sur un vrai iPhone** avant de considérer une fonction comme terminée.
5. **Garde-fou** : puisque l'app peut être réinstallée tous les 7 jours, la sauvegarde/export des données (DATA-2) devient **prioritaire en V1** et l'app doit conserver ses données de façon robuste lors d'une réinstallation (stockage hors du bundle ; export automatique vers « Fichiers » iCloud/local à proposer).
6. Version minimale d'iOS prise en charge : à confirmer d'après la documentation Flutter en vigueur **[À VÉRIFIER]**.
7. Intégration continue : tests automatisés (GitHub Actions) à chaque commit.
8. Publication publique uniquement après validation de la checklist §14 (et souscription au compte Apple Developer à ce moment-là), avec : icône, captures, descriptions FR, politique de confidentialité, classification d'âge, déclaration de collecte de données (« Privacy Nutrition Label »).
9. Google Play : après la phase iOS.

---

## 18. Modèle économique (hypothèses de réflexion)

À trancher plus tard, mais à garder en tête dès maintenant car cela influence l'architecture :

- Gratuit avec achat unique pour débloquer l'identification / les zones hors ligne.
- Abonnement annuel (justifié seulement si des coûts récurrents existent : météo, mises à jour de contenu).
- Gratuit + dons (cohérent avec un projet d'abord familial).

L'absence de serveur en V1 rend un achat unique viable sans coût récurrent.

---

## 19. Estimation de complexité

Estimation relative (S = quelques jours · M = 1–2 semaines · L = 3–6 semaines · XL = > 6 semaines), pour un développeur seul à temps partiel :

| Bloc | Taille | Risque principal |
|---|---|---|
| Socle (architecture, DB, navigation, thème) | M | faible |
| Coins + carnet (CRUD, photos) | M | faible |
| Carte + GPS | M | moyen |
| Carte hors ligne | L | **élevé** (licences + gestion des tuiles) |
| Encyclopédie (code) | S | faible |
| Encyclopédie (contenu : fiches, photos, licences) | **XL** | **sous-estimé en général** |
| Export / import | S | faible |
| Identification IA (modèle + intégration) | **XL** | **très élevé** (données, qualité, licences) |
| Météo + conditions | M | moyen |
| Sauvegarde cloud chiffrée | L | moyen |
| Réglementation | L–XL | sources fiables |
| Publication stores | M | conformité |

Le chemin critique n'est pas le code Flutter : ce sont **le contenu, les licences et le modèle**.

---

## 20. Décisions prises et questions ouvertes

### Décisions prises
- Identification par photo = **fonction centrale**, **livrée après la V1** ; démo avec données en dur dès la V1.
- **Plateforme prioritaire : iPhone.**
- **Zone : Vosges et Alsace** (cartes hors ligne limitées à cette région → volume maîtrisé).
- **Espèces : forêt uniquement** ; comestibles principaux (morilles, chanterelles, trompettes de la mort, cèpes, pieds-de-mouton) + toxiques les plus connus.
- **V1 sans compte et sans IA réelle**, avec démo d'affichage de l'identification sur données en dur.
- Coins enregistrés par l'utilisateur : **oui**, privés.
- Dimension communautaire : **non**.
- Fonctionnement hors connexion : **oui**.
- Carte : **uniquement ses propres emplacements**.
- Objectif : d'abord aider son père, puis publication si maturité/coûts/licences maîtrisés.
- Technologie : **Flutter / Dart**.

- **Budget V1 : 0 €.** Pas de compte Apple Developer payant, pas de service payant (§17).
- **Langue V1 : français uniquement.**
- **Build iOS** : cloud gratuit si possible, sinon MacBook (dans un second temps).
- **Le père participera** à la constitution d'un jeu de photos annotées (test futur du modèle).
- **Familles d'espèces confirmées** : chanterelles, bolets/cèpes, trompettes de la mort, pieds-de-mouton, morilles.
- **Toxiques proposés validés**, avec ajout par l’utilisateur de ses propres espèces (photo + description), ENC-7.
- **Réinstallation hebdomadaire de l’app** (limite du compte Apple gratuit) : acceptée par le père.

### Questions ouvertes
1. **Piste d'installation sur l'iPhone** (§17) : la réinstallation hebdomadaire est acceptée ; reste à choisir entre MacBook, sideloading depuis un build cloud, ou une combinaison. Décision reportée à la première installation sur l'iPhone ; le développement de l'interface n'en dépend pas.
2. **Liste exacte des bolets** à avoir en V1 (proposition §4.4) : à affiner avec le père.
3. **Cible exacte** : hypothèse « amateur régulier » (le père) — conditionne le ton des avertissements.
4. **Budget pour la publication** : à fixer au moment du go/no-go (§14).
