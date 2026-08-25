"""Génère l'icône de l'application Micabo (1024x1024) dans le catalogue d'assets."""

from __future__ import annotations

import pathlib

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUTPUT = (
    pathlib.Path(__file__).resolve().parents[1]
    / "Micabo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
)

# Le vert de Micabo, et pas l'indigo : l'icône portait un violet d'app de productivité,
# avec un rond menthe pour seul rappel du vert. C'est le vert qui mène maintenant, dans les
# deux nuances de l'app — le vert profond porte la carte, le menthe vif ponctue.
PAPER_TOP = (251, 255, 253)
PAPER_BOTTOM = (222, 244, 235)
GREEN = (13, 145, 108)
AMBER = (247, 181, 56)
MINT = (34, 214, 160)


def vertical_gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGB", (size, size), top)
    draw = ImageDraw.Draw(image)
    for y in range(size):
        ratio = y / (size - 1)
        color = tuple(round(top[i] + (bottom[i] - top[i]) * ratio) for i in range(3))
        draw.line([(0, y), (size, y)], fill=color)
    return image


def card(width: int, height: int, radius: int, fill, outline=None, outline_width: int = 0) -> Image.Image:
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle(
        [(0, 0), (width - 1, height - 1)],
        radius=radius,
        fill=fill,
        outline=outline,
        width=outline_width,
    )
    return layer


def paste_rotated(base: Image.Image, layer: Image.Image, angle: float, center: tuple[int, int]) -> None:
    rotated = layer.rotate(angle, resample=Image.BICUBIC, expand=True, fillcolor=(0, 0, 0, 0))
    origin = (center[0] - rotated.width // 2, center[1] - rotated.height // 2)
    base.alpha_composite(rotated, origin)


def drop_shadow(layer: Image.Image, blur: int, opacity: int) -> Image.Image:
    # Le flou déborde de la forme : on élargit le calque pour ne pas le tronquer.
    pad = blur * 3
    alpha = layer.split()[3].point(lambda value: min(opacity, value))
    canvas = Image.new("L", (layer.width + pad * 2, layer.height + pad * 2), 0)
    canvas.paste(alpha, (pad, pad))
    shadow = Image.new("RGBA", canvas.size, (18, 52, 42, 0))
    shadow.putalpha(canvas)
    return shadow.filter(ImageFilter.GaussianBlur(blur))


def build() -> Image.Image:
    base = vertical_gradient(SIZE, PAPER_TOP, PAPER_BOTTOM).convert("RGBA")

    card_w, card_h, radius = 430, 560, 68
    center = (SIZE // 2, SIZE // 2)

    back = card(card_w, card_h, radius, (255, 255, 255, 255))
    paste_rotated(base, drop_shadow(back, 30, 46), -12, (center[0] - 60, center[1] + 24))
    paste_rotated(base, back, -12, (center[0] - 64, center[1] + 14))

    front = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
    front_draw = ImageDraw.Draw(front)
    front_draw.rounded_rectangle([(0, 0), (card_w - 1, card_h - 1)], radius=radius, fill=GREEN + (255,))

    # Lignes de « prise de notes » sur la carte de devant.
    line_x = 72
    rows = [(268, 26, (255, 255, 255, 255)), (214, 20, AMBER + (255,)), (250, 20, (255, 255, 255, 130)), (166, 20, (255, 255, 255, 130))]
    line_y = 150
    for width, height, color in rows:
        front_draw.rounded_rectangle(
            [(line_x, line_y), (line_x + width, line_y + height)],
            radius=height // 2,
            fill=color,
        )
        line_y += height + 46

    front_draw.ellipse([(line_x, card_h - 158), (line_x + 84, card_h - 74)], fill=MINT + (255,))

    paste_rotated(base, drop_shadow(front, 38, 72), 8, (center[0] + 62, center[1] + 30))
    paste_rotated(base, front, 8, (center[0] + 58, center[1]))

    return base.convert("RGB")


if __name__ == "__main__":
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    build().save(OUTPUT, format="PNG")
    print(f"Icône écrite dans {OUTPUT}")
