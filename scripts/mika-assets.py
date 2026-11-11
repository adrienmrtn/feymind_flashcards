#!/usr/bin/env python3
"""
**Mika, du kit à l'app iPhone — en une commande.**

Changer de Mika (un kit plus mignon, de nouvelles poses) ne demande aucun code :

    1. Pousser le kit sur la branche d'assets (jamais dans l'app) :
         sequences-png/<nom>/<nom>-000.png…   une animation, image par image, canevas 512 px,
                                              24 images par seconde
         images-fixes/mika-<pose>.png         les poses fixes, canevas 1024 px
       (la disposition du kit d'origine, `seq/sequences-png/` et
       `anim/mika-animations/images-fixes/`, est lue aussi).
           git switch --orphan assets/mika-kit && cp -r <kit>/… . && git add -A
           git commit -m "Kit de Mika" && git push origin assets/mika-kit
    2. Lancer la fabrication sur un Mac de GitHub (l'encodage HEVC avec alpha n'existe que sur
       macOS) :
           gh workflow run mika-encode.yml --ref <branche> -f target=<branche>
       Le workflow (`.github/workflows/mika-encode.yml`) lit le kit, lance ce script, encode
       chaque animation avec `scripts/mika-encode.swift`, vérifie chaque vidéo en la relisant,
       et commite tout sur `<branche>` ; ses planches de contrôle partent sur
       `assets/mika-build`.

Ce que le script écrit (tout ce que l'app embarque de Mika) :

- `Micabo/Resources/Assets.xcassets/Mika/Mika-<pose>.imageset` : les poses fixes, rognées
  autour de lui, à 1,5 pixel par unité du canevas de 512 (un iPhone 3x pour un Mika de 170
  points) ; `Mika-tete` : son visage souriant, pour l'avatar rond ;
  `Mika-clip-<nom>.imageset` : la première image de chaque animation, au pixel près de la
  vidéo — l'app la montre tant que la vidéo n'est pas prête (aucun flash, aucun saut) ;
- `--frames <dossier>` : les images de chaque animation, traitées, rognées et agrandies comme
  la vidéo les attend, et `clips.json` (ce que lit `mika-encode.swift`) ;
- `Micabo/DesignSystem/Components/MikaArt.swift` : où chaque image se place dans le canevas de
  512 du kit, pour que l'app superpose pose, première image et vidéo au pixel près.

**Le traitement** (le même pour les poses, les images des animations et l'avatar, réglé dans
les constantes plus bas) :
- une **lueur claire** autour de lui (blanche, douce) : invisible sur la crème et le blanc du
  jour, elle détache le corps noir du graphite la nuit et du bleu ;
- une **lumière de contour** froide sur le haut et la gauche du corps : le noir brillant a du
  relief sur tous les fonds ;
- des **joues roses**, discrètes, sous les yeux (repérés image par image, lissés dans le
  temps) : seulement sur le noir du corps, jamais sur les yeux.

    python3 scripts/mika-assets.py <dossier du kit> [--frames <dossier>]

Dépendances : Pillow et NumPy.
"""
import argparse
import glob
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Les animations que l'app joue, toutes à la cadence du kit (24 images par seconde).
CLIPS = ["coucou", "saut", "surprise", "clin-doeil", "apparition", "celebration",
         "reflexion", "ecriture", "triste", "regard", "sommeil"]
STILLS = ["neutre", "coucou", "sourire", "sommeil", "reflexion", "surprise", "saut", "triste", "ecriture", "clin-doeil"]
CANVAS = 512            # le canevas du kit, en unités
SCALE = 1.5             # pixels par unité : poses, premières images et vidéos
PAD = 2                 # unités d'air autour de Mika (en plus de la lueur)
# L'avatar : un carré du canevas autour de son visage (la tête, les yeux, le haut du crayon).
HEAD = (138, 200, 374, 436)
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


def smooth_eyes(found):
    """Comble les images sans yeux lisibles (un clignement, un saut) et lisse le mouvement :
    les joues suivent la tête sans trembler."""
    n = len(found)
    known = [i for i, e in enumerate(found) if e is not None]
    if not known:
        return found
    filled = []
    for i in range(n):
        if found[i] is not None:
            filled.append(np.array(found[i]))
            continue
        before = [k for k in known if k < i]
        after = [k for k in known if k > i]
        if before and after:
            k0, k1 = before[-1], after[0]
            t = (i - k0) / (k1 - k0)
            filled.append(np.array(found[k0]) * (1 - t) + np.array(found[k1]) * t)
        else:
            filled.append(np.array(found[(before or after)[-1 if before else 0]]))
    out = []
    for i in range(n):
        window = [filled[j] for j in range(max(0, i - 2), min(n, i + 3))]
        out.append(tuple(np.mean(window, axis=0)))
    return out


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
    """Joues, lumière de contour, lueur : une image du canevas (512 ou 1024 px de côté)."""
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
    """Le rectangle en unités entières du canevas, élargi de PAD et arrondi à `multiple` (les
    côtés de la vidéo, ×1,5, restent pairs)."""
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


def find_kit(kit):
    seq = next((p for p in [os.path.join(kit, "sequences-png"), os.path.join(kit, "seq/sequences-png")] if os.path.isdir(p)), None)
    stills = next((p for p in [os.path.join(kit, "images-fixes"), os.path.join(kit, "anim/mika-animations/images-fixes")] if os.path.isdir(p)), None)
    if not seq or not stills:
        sys.exit(f"kit incomplet dans {kit} : il faut sequences-png/ et images-fixes/")
    return seq, stills


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


# MARK: - La fabrication

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("kit")
    parser.add_argument("--frames", help="où écrire les images des animations, pour mika-encode.swift")
    args = parser.parse_args()
    seq_dir, still_dir = find_kit(args.kit)
    out_assets = os.path.join(ROOT, "Micabo/Resources/Assets.xcassets/Mika")
    os.makedirs(out_assets, exist_ok=True)
    for old in glob.glob(os.path.join(out_assets, "Mika-*.imageset")):
        shutil.rmtree(old)
    for old in glob.glob(os.path.join(ROOT, "Micabo/Resources/Mika/*.webp")):
        os.remove(old)

    clips = []
    manifest = []
    for name in CLIPS:
        files = sorted(glob.glob(os.path.join(seq_dir, name, "*.png")))
        if not files:
            sys.exit(f"{name} : aucune image dans {seq_dir}/{name}")
        raw = [arr(Image.open(f)) for f in files]
        found = smooth_eyes([eyes(a) for a in raw])
        frames = [treat(a, e) for a, e in zip(raw, found)]
        side = frames[0].shape[1]
        boxes = [alpha_box(f) for f in frames if (f[..., 3] > 2 / 255).any()]
        union = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
        box = box_units(union, side)
        out = [crop_units(f, box) for f in frames]
        imageset(out_assets, f"Mika-clip-{name}", out[0])
        if args.frames:
            folder = os.path.join(args.frames, name)
            shutil.rmtree(folder, ignore_errors=True)
            os.makedirs(folder)
            for i, im in enumerate(out):
                im.save(os.path.join(folder, f"{i:04d}.png"))
        manifest.append({"name": name, "fps": 24, "frames": len(out), "width": out[0].width, "height": out[0].height})
        clips.append((name, box, len(out)))
        seen = sum(e is not None for e in [eyes(a) for a in raw[:: max(1, len(raw) // 8)]])
        print(f"{name:12s} {box} {len(out)} images {out[0].width}x{out[0].height}  yeux vus {seen}/{len(raw[:: max(1, len(raw) // 8)])}")
    if args.frames:
        with open(os.path.join(args.frames, "clips.json"), "w") as f:
            json.dump(manifest, f, indent=2)

    stills = []
    for pose in STILLS:
        a = arr(Image.open(os.path.join(still_dir, f"mika-{pose}.png")))
        t = treat(a, eyes(a))
        box = box_units(alpha_box(t), t.shape[1], multiple=2)
        imageset(out_assets, f"Mika-{pose}", crop_units(t, box))
        stills.append((pose, box))
        if pose == HEAD_POSE:
            head = crop_units(t, HEAD).resize((HEAD_PIXELS, HEAD_PIXELS), Image.LANCZOS)
            imageset(out_assets, "Mika-tete", head)

    lines = [
        "import CoreGraphics",
        "",
        "// Généré par scripts/mika-assets.py depuis le kit de Mika. Ne pas éditer à la main.",
        "",
        "/// **Où chaque image de Mika se place**, dans le canevas de 512 du kit : les vidéos, leurs",
        "/// premières images et les poses sont rognées autour de lui, ce cadre les remet au pixel près.",
        "enum MikaArt {",
        "    struct Clip {",
        "        /// Le rectangle de la vidéo (et de sa première image) dans le canevas.",
        "        let rect: CGRect",
        "        let frames: Int",
        "        let fps: Double",
        "",
        "        var duration: Double { Double(frames) / fps }",
        "    }",
        "",
        f"    /// Pixels par unité du canevas, partout.",
        f"    static let pixelsPerUnit: CGFloat = {SCALE}",
        "",
        "    /// Les animations embarquées, par nom (`mika-<nom>.mov`, première image `Mika-clip-<nom>`).",
        "    static let clips: [String: Clip] = [",
    ]
    for name, box, n in clips:
        lines.append(f'        "{name}": Clip(rect: {rect(box)}, frames: {n}, fps: 24),')
    lines += ["    ]", "", "    /// Les poses fixes, par nom (`Mika-<nom>`).", "    static let stills: [String: CGRect] = ["]
    for pose, box in stills:
        lines.append(f'        "{pose}": {rect(box)},')
    lines += ["    ]", "", "    /// Le visage de l'avatar (`Mika-tete`).", f"    static let head = {rect(HEAD)}", "}", ""]
    with open(os.path.join(ROOT, "Micabo/DesignSystem/Components/MikaArt.swift"), "w") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    main()
