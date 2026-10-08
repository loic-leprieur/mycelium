# Déployer Mycelium sur un iPhone (sans compte Apple payant)

Contexte : le développement se fait sous Windows, et Flutter ne peut pas
compiler pour iOS sous Windows. On compile donc dans le cloud (GitHub Actions,
Mac virtuel), puis on installe le fichier obtenu sur l'iPhone avec un outil qui
le signe avec un **identifiant Apple gratuit**.

> Limite du compte gratuit : l'application **expire au bout de 7 jours** et doit
> être réinstallée (AltStore peut le faire automatiquement, voir plus bas).
> Pour une installation durable (TestFlight, App Store) il faudra le compte
> Apple Developer payant — prévu seulement au moment de la publication.

## 1. Compiler l'application (une fois par version)

1. Poussez le code sur GitHub (branche `main` ou la branche à tester).
2. Sur GitHub : onglet **Actions** → workflow **Build iOS (non signé)** →
   bouton **Run workflow** (choisir la branche).
3. Attendez la fin (environ 10 à 20 minutes). Les tests sont exécutés avant la
   compilation : si un test échoue, aucun fichier n'est produit.
4. En bas de la page de l'exécution, section **Artifacts** : téléchargez
   **Mycelium-ipa** (archive zip contenant `Mycelium.ipa`) et décompressez-la.

Remarque : GitHub Actions est gratuit et illimité pour un dépôt **public**. Pour
un dépôt privé, le quota gratuit de minutes macOS est limité (chaque minute
macOS compte 10 fois) : suffisant pour quelques builds par mois.

## 2. Installer sur l'iPhone avec AltStore (depuis Windows)

Prérequis sur le PC : iTunes et iCloud **téléchargés depuis le site d'Apple**
(pas la version du Microsoft Store), et AltServer (altstore.io).

1. Installer AltServer sur le PC, puis le lancer (icône dans la barre des tâches).
2. Brancher l'iPhone en USB, le déverrouiller, accepter « Faire confiance à cet
   ordinateur ». Dans iTunes, activer « Synchroniser avec cet iPhone via le Wi-Fi ».
3. Icône AltServer → **Install AltStore** → choisir l'iPhone → saisir
   l'identifiant Apple (gratuit) et son mot de passe (ils ne servent qu'à signer).
4. Sur l'iPhone : **Réglages → Général → VPN et gestion de l'appareil** → faire
   confiance au profil de l'identifiant Apple.
5. Sur l'iPhone, activer le **mode développeur** si iOS le demande
   (Réglages → Confidentialité et sécurité → Mode développeur) puis redémarrer.
6. Transférer `Mycelium.ipa` sur l'iPhone (AirDrop, iCloud Drive, câble…), ouvrir
   **AltStore → My Apps → +** et choisir le fichier. L'application s'installe.
7. **Renouvellement automatique** : tant que l'iPhone et le PC sont sur le même
   Wi-Fi, AltServer ouvert, AltStore re-signe l'application avant l'expiration.

Alternative : **Sideloadly** (sideloadly.io, Windows) — glisser `Mycelium.ipa`,
saisir l'identifiant Apple, cliquer *Start*. Même limite de 7 jours, à refaire à
la main.

## 3. Première utilisation

- Autoriser la **localisation** (« Lorsque l'app est active ») et l'appareil photo.
- La carte se centre sur votre position ; « Coins d'exemple » crée trois coins
  de démonstration pour tester le guidage.
- L'identification par photo est en **mode démonstration** (résultats fictifs).

## 4. Variante : avec un Mac

Si vous avez un MacBook : installer Xcode et Flutter, brancher l'iPhone, puis

```bash
flutter pub get
flutter run --release -d <nom de l'iPhone>
```

Xcode demande de choisir une équipe de signature : connecter l'identifiant Apple
gratuit dans *Xcode → Settings → Accounts*, puis dans le projet `ios/Runner.xcworkspace`
choisir cette équipe et un identifiant d'application unique (ex.
`fr.votrenom.mycelium`). Même limite de 7 jours.

## 5. Données et mises à jour

- Les coins, sorties et photos sont stockés **sur l'iPhone**. Réinstaller une
  nouvelle version par-dessus (même identifiant) conserve les données ; **ne
  désinstallez pas** l'application avant d'avoir exporté ce qui compte (l'export
  des données est prévu en V1, pas encore disponible).
- Le fond de carte utilise les tuiles publiques d'OpenStreetMap : il faut du
  réseau pour afficher la carte (carte hors ligne à venir).
