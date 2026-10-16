#!/usr/bin/env python3
"""**Mika, du SVG animé à SwiftUI.**

La mascotte arrive du design en deux fichiers : `design/mika/mika.svg` (Mika au repos, chaque
partie du corps dans son calque) et `design/mika/mika.css` (les huit humeurs : quelles parties
bougent, autour de quel point, sur quelles images clés). Le kit d'origine les anime dans une
WebView ; l'app les dessine nativement, dans un `Canvas`, sans navigateur.

Ce script fait la traduction une fois pour toutes et écrit `Micabo/Resources/mika.json`, que
`MikaMascot` lit au premier affichage :

- **le dessin** — chaque calque, ses tracés ramenés à M / L / C / Z en coordonnées absolues
  (arcs et quadratiques convertis), ses couleurs et dégradés, sa transformation fixe ;
- **le mouvement** — pour chaque calque et chaque humeur, le style résolu comme le ferait un
  navigateur : quelle animation, combien de temps, quelle courbe, autour de quel point (les
  pourcentages `fill-box` sont résolus sur la boîte du calque), quelle transformation et
  quelle opacité fixes ;
- **les images clés**, chaque transformation décomposée en translation, rotation, échelle.

    python3 scripts/generate-mika.py

Le design change ? On remplace les deux fichiers de `design/mika/` et on relance.
"""

import json
import math
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
SVG = ROOT / "design/mika/mika.svg"
CSS = ROOT / "design/mika/mika.css"
OUT = ROOT / "Micabo/Resources/mika.json"

MOODS = ["idle", "wave", "happy", "sleep", "think", "surprise", "celebrate", "sad"]
NS = "{http://www.w3.org/2000/svg}"

# ---------------------------------------------------------------------------------------------
# Matrices affines [a, b, c, d, e, f] : x' = a x + c y + e, y' = b x + d y + f
# ---------------------------------------------------------------------------------------------

IDENTITY = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]


def mul(m, n):
    """m ∘ n : applique n, puis m."""
    a, b, c, d, e, f = m
    a2, b2, c2, d2, e2, f2 = n
    return [
        a * a2 + c * b2,
        b * a2 + d * b2,
        a * c2 + c * d2,
        b * c2 + d * d2,
        a * e2 + c * f2 + e,
        b * e2 + d * f2 + f,
    ]


def apply(m, x, y):
    a, b, c, d, e, f = m
    return a * x + c * y + e, b * x + d * y + f


def nums(text):
    return [float(v) for v in re.findall(r"-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?", text)]


def parse_transform_attr(text):
    """L'attribut `transform` d'un élément SVG (translate, scale, rotate, matrix)."""
    m = IDENTITY
    if not text:
        return None
    for name, args in re.findall(r"(\w+)\s*\(([^)]*)\)", text):
        v = nums(args)
        if name == "translate":
            t = [1, 0, 0, 1, v[0], v[1] if len(v) > 1 else 0]
        elif name == "scale":
            sx = v[0]
            sy = v[1] if len(v) > 1 else sx
            t = [sx, 0, 0, sy, 0, 0]
        elif name == "rotate":
            r = math.radians(v[0])
            t = [math.cos(r), math.sin(r), -math.sin(r), math.cos(r), 0, 0]
            if len(v) == 3:
                cx, cy = v[1], v[2]
                t = mul(mul([1, 0, 0, 1, cx, cy], t), [1, 0, 0, 1, -cx, -cy])
        elif name == "matrix":
            t = v[:6]
        else:
            raise ValueError(f"transformation inconnue : {name}")
        m = mul(m, t)
    return [round(x, 6) for x in m]


# ---------------------------------------------------------------------------------------------
# Tracés
# ---------------------------------------------------------------------------------------------

def tokenize_path(d):
    for token in re.findall(r"[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?", d):
        yield token


def arc_to_cubics(x1, y1, rx, ry, phi, large, sweep, x2, y2):
    """Arc elliptique (paramétrage SVG) → courbes de Bézier cubiques."""
    if rx == 0 or ry == 0:
        return [("L", x2, y2)]
    phi = math.radians(phi)
    cos_p, sin_p = math.cos(phi), math.sin(phi)
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p = cos_p * dx + sin_p * dy
    y1p = -sin_p * dx + cos_p * dy
    rx, ry = abs(rx), abs(ry)
    lam = x1p ** 2 / rx ** 2 + y1p ** 2 / ry ** 2
    if lam > 1:
        rx *= math.sqrt(lam)
        ry *= math.sqrt(lam)
    num = rx ** 2 * ry ** 2 - rx ** 2 * y1p ** 2 - ry ** 2 * x1p ** 2
    den = rx ** 2 * y1p ** 2 + ry ** 2 * x1p ** 2
    coef = math.sqrt(max(0, num / den)) if den else 0
    if large == sweep:
        coef = -coef
    cxp = coef * rx * y1p / ry
    cyp = -coef * ry * x1p / rx
    cx = cos_p * cxp - sin_p * cyp + (x1 + x2) / 2
    cy = sin_p * cxp + cos_p * cyp + (y1 + y2) / 2

    def angle(ux, uy, vx, vy):
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return a

    theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dtheta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and dtheta > 0:
        dtheta -= 2 * math.pi
    elif sweep and dtheta < 0:
        dtheta += 2 * math.pi
    segments = max(1, math.ceil(abs(dtheta) / (math.pi / 2)))
    delta = dtheta / segments
    t = 4 / 3 * math.tan(delta / 4)
    out = []
    for i in range(segments):
        a1 = theta1 + i * delta
        a2 = a1 + delta
        e1x, e1y = math.cos(a1), math.sin(a1)
        e2x, e2y = math.cos(a2), math.sin(a2)
        p1 = (e1x - t * e1y, e1y + t * e1x)
        p2 = (e2x + t * e2y, e2y - t * e2x)
        p3 = (e2x, e2y)

        def to_user(p):
            x, y = p[0] * rx, p[1] * ry
            return cos_p * x - sin_p * y + cx, sin_p * x + cos_p * y + cy

        c1, c2, end = to_user(p1), to_user(p2), to_user(p3)
        out.append(("C", c1[0], c1[1], c2[0], c2[1], end[0], end[1]))
    return out


def parse_path(d):
    """Un attribut `d` → liste de commandes absolues M, L, C, Z."""
    tokens = list(tokenize_path(d))
    out = []
    i = 0
    cmd = None
    x = y = 0.0
    sx = sy = 0.0
    last_ctrl = None  # dernier point de contrôle cubique (pour S)
    last_qctrl = None  # dernier point de contrôle quadratique (pour T)

    def take(n):
        nonlocal i
        vals = [float(v) for v in tokens[i:i + n]]
        i += n
        return vals

    while i < len(tokens):
        tok = tokens[i]
        if re.match(r"[A-Za-z]", tok):
            cmd = tok
            i += 1
            if cmd in "Zz":
                out.append(("Z",))
                x, y = sx, sy
                last_ctrl = last_qctrl = None
                continue
        rel = cmd.islower()
        c = cmd.upper()
        if c == "M":
            nx, ny = take(2)
            if rel:
                nx, ny = x + nx, y + ny
            out.append(("M", nx, ny))
            x, y = sx, sy = nx, ny
            cmd = "l" if rel else "L"
            last_ctrl = last_qctrl = None
        elif c == "L":
            nx, ny = take(2)
            if rel:
                nx, ny = x + nx, y + ny
            out.append(("L", nx, ny))
            x, y = nx, ny
            last_ctrl = last_qctrl = None
        elif c == "H":
            (nx,) = take(1)
            if rel:
                nx += x
            out.append(("L", nx, y))
            x = nx
            last_ctrl = last_qctrl = None
        elif c == "V":
            (ny,) = take(1)
            if rel:
                ny += y
            out.append(("L", x, ny))
            y = ny
            last_ctrl = last_qctrl = None
        elif c == "C":
            x1, y1, x2, y2, nx, ny = take(6)
            if rel:
                x1, y1, x2, y2, nx, ny = x + x1, y + y1, x + x2, y + y2, x + nx, y + ny
            out.append(("C", x1, y1, x2, y2, nx, ny))
            last_ctrl = (x2, y2)
            last_qctrl = None
            x, y = nx, ny
        elif c == "S":
            x2, y2, nx, ny = take(4)
            if rel:
                x2, y2, nx, ny = x + x2, y + y2, x + nx, y + ny
            x1, y1 = (2 * x - last_ctrl[0], 2 * y - last_ctrl[1]) if last_ctrl else (x, y)
            out.append(("C", x1, y1, x2, y2, nx, ny))
            last_ctrl = (x2, y2)
            last_qctrl = None
            x, y = nx, ny
        elif c == "Q":
            qx, qy, nx, ny = take(4)
            if rel:
                qx, qy, nx, ny = x + qx, y + qy, x + nx, y + ny
            out.append(("C", x + 2 / 3 * (qx - x), y + 2 / 3 * (qy - y),
                        nx + 2 / 3 * (qx - nx), ny + 2 / 3 * (qy - ny), nx, ny))
            last_qctrl = (qx, qy)
            last_ctrl = None
            x, y = nx, ny
        elif c == "T":
            nx, ny = take(2)
            if rel:
                nx, ny = x + nx, y + ny
            qx, qy = (2 * x - last_qctrl[0], 2 * y - last_qctrl[1]) if last_qctrl else (x, y)
            out.append(("C", x + 2 / 3 * (qx - x), y + 2 / 3 * (qy - y),
                        nx + 2 / 3 * (qx - nx), ny + 2 / 3 * (qy - ny), nx, ny))
            last_qctrl = (qx, qy)
            last_ctrl = None
            x, y = nx, ny
        elif c == "A":
            rx, ry, phi, large, sweep, nx, ny = take(7)
            if rel:
                nx, ny = x + nx, y + ny
            out.extend(arc_to_cubics(x, y, rx, ry, phi, int(large), int(sweep), nx, ny))
            x, y = nx, ny
            last_ctrl = last_qctrl = None
        else:
            raise ValueError(f"commande de tracé inconnue : {cmd}")
    return out


def ellipse_path(cx, cy, rx, ry):
    k = 0.5522847498
    return [
        ("M", cx + rx, cy),
        ("C", cx + rx, cy + k * ry, cx + k * rx, cy + ry, cx, cy + ry),
        ("C", cx - k * rx, cy + ry, cx - rx, cy + k * ry, cx - rx, cy),
        ("C", cx - rx, cy - k * ry, cx - k * rx, cy - ry, cx, cy - ry),
        ("C", cx + k * rx, cy - ry, cx + rx, cy - k * ry, cx + rx, cy),
        ("Z",),
    ]


def rect_path(x, y, w, h, rx, ry):
    rx = min(rx, w / 2)
    ry = min(ry, h / 2)
    if rx <= 0 or ry <= 0:
        return [("M", x, y), ("L", x + w, y), ("L", x + w, y + h), ("L", x, y + h), ("Z",)]
    k = 0.5522847498
    return [
        ("M", x + rx, y),
        ("L", x + w - rx, y),
        ("C", x + w - rx + k * rx, y, x + w, y + ry - k * ry, x + w, y + ry),
        ("L", x + w, y + h - ry),
        ("C", x + w, y + h - ry + k * ry, x + w - rx + k * rx, y + h, x + w - rx, y + h),
        ("L", x + rx, y + h),
        ("C", x + rx - k * rx, y + h, x, y + h - ry + k * ry, x, y + h - ry),
        ("L", x, y + ry),
        ("C", x, y + ry - k * ry, x + rx - k * rx, y, x + rx, y),
        ("Z",),
    ]


def path_points(commands, steps=24):
    """Points échantillonnés le long du tracé, pour sa boîte exacte."""
    pts = []
    cx = cy = 0.0
    for c in commands:
        if c[0] in ("M", "L"):
            cx, cy = c[1], c[2]
            pts.append((cx, cy))
        elif c[0] == "C":
            x0, y0 = cx, cy
            x1, y1, x2, y2, x3, y3 = c[1:]
            for s in range(1, steps + 1):
                t = s / steps
                mt = 1 - t
                px = mt ** 3 * x0 + 3 * mt * mt * t * x1 + 3 * mt * t * t * x2 + t ** 3 * x3
                py = mt ** 3 * y0 + 3 * mt * mt * t * y1 + 3 * mt * t * t * y2 + t ** 3 * y3
                pts.append((px, py))
            cx, cy = x3, y3
    return pts


def bbox(points):
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return [min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)]


# ---------------------------------------------------------------------------------------------
# Couleurs et dégradés
# ---------------------------------------------------------------------------------------------

def frac(value, default):
    if value is None:
        return default
    value = value.strip()
    if value.endswith("%"):
        return float(value[:-1]) / 100
    return float(value)


def color(value):
    value = value.strip()
    named = {"#fff": "FFFFFF", "#000": "000000", "white": "FFFFFF", "black": "000000"}
    if value.lower() in named:
        return named[value.lower()]
    if re.fullmatch(r"#[0-9A-Fa-f]{6}", value):
        return value[1:].upper()
    if re.fullmatch(r"#[0-9A-Fa-f]{3}", value):
        return "".join(ch * 2 for ch in value[1:]).upper()
    raise ValueError(f"couleur inconnue : {value}")


def read_gradients(defs, prefix):
    gradients = {}
    for g in defs:
        tag = g.tag.replace(NS, "")
        gid = g.get("id").replace(prefix, "")
        stops = []
        for s in g:
            off = frac(s.get("offset"), 0)
            stops.append([round(off, 4), color(s.get("stop-color")), float(s.get("stop-opacity", "1"))])
        units = "user" if g.get("gradientUnits") == "userSpaceOnUse" else "bbox"
        if tag == "linearGradient":
            gradients[gid] = {
                "k": "lin", "units": units, "stops": stops,
                "x1": frac(g.get("x1"), 0), "y1": frac(g.get("y1"), 0),
                "x2": frac(g.get("x2"), 1), "y2": frac(g.get("y2"), 0),
            }
        else:
            cx = frac(g.get("cx"), 0.5)
            cy = frac(g.get("cy"), 0.5)
            gradients[gid] = {
                "k": "rad", "units": units, "stops": stops,
                "cx": cx, "cy": cy, "r": frac(g.get("r"), 0.5),
            }
    return gradients


def paint(value, gradients, prefix):
    if value is None or value == "none":
        return None
    m = re.fullmatch(r"url\(#(.+)\)", value.strip())
    if m:
        return dict(gradients[m.group(1).replace(prefix, "")])
    return {"k": "solid", "rgb": color(value)}


# ---------------------------------------------------------------------------------------------
# Le dessin
# ---------------------------------------------------------------------------------------------

INHERITED = ("fill", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin")


def inline_style(el):
    out = {}
    for part in (el.get("style") or "").split(";"):
        if ":" in part:
            k, v = part.split(":", 1)
            out[k.strip()] = v.strip()
    return out


def seconds(value):
    value = value.strip()
    if value.endswith("ms"):
        return float(value[:-2]) / 1000
    return float(value.rstrip("s"))


def build(el, inherited, gradients, prefix, counter):
    tag = el.tag.replace(NS, "")
    attrs = dict(inherited)
    for key in INHERITED:
        if el.get(key) is not None:
            attrs[key] = el.get(key)
    node = {"id": counter[0]}
    counter[0] += 1
    classes = (el.get("class") or "").split()
    if classes:
        node["c"] = classes
    m = parse_transform_attr(el.get("transform"))
    if m and m != IDENTITY:
        node["m"] = m
    if el.get("opacity") is not None:
        node["o"] = float(el.get("opacity"))
    style = inline_style(el)
    if "animation-delay" in style:
        node["delay"] = seconds(style["animation-delay"])
    if "animation-duration" in style:
        node["dur"] = seconds(style["animation-duration"])
    if "fill" in style:
        attrs["fill"] = style["fill"]

    if tag == "g":
        node["t"] = "g"
        kids = []
        for child in el:
            if child.tag.replace(NS, "") in ("g", "path", "ellipse", "circle", "rect"):
                kids.append(build(child, attrs, gradients, prefix, counter))
        node["kids"] = kids
        boxes = []
        for k in kids:
            if "bb" in k:
                x, y, w, h = k["bb"]
                corners = [(x, y), (x + w, y), (x, y + h), (x + w, y + h)]
                km = k.get("m", IDENTITY)
                boxes.extend(apply(km, px, py) for px, py in corners)
        if boxes:
            node["bb"] = [round(v, 3) for v in bbox(boxes)]
        return node

    f = lambda key, default=0.0: float(el.get(key, default))
    if tag == "path":
        commands = parse_path(el.get("d"))
    elif tag == "ellipse":
        commands = ellipse_path(f("cx"), f("cy"), f("rx"), f("ry"))
    elif tag == "circle":
        commands = ellipse_path(f("cx"), f("cy"), f("r"), f("r"))
    elif tag == "rect":
        rx = el.get("rx")
        ry = el.get("ry", rx)
        commands = rect_path(f("x"), f("y"), f("width"), f("height"),
                             float(rx or 0), float(ry or 0))
    else:
        raise ValueError(tag)

    node["t"] = "s"
    node["d"] = [[c[0]] + [round(v, 3) for v in c[1:]] for c in commands]
    node["bb"] = [round(v, 3) for v in bbox(path_points(commands))]
    fill = paint(attrs.get("fill", "#000"), gradients, prefix)
    stroke = paint(attrs.get("stroke"), gradients, prefix)
    if fill:
        node["fill"] = fill
    if stroke:
        node["stroke"] = stroke
        node["sw"] = float(attrs.get("stroke-width", "1"))
        node["cap"] = attrs.get("stroke-linecap", "butt")
        node["join"] = attrs.get("stroke-linejoin", "miter")
    return node


# ---------------------------------------------------------------------------------------------
# Le mouvement
# ---------------------------------------------------------------------------------------------

EASINGS = {
    "linear": [0, 0, 1, 1],
    "ease": [0.25, 0.1, 0.25, 1],
    "ease-in": [0.42, 0, 1, 1],
    "ease-out": [0, 0, 0.58, 1],
    "ease-in-out": [0.42, 0, 0.58, 1],
}


def parse_transform_css(text):
    """Une transformation CSS → ses composantes. Les fonctions de ce design se composent
    toutes dans l'ordre translation, rotation, échelle (et une échelle non uniforme n'est
    jamais combinée à une rotation), ce qui rend la décomposition exacte."""
    out = {}
    for name, args in re.findall(r"([\w]+)\(([^)]*)\)", text):
        v = nums(args)
        if name == "translate":
            out["tx"] = v[0]
            out["ty"] = v[1] if len(v) > 1 else 0.0
        elif name == "translateX":
            out["tx"] = v[0]
        elif name == "translateY":
            out["ty"] = v[0]
        elif name == "scale":
            out["sx"] = v[0]
            out["sy"] = v[1] if len(v) > 1 else v[0]
        elif name == "scaleX":
            out["sx"] = v[0]
        elif name == "scaleY":
            out["sy"] = v[0]
        elif name == "rotate":
            out["rot"] = v[0]
        else:
            raise ValueError(f"fonction CSS inconnue : {name}")
    return out


def component_list(t):
    return [t.get("tx", 0.0), t.get("ty", 0.0), t.get("rot", 0.0), t.get("sx", 1.0), t.get("sy", 1.0)]


def parse_css(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"@media[^{]*\{(?:[^{}]*\{[^{}]*\})*[^{}]*\}", "", text)
    keyframes = {}
    for name, body in re.findall(r"@keyframes\s+([\w-]+)\s*\{((?:[^{}]*\{[^{}]*\})*)\s*\}", text):
        transform_track = []
        opacity_track = []
        for sel, decl in re.findall(r"([^{}]+)\{([^{}]*)\}", body):
            props = dict(
                (k.strip(), v.strip()) for k, v in
                (p.split(":", 1) for p in decl.split(";") if ":" in p)
            )
            for s in sel.split(","):
                s = s.strip()
                off = {"from": 0.0, "to": 1.0}.get(s)
                if off is None:
                    off = float(s.rstrip("%")) / 100
                if "transform" in props:
                    transform_track.append([off] + component_list(parse_transform_css(props["transform"])))
                if "opacity" in props:
                    opacity_track.append([off, float(props["opacity"])])
        entry = {}
        if transform_track:
            entry["transform"] = sorted(transform_track)
        if opacity_track:
            entry["opacity"] = sorted(opacity_track)
        keyframes[name] = entry
    text = re.sub(r"@keyframes\s+[\w-]+\s*\{(?:[^{}]*\{[^{}]*\})*\s*\}", "", text)

    rules = []
    order = 0
    for sel, decl in re.findall(r"([^{}]+)\{([^{}]*)\}", text):
        props = [(k.strip(), v.strip()) for k, v in (p.split(":", 1) for p in decl.split(";") if ":" in p)]
        for s in sel.split(","):
            s = s.strip()
            m = re.fullmatch(r"\.mico(\.s-([\w-]+))?((?:\s+\.[\w-]+)+|\s+\*)", s)
            if not m:
                continue  # .mico{…}, .mico:not(.static), .mico.static …
            mood = m.group(2)
            chain = re.findall(r"\.([\w-]+)", m.group(3))
            universal = m.group(3).strip() == "*"
            specificity = 1 + (1 if mood else 0) + len(chain)
            rules.append({
                "mood": mood, "chain": chain, "universal": universal,
                "spec": specificity, "order": order, "props": props,
            })
            order += 1
    return keyframes, rules


def parse_animation(value):
    if value.strip() == "none":
        return None
    tokens = re.findall(r"cubic-bezier\([^)]*\)|\S+", value)
    anim = {"name": None, "dur": None, "ease": EASINGS["ease"], "alternate": False}
    times = []
    for tok in tokens:
        if tok.startswith("mc-"):
            anim["name"] = tok
        elif re.fullmatch(r"-?[\d.]+m?s", tok):
            times.append(seconds(tok))
        elif tok in EASINGS:
            anim["ease"] = EASINGS[tok]
        elif tok.startswith("cubic-bezier"):
            anim["ease"] = nums(tok)
        elif tok == "alternate":
            anim["alternate"] = True
        elif tok in ("infinite", "normal"):
            pass
        else:
            raise ValueError(f"animation : jeton inconnu {tok}")
    anim["dur"] = times[0]
    anim["delay"] = times[1] if len(times) > 1 else 0.0
    return anim


def resolve_origin(value, fill_box, box):
    parts = value.split()
    if len(parts) == 1:
        parts.append("50%")
    out = []
    for i, p in enumerate(parts[:2]):
        if p.endswith("%"):
            f = float(p[:-1]) / 100
            if fill_box:
                out.append(box[i] + f * box[i + 2])
            else:
                out.append(f * 220)  # la boîte de vue : 220 × 220, posée à l'origine
        else:
            v = float(p.rstrip("px"))
            out.append(box[i] + v if fill_box else v)
    return [round(v, 3) for v in out]


def matches(rule, node, ancestors):
    if rule["universal"]:
        return True
    classes = node.get("c", [])
    *head, last = rule["chain"]
    if last not in classes:
        return False
    # Les classes qui précèdent doivent se trouver chez les ancêtres, dans l'ordre.
    pool = list(ancestors)
    for cls in reversed(head):
        while pool and cls not in pool[-1]:
            pool.pop()
        if not pool:
            return False
        pool.pop()
    return True


def resolve_styles(node, ancestors, rules, fill_box_classes, fade_classes):
    classes = node.get("c", [])
    if classes:
        styles = {}
        base_box = node.get("bb", [0, 0, 0, 0])
        for mood in MOODS:
            applicable = [r for r in rules
                          if (r["mood"] is None or r["mood"] == mood)
                          and (classes or r["universal"])
                          and matches(r, node, ancestors)]
            applicable.sort(key=lambda r: (r["spec"], r["order"]))
            props = {}
            for r in applicable:
                for k, v in r["props"]:
                    props[k] = v
            fill_box = props.get("transform-box") == "fill-box"
            style = {}
            if "animation" in props:
                anim = parse_animation(props["animation"])
                if anim:
                    if "delay" in node:
                        anim["delay"] = node["delay"]
                    if "dur" in node:
                        anim["dur"] = node["dur"]
                    style["anim"] = anim
            if "transform" in props:
                style["tf"] = component_list(parse_transform_css(props["transform"]))
            if "opacity" in props:
                style["op"] = float(props["opacity"])
            if "transform-origin" in props:
                style["origin"] = resolve_origin(props["transform-origin"], fill_box, base_box)
            elif "anim" in style or "tf" in style:
                # Sans `transform-origin`, un élément SVG tourne autour de « 0 0 » de sa
                # boîte de référence (feuille de style du navigateur), pas de son centre.
                style["origin"] = resolve_origin("0 0", fill_box, base_box)
            if style:
                styles[mood] = style
        if styles:
            node["st"] = styles
        if any(c in fade_classes for c in classes):
            node["fade"] = True
    for kid in node.get("kids", []):
        resolve_styles(kid, ancestors + [classes], rules, fill_box_classes, fade_classes)


def main():
    svg_text = SVG.read_text(encoding="utf-8")
    root = ET.fromstring(svg_text)
    view_box = nums(root.get("viewBox"))
    defs = root.find(f"{NS}defs")
    first_id = defs[0].get("id")
    prefix = first_id[: first_id.index("-", 2) + 1]  # « m-idle- »
    gradients = read_gradients(defs, prefix)

    counter = [0]
    nodes = []
    for child in root:
        tag = child.tag.replace(NS, "")
        if tag in ("g", "path", "ellipse", "circle", "rect"):
            nodes.append(build(child, {}, gradients, prefix, counter))

    keyframes, rules = parse_css(CSS.read_text(encoding="utf-8"))
    fill_box_classes = set()
    fade_classes = set()
    for r in rules:
        for k, v in r["props"]:
            if k == "transform-box" and v == "fill-box" and r["chain"]:
                fill_box_classes.add(r["chain"][-1])
            if k == "transition" and "opacity" in v and r["chain"]:
                fade_classes.add(r["chain"][-1])
    for n in nodes:
        resolve_styles(n, [], rules, fill_box_classes, fade_classes)

    used = set()

    def collect(n):
        for st in n.get("st", {}).values():
            if "anim" in st:
                used.add(st["anim"]["name"])
        for k in n.get("kids", []):
            collect(k)

    for n in nodes:
        collect(n)
    missing = used - set(keyframes)
    if missing:
        sys.exit(f"animations sans images clés : {sorted(missing)}")

    data = {
        "viewBox": view_box,
        "moods": MOODS,
        "fade": 0.18,
        "keyframes": {k: v for k, v in sorted(keyframes.items()) if k in used},
        "nodes": nodes,
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)} : {counter[0]} calques, {len(data['keyframes'])} animations, "
          f"{OUT.stat().st_size // 1024} Ko")


if __name__ == "__main__":
    main()
