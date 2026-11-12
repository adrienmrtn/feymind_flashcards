#!/usr/bin/env python3
"""
**Mika, du kit à l'app iPhone — en une commande.**

Depuis le lot 9, Mika est une **image fixe nette** à chaque instant : ses expressions sont
des PNG, et tout ce qui bouge (le fondu d'une expression à l'autre, la respiration de son
arrivée, le petit écrasement d'un appui, les étincelles de la fête) est dessiné par SwiftUI à
la cadence de l'écran (`MikaMascot.swift`). Plus aucune vidéo : une animation précalculée à
24 images par seconde saccadait à côté d'une interface à 120 Hz.

Changer de Mika (un kit plus mignon, de nouvelles expressions) :

    python3 scripts/mika-assets.py <dossier du kit> [--sheet controle.jpg]

Le kit : `images-fixes/mika-<expression>.png` (PNG transparent, canevas carré de 1024 px,
Mika debout au même endroit et à la même taille dans chaque image, le bas des tentacules vers
y = 970), une image par nom de `STILLS` ci-dessous. La disposition du kit d'origine
(`anim/mika-animations/images-fixes/`) est lue aussi ; les séquences d'animation, s'il y en a,
sont ignorées. Sur GitHub : pousser le kit sur la branche `assets/mika-kit`, puis
`gh workflow run mika-encode.yml --ref <branche> -f target=<branche>` (un Linux suffit).

Ce que le script écrit (tout ce que l'app embarque de Mika) :

- `Micabo/Resources/Assets.xcassets/Mika/Mika-<expression>.imageset` : chaque expression,
  rognée autour de lui, à 2 pixels par unité du canevas de 512 (la définition du kit : un
  iPhone 3x net jusqu'à un Mika de 220 points) ; `Mika-tete` : son visage souriant, pour
  l'avatar rond ;
- `Micabo/DesignSystem/Components/MikaArt.swift` : où chaque image se place dans le canevas de
  512, pour que deux expressions se superposent au pixel près pendant leur fondu ;
- `--sheet` : une planche de contrôle (chaque expression sur la crème, le graphite et le bleu).

**Le traitement** (le même pour toutes, réglé dans les constantes plus bas) :
- une **lueur claire** autour de lui (blanche, douce) : invisible sur la crème et le blanc du
  jour, elle détache le corps noir du graphite la nuit et du bleu ;
- une **lumière de contour** froide sur le haut et la gauche du corps : le noir brillant a du
  relief sur tous les fonds ;
- des **joues roses**, discrètes, sous les yeux (repérés dans l'image) : seulement sur le noir
  du corps, jamais sur les yeux.

Une nouvelle expression (un nom absent de `STILLS`) demande aussi sa place dans `MikaStill`
(`MikaMascot.swift`) ; une expression manquante arrête le script avec la liste attendue.

Dépendances : Pillow et NumPy.
"""
import argparse
import glob
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Les expressions que l'app montre (`MikaStill`), toutes debout, les tentacules au sol.
STILLS = ["neutre", "sourire", "clin-doeil", "coucou", "surprise", "reflexion", "ecriture",
          "triste", "sommeil"]
CANVAS = 512            # le canevas de référence, en unités (le kit est en 1024 px : 2 px par unité)
SCALE = 2.0             # pixels par unité : la définition du kit, sans agrandissement
PAD = 2                 # unités d'air autour de Mika (en plus de la lueur)
# L'avatar : un carré du canevas autour de son visage (la tête, les yeux, le haut du crayon).
HEAD = (118, 182, 394, 458)
HEAD_POSE = "sourire"
HEAD_PIXELS = 216

# Le traitement, en fractions du côté du canevas.
GLOW_OPACITY = 0.36
GLOW_RADIUS = 0.035
RIM_LIGHT = 0.6
BLUSH_OPACITY = 0.55
BLUSH_COLOR = (255, 135, 165)


# MARK: - Outils

def arr(im):
    return np.asarray(im.convert("RGBA")).astype(np.float32) / 255


def img(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8))


def blur(a, r):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), "L")
                      .filter(ImageFilter.GaussianBlur(r)), dtype=np.float32) / 255


def over(top, bottom):
    ta, ba = top[..., 3:4], bottom[..., 3:4]
    oa = ta + ba * (1 - ta)
    oc = (top[..., :3] * ta + bottom[..., :3] * ba * (1 - ta)) / np.maximum(oa, 1e-6)
    return np.concatenate([oc, oa], -1)


def solid(color, alpha):
    h, w = alpha.shape
    c = np.ones((h, w, 3), np.float32) * (np.array(color, np.float32) / 255)
    return np.concatenate([c, alpha[..., None]], -1)


# MARK: - Les yeux et les joues

def blobs(mask):
    h, w = mask.shape
    seen = np.zeros_like(mask, bool)
    out = []
    for y, x in np.argwhere(mask):
        if seen[y, x]:
            continue
        stack = [(y, x)]
        seen[y, x] = True
        ys, xs = [], []
        while stack:
            cy, cx = stack.pop()
            ys.append(cy)
            xs.append(cx)
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        out.append((len(ys), np.array(ys), np.array(xs)))
    out.sort(key=lambda b: -b[0])
    return out


def eyes(a):
    """Les deux yeux — blancs, dans le noir de la tête — : (x1, y1, x2, y2) en fractions du
    côté, ou None."""
    w = a.shape[1]
    s = max(1, w // 256)
    sm = a[::s, ::s]
    rgb, al = sm[..., :3], sm[..., 3]
    white = (rgb.min(-1) > 0.78) & (al > 0.9) & ((rgb[..., 2] - rgb[..., 0]) < 0.12)
    dark = (rgb.max(-1) < 0.25) & (al > 0.9)
    white &= blur(dark.astype(np.float32), 4) > 0.35
    found = [b for b in blobs(white) if b[0] >= 3][:2]
    if len(found) < 2:
        return None
    pts = sorted(((xs.mean() + 0.5) * s / w, (ys.mean() + 0.5) * s / w) for _, ys, xs in found)
    (x1, y1), (x2, y2) = pts
    gap = x2 - x1
    if not (0.07 < gap < 0.18) or abs(y2 - y1) > gap * 0.5:
        return None
    return (x1, y1, x2, y2)


def blush(a, eye):
    if eye is None or BLUSH_OPACITY <= 0:
        return a
    h, w = a.shape[:2]
    x1, y1, x2, y2 = (v * w for v in eye)
    gap = x2 - x1
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    m = np.zeros((h, w), np.float32)
    for x, y, side in ((x1, y1, -1), (x2, y2, 1)):
        cx, cy = x + side * gap * 0.32, y + gap * 0.42
        d = ((xx - cx) / (gap * 0.30)) ** 2 + ((yy - cy) / (gap * 0.17)) ** 2
        m = np.maximum(m, np.clip(1 - d, 0, 1) ** 1.5)
    lum = a[..., :3].max(-1)
    m *= a[..., 3] * np.clip((0.4 - lum) / 0.4, 0, 1)
    k = (m * BLUSH_OPACITY)[..., None]
    out = a.copy()
    out[..., :3] = out[..., :3] * (1 - k) + (np.array(BLUSH_COLOR, np.float32) / 255) * k
    return out


# MARK: - Le traitement

def treat(a, eye):
    """Joues, lumière de contour, lueur : une image du canevas (1024 px de côté)."""
    w = a.shape[1]
    al = a[..., 3]
    out = blush(a, eye)
    if RIM_LIGHT > 0:
        inner = np.clip((al - blur(al, w * 0.01)) * 3, 0, 1) * al
        gy, gx = np.gradient(blur(al, w * 0.02))
        toward = np.clip((gx * 0.6 + gy * 0.8) / (np.sqrt(gx ** 2 + gy ** 2) + 1e-4), 0, 1)
        k = (inner * (0.35 + 0.65 * toward) * RIM_LIGHT)[..., None]
        out = out.copy()
        out[..., :3] = out[..., :3] * (1 - k) + np.array([0.80, 0.86, 1.0], np.float32) * k
    if GLOW_OPACITY > 0:
        glow = np.clip(blur(al, w * GLOW_RADIUS) * 1.6, 0, 1) * GLOW_OPACITY
        out = over(out, solid((255, 255, 255), glow))
    return out


def alpha_box(a, threshold=2 / 255):
    ys, xs = np.nonzero(a[..., 3] > threshold)
    return (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)


def box_units(box, side, multiple=4):
    """Le rectangle en unités entières du canevas, élargi de PAD et arrondi à `multiple`."""
    k = side / CANVAS
    x0, y0 = int(np.floor(box[0] / k)) - PAD, int(np.floor(box[1] / k)) - PAD
    x1, y1 = int(np.ceil(box[2] / k)) + PAD, int(np.ceil(box[3] / k)) + PAD
    while (x1 - x0) % multiple:
        x1 += 1
    while (y1 - y0) % multiple:
        y1 += 1
    return (x0, y0, x1, y1)


def crop_units(a, box):
    """Rogne une image du canevas à `box` (en unités), en complétant de transparent si le
    rectangle déborde, puis la met à SCALE pixels par unité."""
    side = a.shape[1]
    k = side / CANVAS
    x0, y0, x1, y1 = (int(round(v * k)) for v in box)
    canvas = np.zeros((y1 - y0, x1 - x0, 4), np.float32)
    sx0, sy0 = max(0, x0), max(0, y0)
    sx1, sy1 = min(side, x1), min(a.shape[0], y1)
    canvas[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = a[sy0:sy1, sx0:sx1]
    # Le redimensionnement se fait en prémultiplié : aucun liseré sombre sur les bords.
    pm = canvas.copy()
    pm[..., :3] *= pm[..., 3:4]
    size = (int(round((box[2] - box[0]) * SCALE)), int(round((box[3] - box[1]) * SCALE)))
    chans = [Image.fromarray(pm[..., c], "F").resize(size, Image.LANCZOS) for c in range(4)]
    out = np.stack([np.asarray(c, np.float32) for c in chans], -1)
    out = np.clip(out, 0, 1)
    out[..., :3] = np.where(out[..., 3:4] > 1e-4, out[..., :3] / np.maximum(out[..., 3:4], 1e-4), 0)
    return img(np.clip(out, 0, 1))


def find_stills(kit):
    for path in [os.path.join(kit, "images-fixes"), os.path.join(kit, "anim/mika-animations/images-fixes"), kit]:
        if glob.glob(os.path.join(path, "mika-*.png")):
            return path
    sys.exit(f"aucune image mika-<expression>.png dans {kit} (ni dans images-fixes/)")


def imageset(folder, name, image):
    path = os.path.join(folder, f"{name}.imageset")
    os.makedirs(path, exist_ok=True)
    for old in glob.glob(os.path.join(path, "*.png")):
        os.remove(old)
    image.save(os.path.join(path, f"{name}.png"), optimize=True)
    with open(os.path.join(path, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": f"{name}.png", "idiom": "universal"}],
                   "info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")


def rect(b):
    return f"CGRect(x: {b[0]}, y: {b[1]}, width: {b[2] - b[0]}, height: {b[3] - b[1]})"


def sheet(path, images):
    """La planche de contrôle : chaque expression sur la crème, le graphite et le bleu."""
    cell = 220
    backgrounds = [(250, 246, 238), (28, 30, 38), (64, 112, 240)]
    out = Image.new("RGB", (cell * len(images), cell * len(backgrounds)), (255, 255, 255))
    draw = ImageDraw.Draw(out)
    for column, (name, image) in enumerate(images):
        thumb = image.copy()
        thumb.thumbnail((cell - 24, cell - 40), Image.LANCZOS)
        for row, color in enumerate(backgrounds):
            tile = Image.new("RGBA", (cell, cell), color + (255,))
            tile.alpha_composite(thumb, ((cell - thumb.width) // 2, (cell - 18 - thumb.height) // 2))
            out.paste(tile.convert("RGB"), (column * cell, row * cell))
            draw.text((column * cell + 6, row * cell + cell - 16), name, fill=(220, 40, 40))
    out.save(path, quality=88)


# MARK: - La fabrication

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("kit")
    parser.add_argument("--sheet", help="où écrire la planche de contrôle (JPEG)")
    args = parser.parse_args()
    still_dir = find_stills(args.kit)
    missing = [p for p in STILLS if not os.path.exists(os.path.join(still_dir, f"mika-{p}.png"))]
    if missing:
        sys.exit(f"il manque {', '.join(f'mika-{m}.png' for m in missing)} dans {still_dir} "
                 f"(attendu : {', '.join(STILLS)})")
    extra = sorted(os.path.basename(p)[5:-4] for p in glob.glob(os.path.join(still_dir, "mika-*.png")))
    extra = [p for p in extra if p not in STILLS]
    if extra:
        print(f"ignorées (pas dans STILLS ni dans MikaStill) : {', '.join(extra)}")

    out_assets = os.path.join(ROOT, "Micabo/Resources/Assets.xcassets/Mika")
    os.makedirs(out_assets, exist_ok=True)
    for old in glob.glob(os.path.join(out_assets, "Mika-*.imageset")):
        shutil.rmtree(old)
    # Les vidéos d'avant le lot 9 : plus rien ne les lit.
    shutil.rmtree(os.path.join(ROOT, "Micabo/Resources/Mika"), ignore_errors=True)

    stills = []
    shown = []
    for pose in STILLS:
        a = arr(Image.open(os.path.join(still_dir, f"mika-{pose}.png")))
        t = treat(a, eyes(a))
        box = box_units(alpha_box(t), t.shape[1], multiple=2)
        image = crop_units(t, box)
        imageset(out_assets, f"Mika-{pose}", image)
        stills.append((pose, box))
        shown.append((pose, image))
        print(f"{pose:12s} {box} {image.width}x{image.height}")
        if pose == HEAD_POSE:
            head = crop_units(t, HEAD).resize((HEAD_PIXELS, HEAD_PIXELS), Image.LANCZOS)
            imageset(out_assets, "Mika-tete", head)
    if args.sheet:
        sheet(args.sheet, shown)

    lines = [
        "import CoreGraphics",
        "",
        "// Généré par scripts/mika-assets.py depuis le kit de Mika. Ne pas éditer à la main.",
        "",
        "/// **Où chaque expression de Mika se place**, dans le canevas de 512 du kit : les images",
        "/// sont rognées autour de lui, ce cadre les remet au pixel près — deux expressions se",
        "/// superposent exactement pendant leur fondu.",
        "enum MikaArt {",
        "    /// Pixels par unité du canevas, partout.",
        f"    static let pixelsPerUnit: CGFloat = {SCALE}",
        "",
        "    /// Les expressions, par nom (`Mika-<nom>`).",
        "    static let stills: [String: CGRect] = [",
    ]
    for pose, box in stills:
        lines.append(f'        "{pose}": {rect(box)},')
    lines += ["    ]", "", "    /// Le visage de l'avatar (`Mika-tete`).", f"    static let head = {rect(HEAD)}", "}", ""]
    with open(os.path.join(ROOT, "Micabo/DesignSystem/Components/MikaArt.swift"), "w") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    main()
