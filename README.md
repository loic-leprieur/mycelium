# mycelium
A mushroom-picking assistant that allows you to discover, identify, locate and memorize your mushroom corners, while providing safety and regulatory information.

## Développement

Cahier des charges : [docs/cahier-des-charges-v0.1.md](docs/cahier-des-charges-v0.1.md).

Prérequis : Flutter (canal stable). Sous Windows, activer le **Mode développeur** (Paramètres > Confidentialité et sécurité > Pour les développeurs), requis par les plugins Flutter.

```bash
flutter pub get
dart run build_runner build   # génère lib/data/database.g.dart (Drift)
flutter test
flutter run -d windows        # ou un émulateur Android
```

Identification par photo **hors ligne** (BioCLIP + ONNX Runtime) : le modèle n'est pas versionné, voir [tools/bioclip/README.md](tools/bioclip/README.md) pour le générer. Sans lui l'application fonctionne en **mode démonstration** (données fictives). Desktop macOS : `flutter run -d macos` (choix d'une photo dans un fichier, pas d'appareil photo).

État : V1 (carte, coins, carnet, encyclopédie, vibrations de guidage, identification locale — précision à mesurer sur de vraies photos). Les fiches d'espèces sont provisoires et doivent être validées avant toute diffusion.

## Licence

Logiciel **propriétaire** : © 2026 Loïc Leprieur, tous droits réservés. Le code est visible
sur ce dépôt public, mais **aucune réutilisation, copie, modification ni distribution n'est
autorisée** sans accord écrit (voir [LICENSE](LICENSE)). Les composants tiers gardent leurs
propres licences : [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
