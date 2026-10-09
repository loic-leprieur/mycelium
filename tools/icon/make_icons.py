#!/usr/bin/env python3
"""Génère les icônes de l'application pour iOS, Android, macOS, web et Windows
à partir des calques rendus par `flutter test tools/icon/render_layers_test.dart`.

    python3 tools/icon/make_icons.py        # nécessite Pillow

Calques (tools/icon/layers/) : background.png (dégradé opaque) et foreground.png
(champignon sur fond transparent), tous deux en 1024×1024.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
LAYERS = Path(__file__).resolve().parent / "layers"


def load(name):
    return Image.open(LAYERS / f"{name}.png").convert("RGBA")


def rounded(img, radius_ratio):
    """Coins arrondis (masque sur-échantillonné pour des bords lisses)."""
    size = img.size[0]
    scale = 4
    mask = Image.new("L", (size * scale,) * 2, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size * scale - 1, size * scale - 1),
        radius=size * scale * radius_ratio,
        fill=255,
    )
    mask = mask.resize((size, size), Image.LANCZOS)
    out = img.copy()
    out.putalpha(mask)
    return out


def save(img, path, size, opaque=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    out = img.resize((size, size), Image.LANCZOS)
    if opaque:
        out = out.convert("RGB")  # iOS refuse la transparence
    out.save(path, optimize=True)


background, foreground = load("background"), load("foreground")

# Icône pleine : fond + champignon (opaque, sans coins : iOS arrondit lui-même).
full = Image.alpha_composite(background, foreground)

# Icône « carte » à coins arrondis, pour Android < 8, Windows et macOS.
card = rounded(full, 0.2237)

# macOS : carte de 824 px centrée dans 1024 px, avec une ombre douce.
mac = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
inset = card.resize((824, 824), Image.LANCZOS)
shadow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
shadow.paste((0, 0, 0, 90), (100, 112), inset.getchannel("A"))
mac = Image.alpha_composite(mac, shadow.filter(ImageFilter.GaussianBlur(14)))
mac.alpha_composite(inset, (100, 100))

# --- iOS ---------------------------------------------------------------------
ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for entry in json.loads((ios / "Contents.json").read_text())["images"]:
    side = float(entry["size"].split("x")[0]) * int(entry["scale"].rstrip("x"))
    save(full, ios / entry["filename"], round(side), opaque=True)

# --- macOS -------------------------------------------------------------------
macos = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
for side in (16, 32, 64, 128, 256, 512, 1024):
    save(mac, macos / f"app_icon_{side}.png", side)

# --- Android -----------------------------------------------------------------
res = ROOT / "android/app/src/main/res"
for density, launcher, layer in (
    ("mdpi", 48, 108),
    ("hdpi", 72, 162),
    ("xhdpi", 96, 216),
    ("xxhdpi", 144, 324),
    ("xxxhdpi", 192, 432),
):
    # Icône classique (Android < 8).
    save(card, res / f"mipmap-{density}/ic_launcher.png", launcher)
    # Icône adaptative (Android ≥ 8) : 108 dp, seuls ~66 % centraux sont garantis
    # visibles, donc le champignon est réduit pour ne jamais être rogné.
    save(background, res / f"mipmap-{density}/ic_launcher_background.png", layer, opaque=True)
    small = foreground.resize((round(1024 * 0.86),) * 2, Image.LANCZOS)
    padded = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    padded.alpha_composite(small, ((1024 - small.width) // 2,) * 2)
    save(padded, res / f"mipmap-{density}/ic_launcher_foreground.png", layer)

adaptive = res / "mipmap-anydpi-v26/ic_launcher.xml"
adaptive.parent.mkdir(parents=True, exist_ok=True)
adaptive.write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    "</adaptive-icon>\n"
)

# --- Web ---------------------------------------------------------------------
web = ROOT / "web"
for side in (192, 512):
    save(full, web / f"icons/Icon-{side}.png", side)
    save(full, web / f"icons/Icon-maskable-{side}.png", side)  # fond plein + zone sûre
save(card, web / "favicon.png", 32)

# --- Windows -----------------------------------------------------------------
ico = ROOT / "windows/runner/resources/app_icon.ico"
card.save(ico, format="ICO", sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])

print("Icônes générées pour iOS, macOS, Android, web et Windows.")
