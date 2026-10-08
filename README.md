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

État : squelette V1 (carte, coins, carnet, encyclopédie, identification en **mode démonstration** avec données fictives). Les fiches d'espèces sont provisoires et doivent être validées avant toute diffusion.
