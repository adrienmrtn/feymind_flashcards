import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

/**
 * **Mika, du design au site** (direction artistique V3.3).
 *
 * Le personnage plat et vectoriel de l'app est dessiné par une seule fonction,
 * `design/mika-v3/mika.js` (`mika(o)`, viewBox « -10 -30 420 420 », pieds posés vers y = 344) :
 * c'est la source de vérité que l'iPhone retrace en SwiftUI (`MikaArt.swift`). Ce script
 * l'exécute dans un bac à sable, pose chaque humeur (les mêmes paramètres que
 * `design/mika-v3/apercu.html`) et écrit `components/mika/mika-art.ts` : un SVG par humeur.
 *
 * Le corps et les tentacules arrière ne sont pas des couleurs écrites : ils lisent
 * `--mika-body` et `--mika-shade` (#5C88FF et #3F6BE8 sur le marine, #3870FE et #2A5BE0 sur
 * le clair, `globals.css`). Le même dessin suit donc le thème.
 *
 * `lib/mika.test.ts` recalcule le fichier et échoue si la copie a dérivé.
 *
 *     node web/scripts/sync-mika.mjs
 */

const here = dirname(fileURLToPath(import.meta.url));
export const repoRoot = resolve(here, "../..");
export const MIKA_SOURCE = resolve(repoRoot, "design/mika-v3/mika.js");
export const ART_TARGET = resolve(here, "../components/mika/mika-art.ts");

export const VIEWBOX = "-10 -30 420 420";

const BODY = "__MIKA_BODY__";
const SHADE = "__MIKA_SHADE__";

/** Les humeurs, et ce que chacune change au repos (`apercu.html`). `air` = ce qui flotte. */
export const POSES = {
  idle: () => ({}),
  happy: () => ({ eyes: "happy", mouth: "open" }),
  wave: () => ({ leftArm: "wave", mouth: "open" }),
  wink: () => ({ eyes: "wink", mouth: "smile" }),
  celebrate: (air) => ({ eyes: "happy", mouth: "open", leftArm: "up", rightArm: "up", extra: air.confetti }),
  think: (air) => ({ px: 8, py: -13, mouth: "small", extra: air.dots }),
  write: (air) => ({ px: 9, py: -3, mouth: "small", rightArm: "tilt", extra: air.lines }),
  surprise: () => ({ eyes: "wide", mouth: "o" }),
  sad: () => ({ py: 6, mouth: "sad", rightArm: "rest" }),
  sleep: (air) => ({ eyes: "closed", mouth: "flat", rightArm: "rest", extra: air.zzz }),
  look: () => ({ px: 10, py: -2, mouth: "small" }),
  proud: () => ({ eyes: "happy", mouth: "smile", rightArm: "up" }),
};

/** Exécute `mika.js` et rend la fonction de dessin et ce qui flotte autour de lui. */
export function loadMika(source = readFileSync(MIKA_SOURCE, "utf8")) {
  const sandbox = { window: {} };
  vm.runInNewContext(source, sandbox, { filename: "mika.js" });
  if (typeof sandbox.window.mika !== "function") throw new Error(`${MIKA_SOURCE} : window.mika introuvable.`);
  return { draw: sandbox.window.mika, air: sandbox.window.MIKA };
}

/** Le corps d'un SVG, ses couleurs de corps remplacées par les variables du thème. */
export function inner(svg) {
  const open = svg.match(/<svg\b[^>]*>/);
  const close = svg.lastIndexOf("</svg>");
  if (!open || close < 0) throw new Error("mika.js : balise <svg> introuvable.");
  const body = svg
    .slice(open.index + open[0].length, close)
    .replaceAll(`fill="${BODY}"`, 'style="fill:var(--mika-body,#5C88FF)"')
    .replaceAll(`stroke="${BODY}"`, 'style="stroke:var(--mika-body,#5C88FF)"')
    .replaceAll(`stroke="${SHADE}"`, 'style="stroke:var(--mika-shade,#3F6BE8)"')
    .replace(/>\s+</g, "><")
    .trim();
  if (body.includes(BODY) || body.includes(SHADE)) throw new Error("mika.js : une couleur de corps n'a pas été remplacée.");
  if (body.includes("<script")) throw new Error("mika.js : un script dans le dessin.");
  return body;
}

export function poses(mika = loadMika()) {
  return Object.fromEntries(
    Object.entries(POSES).map(([name, options]) => [
      name,
      inner(mika.draw({ noShadow: true, body: BODY, shade: SHADE, viewBox: VIEWBOX, ...options(mika.air) })),
    ]),
  );
}

export function artModule(art = poses()) {
  return `// Généré depuis design/mika-v3/mika.js par web/scripts/sync-mika.mjs. Ne pas éditer à la main.

/** Le cadre du dessin : Mika et ce qui flotte au-dessus de sa tête. */
export const MIKA_VIEWBOX = ${JSON.stringify(VIEWBOX)};

/** Le corps du SVG de chaque pose. Le bleu du corps se lit dans \`--mika-body\`. */
export const MIKA_POSES = ${JSON.stringify(art, null, 2)} as const;

export type MikaPose = keyof typeof MIKA_POSES;
`;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const art = artModule();
  writeFileSync(ART_TARGET, art, "utf8");
  console.log(`Écrit ${ART_TARGET} (${art.length} octets)`);
}
