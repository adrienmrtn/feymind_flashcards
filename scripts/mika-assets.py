#!/usr/bin/env python3
"""
**Mika, du kit à l'app iPhone.**

Lit le kit de Mika (les séquences PNG image par image en 512 px et les poses fixes en
1024 px) et écrit ce que l'app embarque :

- `Micabo/Resources/Mika/mika-<nom>.webp` : seulement les animations que l'app joue,
  **rognées** au plus petit rectangle qui contient Mika sur toutes leurs images (le kit
  garde un grand vide autour de lui pour ses sauts), à 24 images par seconde pour les gestes
  courts et 12 pour les longues ; chaque image est une image clé (aucune dépendance entre
  images : ImageIO décode n'importe laquelle d'emblée).
- `Micabo/Resources/Assets.xcassets/Mika/Mika-<pose>.imageset` : les poses fixes, rognées de
  même, à 1,5 pixel par unité du canevas de 512 (la finesse d'un iPhone 3x pour un Mika de
  170 points) ; `Mika-tete` : la tête de Mika, pour l'avatar rond.
- `Micabo/DesignSystem/Components/MikaArt.swift` : où chaque image se place dans le canevas
  de 512 du kit, pour que l'app les superpose au pixel près.

    python3 scripts/mika-assets.py <dossier du kit>

Le dossier du kit contient `seq/sequences-png/<nom>/<nom>-000.png…` et
`anim/mika-animations/images-fixes/mika-<pose>.png`.
"""
import glob
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = sys.argv[1] if len(sys.argv) > 1 else None

# Les animations que l'app joue : (nom du kit, images par seconde dans l'app).
CLIPS = [
    ("coucou", 24),
    ("saut", 24),
    ("surprise", 24),
    ("clin-doeil", 24),
    ("apparition", 24),
    ("celebration", 12),
    ("reflexion", 12),
    ("ecriture", 12),
    ("triste", 12),
    ("regard", 12),
    ("sommeil", 12),
]
STILLS = ["neutre", "coucou", "sourire", "sommeil", "reflexion", "surprise", "saut", "triste", "ecriture", "clin-doeil"]
STILL_SCALE = 1.5  # pixels par unité du canevas de 512
PAD = 3
QUALITY = 88
# La tête, pour l'avatar : un carré du canevas de 512 (yeux au milieu, le haut du crayon).
HEAD = (104, 176, 412, 484)


def alpha_box(im):
    a = im.getchannel("A").point(lambda v: 255 if v > 6 else 0)
    return a.getbbox()


def union(boxes):
    boxes = [b for b in boxes if b]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))


def padded(box, w, h, pad=PAD):
    x0, y0, x1, y1 = box
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(w, x1 + pad), min(h, y1 + pad)
    # Des côtés pairs : la moitié tombe juste.
    if (x1 - x0) % 2:
        x1 = x1 + 1 if x1 < w else x1
        x0 = x0 - 1 if (x1 - x0) % 2 and x0 > 0 else x0
    if (y1 - y0) % 2:
        y1 = y1 + 1 if y1 < h else y1
        y0 = y0 - 1 if (y1 - y0) % 2 and y0 > 0 else y0
    return (x0, y0, x1, y1)


def main():
    if not KIT:
        sys.exit(__doc__)
    out_anim = os.path.join(ROOT, "Micabo/Resources/Mika")
    out_still = os.path.join(ROOT, "Micabo/Resources/Assets.xcassets/Mika")
    for old in glob.glob(os.path.join(out_anim, "*.webp")):
        os.remove(old)

    clips = []
    for name, fps in CLIPS:
        files = sorted(glob.glob(os.path.join(KIT, "seq/sequences-png", name, "*.png")))
        frames = [Image.open(f).convert("RGBA") for f in files]
        step = round(24 / fps)
        frames = frames[::step]
        w, h = frames[0].size
        box = padded(union(alpha_box(f) for f in frames), w, h)
        cropped = [f.crop(box) for f in frames]
        path = os.path.join(out_anim, f"mika-{name}.webp")
        cropped[0].save(
            path, save_all=True, append_images=cropped[1:], duration=round(1000 / fps), loop=0,
            quality=QUALITY, alpha_quality=90, method=6, kmin=0, kmax=1, allow_mixed=False, exact=False,
        )
        clips.append((name, box, len(cropped), fps, os.path.getsize(path)))
        print(f"{name:12s} {box} {len(cropped)} images à {fps} i/s  {os.path.getsize(path) // 1024} Ko")

    stills = []
    for pose in STILLS:
        im = Image.open(os.path.join(KIT, "anim/mika-animations/images-fixes", f"mika-{pose}.png")).convert("RGBA")
        k = im.width / 512
        b = alpha_box(im)
        box = padded(tuple(v / k for v in b), 512, 512)
        box = tuple(int(round(v)) for v in box)
        crop = im.crop(tuple(int(v * k) for v in box))
        crop = crop.resize((round((box[2] - box[0]) * STILL_SCALE), round((box[3] - box[1]) * STILL_SCALE)), Image.LANCZOS)
        name = f"Mika-{pose}"
        folder = os.path.join(out_still, f"{name}.imageset")
        os.makedirs(folder, exist_ok=True)
        crop.save(os.path.join(folder, f"{name}.png"), optimize=True)
        stills.append((pose, box))
    # La tête.
    im = Image.open(os.path.join(KIT, "anim/mika-animations/images-fixes", "mika-neutre.png")).convert("RGBA")
    k = im.width / 512
    head = im.crop(tuple(int(v * k) for v in HEAD)).resize((192, 192), Image.LANCZOS)
    folder = os.path.join(out_still, "Mika-tete.imageset")
    os.makedirs(folder, exist_ok=True)
    head.save(os.path.join(folder, "Mika-tete.png"), optimize=True)
    for pose in ["neutre"] + STILLS + ["tete"]:
        folder = os.path.join(out_still, f"Mika-{pose}.imageset")
        with open(os.path.join(folder, "Contents.json"), "w") as f:
            json.dump({"images": [{"filename": f"Mika-{pose}.png", "idiom": "universal"}],
                       "info": {"author": "xcode", "version": 1}}, f, indent=2)
            f.write("\n")

    def rect(b):
        return f"CGRect(x: {b[0]}, y: {b[1]}, width: {b[2] - b[0]}, height: {b[3] - b[1]})"

    lines = [
        "import CoreGraphics",
        "",
        "// Généré par scripts/mika-assets.py depuis le kit de Mika. Ne pas éditer à la main.",
        "",
        "/// **Où chaque image de Mika se place**, dans le canevas de 512 du kit : les animations et",
        "/// les poses sont rognées autour de lui, ce cadre les remet au pixel près.",
        "enum MikaArt {",
        "    struct Clip {",
        "        /// Le rectangle de l'animation dans le canevas.",
        "        let rect: CGRect",
        "        let frames: Int",
        "        let fps: Double",
        "    }",
        "",
        "    /// Les animations embarquées, par nom de fichier (`mika-<nom>.webp`).",
        "    static let clips: [String: Clip] = [",
    ]
    for name, box, n, fps, _ in clips:
        lines.append(f'        "{name}": Clip(rect: {rect(box)}, frames: {n}, fps: {fps}),')
    lines += ["    ]", "", "    /// Les poses fixes, par nom (`Mika-<nom>`).", "    static let stills: [String: CGRect] = ["]
    for pose, box in stills:
        lines.append(f'        "{pose}": {rect(box)},')
    lines += ["    ]", "", "    /// La tête de l'avatar (`Mika-tete`).", f"    static let head = {rect(HEAD)}", "}", ""]
    with open(os.path.join(ROOT, "Micabo/DesignSystem/Components/MikaArt.swift"), "w") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    main()
