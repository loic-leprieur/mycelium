#!/usr/bin/env python3
"""Évalue l'identification BioCLIP sur VOS photos (cahier des charges §11.3).

Place les photos dans un dossier, un sous-dossier par espèce (nom = id de
l'application, voir tools/bioclip/classes.json) :

    photos/
      girolle/        IMG_001.jpg …
      cepe-de-bordeaux/ …
      amanite-phalloide/ …
      _hors_base/     photos d'autres champignons absents de la liste

    .venv/bin/python tools/bioclip/evaluate.py photos/

Utilise exactement la chaîne de l'application (modèle ONNX réduit, vecteurs de
classes, softmax) et les règles RM-5/RM-6. Affiche : top-1 / top-5, taux
d'identification « insuffisante », et surtout les FAUX « SÛRS » : une espèce
toxique ou mortelle dont le premier candidat est une espèce comestible,
présentée comme une identification valide (bloquant pour la publication).

    --min-top 0.60 --min-margin 0.15   seuils RM-5 (défauts de l'application)
    --sweep                            teste plusieurs seuils pour aider à les fixer
"""
import argparse
import base64
import json
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "assets/models"
MEAN = np.array([0.48145466, 0.4578275, 0.40821073], dtype=np.float32)
STD = np.array([0.26862954, 0.26130258, 0.27577711], dtype=np.float32)
MIN_CANDIDATE = 0.02  # même seuil d'affichage que l'application
DANGEROUS = {"toxic", "deadly"}
EDIBLE = {"good", "conditional"}


def preprocess(image, size=224):
    image = ImageOps.exif_transpose(image).convert("RGB")
    w, h = image.size
    short, long_ = (w, h) if w <= h else (h, w)
    if short != size:
        new_long = int(size * long_ / short)
        image = image.resize((size, new_long) if w <= h else (new_long, size), Image.BICUBIC)
    w, h = image.size
    left, top = int(round((w - size) / 2.0)), int(round((h - size) / 2.0))
    image = image.crop((left, top, left + size, top + size))
    arr = (np.asarray(image, dtype=np.float32) / 255 - MEAN) / STD
    return arr.transpose(2, 0, 1)[None].astype(np.float32)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("photos", type=Path)
    parser.add_argument("--min-top", type=float, default=0.60)
    parser.add_argument("--min-margin", type=float, default=0.15)
    parser.add_argument("--sweep", action="store_true")
    args = parser.parse_args()

    bank = json.loads((MODELS / "bioclip_classes.json").read_text())
    matrix = np.frombuffer(base64.b64decode(bank["embeddings"]), "<f4").reshape(-1, bank["dim"])
    classes = bank["classes"]
    species_idx = [i for i, c in enumerate(classes) if c["kind"] == "species"]
    edibility = {s["id"]: s["edibility"] for s in json.loads((Path(__file__).parent / "classes.json").read_text())["species"]}
    session = ort.InferenceSession(str(MODELS / "bioclip_visual.onnx"), providers=["CPUExecutionProvider"])

    rows = []  # (vrai, [(id, score)…triés], unknown)
    for folder in sorted(p for p in args.photos.iterdir() if p.is_dir()):
        truth = folder.name
        if truth != "_hors_base" and truth not in edibility:
            print(f"Dossier ignoré (espèce inconnue de l'application) : {truth}")
            continue
        for path in sorted(folder.iterdir()):
            if path.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
                continue
            emb = session.run(None, {"pixel_values": preprocess(Image.open(path))})[0][0]
            logits = bank["logitScale"] * matrix @ (emb / np.linalg.norm(emb))
            p = np.exp(logits - logits.max())
            p /= p.sum()
            ranked = sorted(((classes[i]["id"], float(p[i])) for i in species_idx), key=lambda t: -t[1])
            unknown = float(sum(p[i] for i in range(len(classes)) if i not in species_idx))
            rows.append((truth, path.name, ranked, unknown))
    if not rows:
        raise SystemExit("Aucune photo trouvée.")

    def verdict(ranked, unknown, min_top, min_margin):
        top = [c for c in ranked[:5] if c[1] >= MIN_CANDIDATE]
        if not top:
            return None, True
        margin = top[0][1] - top[1][1] if len(top) > 1 else top[0][1]
        insufficient = top[0][1] < min_top or margin < min_margin or unknown >= top[0][1]
        return top, insufficient

    def report(min_top, min_margin, verbose):
        n = len(rows)
        top1 = top5 = insufficient_n = false_safe = valid_wrong = 0
        false_safe_list, confusions, per_class = [], Counter(), defaultdict(lambda: [0, 0])
        known = [r for r in rows if r[0] != "_hors_base"]
        for truth, name, ranked, unknown in rows:
            top, insufficient = verdict(ranked, unknown, min_top, min_margin)
            insufficient_n += insufficient
            if truth == "_hors_base":
                if not insufficient:
                    valid_wrong += 1  # espèce inconnue présentée comme identifiée
                continue
            ids = [c[0] for c in ranked[:5]]
            top1 += ids[0] == truth
            top5 += truth in ids
            per_class[truth][0] += ids[0] == truth
            per_class[truth][1] += 1
            if ids[0] != truth:
                confusions[(truth, ids[0])] += 1
            if not insufficient and edibility[truth] in DANGEROUS and edibility.get(top[0][0]) in EDIBLE:
                false_safe += 1
                false_safe_list.append((truth, name, top[0]))
            if not insufficient and top[0][0] != truth:
                valid_wrong += 1
        k = max(len(known), 1)
        hb = [r for r in rows if r[0] == "_hors_base"]
        print(f"\n== seuils : meilleur score ≥ {min_top:.2f}, écart ≥ {min_margin:.2f} ==")
        print(f"photos : {n} ({len(known)} d'espèces connues, {len(hb)} hors base)")
        print(f"top-1 : {top1 / k:.0%}   top-5 : {top5 / k:.0%}   (cibles §11.3 : ≥ 80 % / ≥ 95 %)")
        print(f"identifications « insuffisantes » : {insufficient_n / n:.0%} (le modèle s'abstient)")
        print(f"FAUSSES identifications présentées comme valides : {valid_wrong}")
        print(f"FAUX « SÛRS » (toxique/mortelle prise pour une comestible) : {false_safe}  <- doit être 0")
        if verbose:
            for truth, name, top in false_safe_list:
                print(f"   !! {truth}/{name} -> {top[0]} ({top[1]:.0%})")
            for (truth, pred), count in confusions.most_common(8):
                print(f"   confusion : {truth} -> {pred} x{count}")
            for truth, (ok, total) in sorted(per_class.items()):
                print(f"   {truth:28s} {ok}/{total}")

    report(args.min_top, args.min_margin, verbose=True)
    if args.sweep:
        for top in (0.4, 0.5, 0.6, 0.7, 0.8, 0.9):
            for margin in (0.1, 0.2, 0.3):
                report(top, margin, verbose=False)


if __name__ == "__main__":
    main()
