# Composants tiers

Les dépendances Dart/Flutter (environ 160 paquets : BSD, MIT, Apache-2.0) sont listées
avec leur texte de licence dans l'écran **Réglages > Licences** de l'application.
Les paquets `dbus`, `geoclue` et `gsettings` (MPL-2.0) ne servent qu'à la
localisation sous Linux et ne sont pas embarqués dans les applications iOS, Android
ou macOS.

## Éléments hors paquets Dart

| Composant | Licence | Remarque |
|---|---|---|
| BioCLIP (`imageomics/bioclip`, ViT-B/16) | MIT (d'après sa fiche) | Entraîné sur TreeOfLife-10M (photos de licences variées) : **à vérifier avant commercialisation**. |
| ONNX Runtime (Microsoft) | MIT | Via `flutter_onnxruntime`. |
| Données cartographiques © contributeurs OpenStreetMap | ODbL 1.0 | Attribution affichée sur la carte. Les serveurs de tuiles publics ne conviennent pas à un usage commercial. |
| Flutter / Dart SDK | BSD-3-Clause | |
| SQLite | Domaine public | |
