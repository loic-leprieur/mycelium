#!/usr/bin/env python3
"""Génère les fixtures de test de l'identification (références calculées avec PIL
et le modèle exporté), pour vérifier que l'implémentation Dart donne les mêmes
résultats que la chaîne Python.

    .venv/bin/python tools/bioclip/make_fixtures.py [--photo PHOTO.jpg] [--out-dart FICHIER]

Avec --photo, la fixture d'intégration utilise cette photo (ex. un vrai champignon)
au lieu de l'image synthétique.

Écrit :
  test/fixtures/clip_{landscape,portrait}.png          images synthétiques
  test/fixtures/clip_{landscape,portrait}_224.png      leur Resize(224)+CenterCrop(224) PIL
  integration_test/clip_fixture.dart                   photo + vecteur et scores attendus
"""
import argparse
import base64
import io
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "test/fixtures"
MODELS = ROOT / "assets/models"
MEAN = np.array([0.48145466, 0.4578275, 0.40821073], dtype=np.float32)
STD = np.array([0.26862954, 0.26130258, 0.27577711], dtype=np.float32)


def synthetic(width, height, seed):
    """Image texturée (sinusoïdes, blocs, bruit) : met l'anti-crénelage à l'épreuve."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:height, 0:width].astype(np.float32)
    img = np.zeros((height, width, 3), np.float32)
    for c in range(3):
        img[..., c] = (
            110 + 70 * np.sin(x / (7 + 3 * c) + c) * np.cos(y / (11 - c))
            + 40 * np.sin((x + y) / (3 + c))
        )
    for _ in range(25):
        x0, y0 = rng.integers(0, width - 30), rng.integers(0, height - 30)
        img[y0:y0 + rng.integers(8, 30), x0:x0 + rng.integers(8, 30)] = rng.integers(0, 255, 3)
    img += rng.normal(0, 6, img.shape)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


def py_round(value):
    return int(round(value))  # arrondi « pair » de Python 3, comme torchvision


def resize_crop(image, size=224):
    """Resize(size, bicubique) + CenterCrop(size), comme open_clip / torchvision."""
    w, h = image.size
    short, long_ = (w, h) if w <= h else (h, w)
    if short != size:
        new_long = int(size * long_ / short)
        new_w, new_h = (size, new_long) if w <= h else (new_long, size)
        image = image.resize((new_w, new_h), Image.BICUBIC)
    w, h = image.size
    left, top = py_round((w - size) / 2.0), py_round((h - size) / 2.0)
    return image.crop((left, top, left + size, top + size))


def tensor(image):
    arr = (np.asarray(image, dtype=np.float32) / 255 - MEAN) / STD
    return arr.transpose(2, 0, 1)[None].astype(np.float32)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--photo", help="photo à utiliser pour la fixture d'intégration")
    parser.add_argument("--out-dart", default=str(ROOT / "integration_test/clip_fixture.dart"))
    args = parser.parse_args()
    FIXTURES.mkdir(parents=True, exist_ok=True)
    landscape, portrait = synthetic(330, 247, 1), synthetic(200, 310, 2)
    for name, image in (("landscape", landscape), ("portrait", portrait)):
        image.save(FIXTURES / f"clip_{name}.png")
        resize_crop(image).save(FIXTURES / f"clip_{name}_224.png")

    # Photo JPEG + vecteur et scores attendus du pipeline complet (modèle exporté).
    source = Image.open(args.photo).convert("RGB") if args.photo else landscape
    buffer = io.BytesIO()
    source.save(buffer, format="JPEG", quality=92)
    jpeg = buffer.getvalue()
    decoded = Image.open(io.BytesIO(jpeg)).convert("RGB")
    # Mêmes pixels, sans perte : isole l'écart dû au décodeur JPEG de celui du modèle.
    png = io.BytesIO()
    decoded.save(png, format="PNG")

    session = ort.InferenceSession(str(MODELS / "bioclip_visual.onnx"),
                                   providers=["CPUExecutionProvider"])
    embedding = session.run(None, {"pixel_values": tensor(resize_crop(decoded))})[0][0]

    bank = json.loads((MODELS / "bioclip_classes.json").read_text())
    matrix = np.frombuffer(base64.b64decode(bank["embeddings"]), "<f4").reshape(-1, bank["dim"])
    logits = bank["logitScale"] * matrix @ (embedding / np.linalg.norm(embedding))
    probs = np.exp(logits - logits.max())
    probs /= probs.sum()
    species = {c["id"]: float(p) for c, p in zip(bank["classes"], probs) if c["kind"] == "species"}
    unknown = float(sum(p for c, p in zip(bank["classes"], probs) if c["kind"] != "species"))

    lines = [
        "// GÉNÉRÉ par tools/bioclip/make_fixtures.py : ne pas modifier à la main.",
        "// Photo synthétique (JPEG) et résultats attendus de la chaîne Python complète.",
        f"const clipModelVersion = '{bank['version']}';",
        f"const clipFixtureJpegBase64 = '{base64.b64encode(jpeg).decode()}';",
        f"const clipFixturePngBase64 = '{base64.b64encode(png.getvalue()).decode()}';",
        "const clipFixtureEmbedding = <double>[" + ",".join(f"{v:.6f}" for v in embedding) + "];",
        f"const clipFixtureUnknown = {unknown:.6f};",
        "const clipFixtureSpecies = <String, double>{",
        *[f"  '{k}': {v:.6f}," for k, v in species.items()],
        "};",
        "",
    ]
    Path(args.out_dart).write_text("\n".join(lines))
    best = max(species, key=species.get)
    print(f"OK. Meilleure espèce de la fixture : {best} ({species[best]:.3f}), hors base {unknown:.3f}")


if __name__ == "__main__":
    main()
