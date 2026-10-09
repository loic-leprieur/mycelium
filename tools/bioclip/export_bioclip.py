#!/usr/bin/env python3
"""Prépare BioCLIP pour l'identification embarquée (hors ligne) de Mycelium.

Modèle : imageomics/bioclip (ViT-B/16, licence MIT), reconnaissance du vivant
« zero-shot » : on compare la photo à des descriptions textuelles des espèces.

Produit dans assets/models/ :
  bioclip_visual.onnx   encodeur d'image (poids int8 par blocs, ~115 Mo)
  bioclip_classes.json  vecteurs-texte précalculés des classes

Précision (--precision) : « int8w » (défaut) = poids int8, calculs en float32,
cosinus 0,9996 avec PyTorch ; « fp16 » = 173 Mo, cosinus 1,0000. La quantification
int8 dynamique, plus petite (87 Mo), est écartée : cosinus 0,92, qui fausse le
classement des espèces.

L'application n'embarque PAS l'encodeur de texte : pour chaque classe de
classes.json on calcule ici, une fois, un vecteur de 512 nombres à partir de
son nom scientifique. À l'exécution, la photo est encodée puis comparée à ces
vecteurs (similarité cosinus). Ajouter une espèce = modifier classes.json et
relancer ce script, sans réentraînement.

    python3.13 -m venv .venv
    .venv/bin/pip install torch torchvision open_clip_torch onnx onnxruntime onnxscript pillow numpy
    .venv/bin/python tools/bioclip/export_bioclip.py [--precision int8w|fp16] [--check-images DOSSIER]
"""
import argparse
import base64
import json
import shutil
import tempfile
import time
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort
import open_clip
import torch
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
MODEL_ID = "hf-hub:imageomics/bioclip"

# Change à chaque modification du modèle ou des classes (stocké avec chaque
# identification pour la traçabilité, RM-3 / cahier des charges §8).
MODEL_VERSION = "bioclip-v1-vit-b16-2026-10-a"

# Gabarits de texte moyennés pour chaque classe (« prompt ensembling »).
TEMPLATES = {
    "taxon": "a photo of {taxon}.",
    "scientific": "a photo of {scientific}.",
    "common": "a photo of {scientific}, {common_en}.",
}


class VisualEncoder(torch.nn.Module):
    """Photo prétraitée (1×3×224×224) -> vecteur de 512 nombres normalisé (L2)."""

    def __init__(self, visual):
        super().__init__()
        self.visual = visual

    def forward(self, pixels):
        return torch.nn.functional.normalize(self.visual(pixels), dim=-1)


def load_model():
    # Le chemin rapide de MultiheadAttention n'est pas exportable en ONNX.
    torch.backends.mha.set_fastpath_enabled(False)
    model, _, preprocess = open_clip.create_model_and_transforms(MODEL_ID)
    tokenizer = open_clip.get_tokenizer(MODEL_ID)
    return model.eval(), preprocess, tokenizer


def export_fp32(model, path):
    encoder = VisualEncoder(model.visual).eval()
    dummy = torch.randn(1, 3, 224, 224)
    names = dict(input_names=["pixel_values"], output_names=["embedding"])
    with torch.no_grad():
        try:
            torch.onnx.export(encoder, (dummy,), str(path), opset_version=17, dynamo=False, **names)
        except Exception as error:  # exportateur historique indisponible
            print("export historique impossible, bascule sur dynamo :", error)
            torch.onnx.export(encoder, (dummy,), dynamo=True, **names).save(str(path))


def convert(fp32, out, precision):
    """Réduit la taille du modèle float32 en gardant la fidélité."""
    if precision == "fp16":
        from onnxruntime.transformers.float16 import convert_float_to_float16
        onnx.save(convert_float_to_float16(onnx.load(str(fp32)), keep_io_types=True), str(out))
    elif precision == "int8w":
        # Poids int8 par blocs de 64, activations en float32 (opérateur MatMulNBits).
        from onnxruntime.quantization.matmul_nbits_quantizer import (
            DefaultWeightOnlyQuantConfig, MatMulNBitsQuantizer)
        config = DefaultWeightOnlyQuantConfig(block_size=64, is_symmetric=True, bits=8)
        quantizer = MatMulNBitsQuantizer(onnx.load(str(fp32)), algo_config=config)
        quantizer.process()
        quantizer.model.save_model_to_file(str(out), use_external_data_format=False)
    else:
        raise SystemExit(f"précision inconnue : {precision}")


def session(path):
    options = ort.SessionOptions()
    options.log_severity_level = 3
    return ort.InferenceSession(str(path), options, providers=["CPUExecutionProvider"])


def embed_onnx(sess, tensor):
    return sess.run(None, {"pixel_values": tensor.numpy()})[0]


def sample_tensors(preprocess, folder):
    """Photos réelles du dossier fourni, sinon images synthétiques (contrôle faible)."""
    paths = []
    if folder:
        paths = sorted(p for p in Path(folder).rglob("*") if p.suffix.lower() in {".jpg", ".jpeg", ".png"})
    if paths:
        return [preprocess(Image.open(p).convert("RGB")).unsqueeze(0) for p in paths], len(paths)
    print("ATTENTION : aucune photo fournie (--check-images), contrôle sur images synthétiques.")
    rng = np.random.default_rng(0)
    out = []
    for _ in range(6):
        base = rng.integers(0, 255, (16, 16, 3), dtype=np.uint8)
        img = Image.fromarray(base).resize((640, 480), Image.BICUBIC)
        out.append(preprocess(img).unsqueeze(0))
    return out, 0


def cosine(a, b):
    a, b = a.reshape(-1), b.reshape(-1)
    return float(a @ b / (np.linalg.norm(a) * np.linalg.norm(b)))


def text_embeddings(model, tokenizer, classes):
    """Un vecteur par classe : moyenne (renormalisée) des gabarits de texte."""
    vectors = []
    for entry in classes:
        if "prompt" in entry:
            prompts = [entry["prompt"]]
        else:
            prompts = [t.format(**entry) for t in TEMPLATES.values()]
        with torch.no_grad():
            feats = model.encode_text(tokenizer(prompts), normalize=True)
        mean = feats.mean(dim=0)
        vectors.append((mean / mean.norm()).numpy())
    return np.stack(vectors).astype("<f4")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=str(ROOT / "assets/models"))
    parser.add_argument("--precision", choices=["int8w", "fp16"], default="int8w")
    parser.add_argument("--check-images", help="dossier de photos pour contrôler la précision")
    args = parser.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    model, preprocess, tokenizer = load_model()
    defs = json.loads((HERE / "classes.json").read_text())
    classes = (
        [dict(e, kind="species") for e in defs["species"]]
        + [dict(e, kind="other") for e in defs["others"]]
        + [dict(e, kind="background") for e in defs["backgrounds"]]
    )

    with tempfile.TemporaryDirectory() as tmp:
        fp32 = Path(tmp) / "visual_fp32.onnx"
        reduced = out / "bioclip_visual.onnx"

        print("1/4 export ONNX (float32)…")
        export_fp32(model, fp32)

        print(f"2/4 réduction du modèle ({args.precision})…")
        convert(fp32, reduced, args.precision)

        print("3/4 contrôle de fidélité…")
        tensors, real = sample_tensors(preprocess, args.check_images)
        fp32_sess, reduced_sess = session(fp32), session(reduced)
        worst_export, worst_reduced = 1.0, 1.0
        for t in tensors:
            with torch.no_grad():
                ref = VisualEncoder(model.visual)(t).numpy()
            worst_export = min(worst_export, cosine(ref, embed_onnx(fp32_sess, t)))
            worst_reduced = min(worst_reduced, cosine(ref, embed_onnx(reduced_sess, t)))
        start = time.perf_counter()
        for _ in range(5):
            embed_onnx(reduced_sess, tensors[0])
        latency = (time.perf_counter() - start) / 5
        print(f"    PyTorch vs ONNX float32 : cosinus min {worst_export:.5f}")
        print(f"    PyTorch vs ONNX {args.precision:7s} : cosinus min {worst_reduced:.5f}"
              f"  ({'photos réelles : ' + str(real) if real else 'synthétique'})")
        print(f"    latence (CPU de cette machine) : {latency * 1000:.0f} ms")
        print(f"    taille : float32 {fp32.stat().st_size / 1e6:.0f} Mo -> {args.precision} {reduced.stat().st_size / 1e6:.0f} Mo")
        assert worst_export > 0.999, "l'export ONNX ne reproduit pas PyTorch"
        assert worst_reduced > 0.995, "la réduction du modèle dégrade trop l'embedding"

    print("4/4 vecteurs-texte des classes…")
    matrix = text_embeddings(model, tokenizer, classes)
    meta = {
        "model": "imageomics/bioclip (ViT-B/16, MIT)",
        "version": MODEL_VERSION,
        "precision": args.precision,
        "inputSize": 224,
        "mean": list(open_clip.constants.OPENAI_DATASET_MEAN),
        "std": list(open_clip.constants.OPENAI_DATASET_STD),
        "logitScale": float(model.logit_scale.exp().item()),
        "dim": int(matrix.shape[1]),
        "classes": [
            {"id": c.get("id"), "kind": c["kind"], "name": c.get("scientific", c.get("prompt"))}
            for c in classes
        ],
        "embeddings": base64.b64encode(matrix.tobytes()).decode("ascii"),
    }
    (out / "bioclip_classes.json").write_text(json.dumps(meta, ensure_ascii=False))
    n_species = sum(c["kind"] == "species" for c in classes)
    print(f"OK : {len(classes)} classes ({n_species} espèces) -> {out}")


if __name__ == "__main__":
    main()
