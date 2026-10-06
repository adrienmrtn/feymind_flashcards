"""
**Les images de l'iPhone 6,3″, tirées de celles du 6,9″.**

    python3 store/screenshots/generator/resize.py <dossier de sortie>

App Store Connect demande des images pour l'iPhone à Dynamic Island de taille moyenne
(1206 × 2622) en plus du grand (1320 × 2868). Les deux formats ont les mêmes proportions à
un millième près : une réduction suffit, sans rien recomposer. On ne les suit pas dans le
dépôt — 35 fichiers de plus pour une simple réduction — et le workflow les refait à chaque
envoi, dans un dossier temporaire.
"""

import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "..")
SIZE = (1206, 2622)


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    out_root = sys.argv[1]
    count = 0
    for lang in sorted(os.listdir(SOURCE)):
        folder = os.path.join(SOURCE, lang)
        if lang == "generator" or not os.path.isdir(folder):
            continue
        out = os.path.join(out_root, lang)
        os.makedirs(out, exist_ok=True)
        for name in sorted(os.listdir(folder)):
            if not name.endswith(".png"):
                continue
            image = Image.open(os.path.join(folder, name)).convert("RGB")
            image.resize(SIZE, Image.LANCZOS).save(os.path.join(out, name), optimize=True)
            count += 1
    print(f"{count} images en {SIZE[0]} × {SIZE[1]} dans {out_root}")


if __name__ == "__main__":
    main()
