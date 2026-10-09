# Identification embarquée : BioCLIP

L'application identifie les champignons **sur le téléphone, sans réseau**, avec
[BioCLIP](https://huggingface.co/imageomics/bioclip) (ViT-B/16, licence MIT),
exécuté par ONNX Runtime. Principe « zero-shot » : la photo est encodée en un
vecteur de 512 nombres, comparé aux vecteurs précalculés des espèces. Ajouter une
espèce = modifier `classes.json` et relancer l'export, **sans réentraînement**.

Les **classes « hors base »** (`others` et `backgrounds` dans `classes.json`) sont
essentielles : elles absorbent la probabilité d'une photo d'espèce inconnue (ou
sans champignon), pour que le modèle ne force jamais une réponse (§11.3).

## Générer le modèle (une fois, ou après un changement de `classes.json`)

Le modèle converti pèse 115 Mo, au-delà de la limite de GitHub : il n'est **pas
versionné** (`assets/models/*.onnx` est ignoré). Sans lui, l'application compile et
fonctionne en **mode démonstration** (résultats fictifs, signalés comme tels).

```bash
python3.13 -m venv .venv          # Python ≥ 3.10
.venv/bin/pip install torch torchvision open_clip_torch onnx onnxruntime onnxscript pillow numpy
.venv/bin/python tools/bioclip/export_bioclip.py --check-images <dossier de photos>
```

Télécharge ~0,6 Go (poids BioCLIP depuis Hugging Face), produit
`assets/models/bioclip_visual.onnx` et `bioclip_classes.json`, et **contrôle la
fidélité** de la conversion par rapport à PyTorch.

| Précision | Taille | Fidélité (cosinus avec PyTorch) |
|---|---|---|
| `int8w` (défaut) : poids int8, calculs float32 | 115 Mo | 0,9996 |
| `fp16` | 173 Mo | 1,0000 |
| int8 dynamique (écarté) | 87 Mo | 0,92 : fausse le classement |

## Évaluer sur de vraies photos (§11.3)

Un sous-dossier par espèce (nom = id de l'application), plus `_hors_base/` :

```bash
.venv/bin/python tools/bioclip/evaluate.py photos/ --sweep
```

Donne top-1 / top-5, le taux d'abstention, les **faux « sûrs »** (toxique prise pour
une comestible : bloquant pour une publication) et aide à fixer les seuils RM-5
(`SafetyThresholds` dans `lib/features/identify/identifier.dart`, aujourd'hui
0,60 / 0,15, **non calibrés**).

## Tests

```bash
python tools/bioclip/make_fixtures.py        # références Python (PIL + modèle exporté)
flutter test                                  # prétraitement Dart == PIL, scores, règles de sécurité
flutter test integration_test/identify_model_test.dart -d macos   # vrai modèle, vrai ONNX Runtime
flutter test integration_test/identify_flow_test.dart  -d macos   # parcours complet de l'interface
```

## Limites connues

- **La précision n'est pas mesurée sur des champignons réels** : seuls la fidélité
  numérique de la conversion et le comportement sur des images non fongiques sont
  vérifiés. Les seuils RM-5 doivent être calibrés avec `evaluate.py`.
- Licences **[À VÉRIFIER]** avant publication : BioCLIP est sous MIT, mais il a été
  entraîné sur TreeOfLife-10M (photos iNaturalist, EOL… aux licences variées).
- 115 Mo : au-delà de la cible de 50 Mo du cahier des charges.
