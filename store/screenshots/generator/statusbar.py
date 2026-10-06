"""
**Les captures de l'app, barre d'état propre.**

Les maquettes du parcours d'accueil (`OnboardingHook`, `OnboardingFeature1` à `5`, une par
langue dans `Assets.xcassets`) servent de captures aux images de l'App Store. Elles ont été
prises à 22 h 22 avec un réseau faible : sur une fiche App Store, ça se voit. Ce script
repeint l'heure en 9:41 et les points du réseau en quatre barres, comme sur les images
d'Apple, et pose le résultat dans `captures/<langue>/`, que `index.html` lit.

    python3 store/screenshots/generator/statusbar.py [--font Inter-SemiBold.otf]

Il faut Pillow, et une police proche de SF Pro pour l'heure : Inter SemiBold
(https://rsms.me/inter). Le dossier `captures/` n'est pas suivi : il se refait d'ici.
"""

import argparse
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "..", "..", "Micabo", "Resources", "Assets.xcassets")

# Le nom court de chaque écran, et la maquette qui le porte.
SOURCES = {
    "meca": "OnboardingHook",
    "fiche": "OnboardingFeature1",
    "today": "OnboardingFeature2",
    "quiz": "OnboardingFeature3",
    "decks": "OnboardingFeature4",
    "mika": "OnboardingFeature5",
}

# La maquette anglaise n'a pas de suffixe : c'est la langue de base du catalogue.
SUFFIXES = {"fr": "-fr", "en": "", "es": "-es", "de": "-de", "tr": "-tr"}


def clean(path, font):
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    draw = ImageDraw.Draw(image)
    background = pixels[120, 70]

    def box(x0, y0, x1, y1):
        """Le cadre de tout ce qui se détache du fond de la barre d'état, dans une zone."""
        points = [
            (x, y)
            for y in range(y0, y1)
            for x in range(x0, x1)
            if sum(abs(pixels[x, y][i] - background[i]) for i in range(3)) > 40
        ]
        if not points:
            return None
        xs = [p[0] for p in points]
        ys = [p[1] for p in points]
        return min(xs), min(ys), max(xs), max(ys)

    clock = box(100, 50, 330, 150)
    signal = box(650, 60, 742, 140)
    # Toutes les maquettes sortent du même téléphone : l'heure est toujours au même endroit.
    # Si ce n'est plus le cas, mieux vaut s'arrêter que repeindre au mauvais endroit.
    if not clock or not (80 <= clock[1] <= 92 and 110 <= clock[3] <= 118):
        raise SystemExit(f"{path} : l'heure n'est pas où on l'attend ({clock})")

    draw.rectangle((clock[0] - 8, clock[1] - 8, clock[2] + 8, clock[3] + 8), fill=background)
    if signal:
        draw.rectangle((signal[0] - 6, signal[1] - 6, signal[2] + 6, signal[3] + 6), fill=background)

    width = draw.textlength("9:41", font=font)
    draw.text(((clock[0] + clock[2]) / 2 - width / 2, clock[3]), "9:41", font=font, fill=(0, 0, 0, 255), anchor="ls")
    x = 690
    for height in (10, 15, 21, 27):
        draw.rounded_rectangle((x, 114 - height, x + 7, 114), radius=2, fill=(0, 0, 0, 255))
        x += 10
    return image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--font", default="/usr/share/fonts/opentype/inter/Inter-SemiBold.otf")
    args = parser.parse_args()
    font = ImageFont.truetype(args.font, 39)

    for lang, suffix in SUFFIXES.items():
        out = os.path.join(HERE, "captures", lang)
        os.makedirs(out, exist_ok=True)
        for name, base in SOURCES.items():
            asset = base + suffix
            source = os.path.join(ASSETS, f"{asset}.imageset", f"{asset}.png")
            clean(source, font).save(os.path.join(out, f"{name}.png"))
        print(f"{lang} : {len(SOURCES)} captures")


if __name__ == "__main__":
    main()
