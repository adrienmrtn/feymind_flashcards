import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * **Mika, du design au site.**
 *
 * La mascotte arrive en deux fichiers, `design/mika/mika.svg` (le dessin, chaque partie du
 * corps dans son calque) et `design/mika/mika.css` (les huit humeurs : ce qui bouge, autour
 * de quel point, sur quelles images clés). C'est leur format d'origine, celui d'un
 * navigateur : l'iPhone les traduit en natif (`scripts/generate-mika.py`), le site les
 * prend tels quels.
 *
 * Ce script écrit deux fichiers que `components/mika/Mika.tsx` lit :
 * - `components/mika/mika-art.ts` — le `viewBox` et le corps du SVG, sans sa feuille de style
 *   embarquée (elle ferait doublon avec le CSS) ;
 * - `components/mika/mika.css` — la feuille de style, copiée.
 *
 * `lib/mika.test.ts` recalcule les deux et échoue si une copie a dérivé.
 *
 *     node web/scripts/sync-mika.mjs
 */

const here = dirname(fileURLToPath(import.meta.url));
export const repoRoot = resolve(here, "../..");
export const SVG_SOURCE = resolve(repoRoot, "design/mika/mika.svg");
export const CSS_SOURCE = resolve(repoRoot, "design/mika/mika.css");
export const ART_TARGET = resolve(here, "../components/mika/mika-art.ts");
export const CSS_TARGET = resolve(here, "../components/mika/mika.css");

export const CSS_HEADER = `/* Copie de design/mika/mika.css, écrite par web/scripts/sync-mika.mjs. Ne pas éditer à la main. */
`;

/** Le `viewBox` et le corps du SVG, sans l'en-tête XML ni la feuille de style embarquée. */
export function extractArt(svg = readFileSync(SVG_SOURCE, "utf8")) {
  const open = svg.match(/<svg\b([^>]*)>/);
  if (!open) throw new Error(`${SVG_SOURCE} : balise <svg> introuvable.`);
  const viewBox = open[1].match(/viewBox="([^"]+)"/)?.[1];
  if (!viewBox) throw new Error(`${SVG_SOURCE} : viewBox introuvable.`);
  const close = svg.lastIndexOf("</svg>");
  if (close < 0) throw new Error(`${SVG_SOURCE} : balise </svg> introuvable.`);
  const body = svg
    .slice(open.index + open[0].length, close)
    .replace(/<style>[\s\S]*?<\/style>/, "")
    .trim();
  if (body.includes("<script")) throw new Error(`${SVG_SOURCE} : un script dans le dessin.`);
  return { viewBox, body };
}

export function artModule(art = extractArt()) {
  return `// Généré depuis design/mika/mika.svg par web/scripts/sync-mika.mjs. Ne pas éditer à la main.

/** Le cadre du dessin : Mika déborde un peu de son corps, les effets au-dessus de sa tête. */
export const MIKA_VIEWBOX = ${JSON.stringify(art.viewBox)};

/** Le corps du SVG : les calques que \`mika.css\` anime, par leur classe. */
export const MIKA_INNER = ${JSON.stringify(art.body)};
`;
}

export function cssCopy(css = readFileSync(CSS_SOURCE, "utf8")) {
  return CSS_HEADER + css;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const art = artModule();
  writeFileSync(ART_TARGET, art, "utf8");
  const css = cssCopy();
  writeFileSync(CSS_TARGET, css, "utf8");
  console.log(`Écrit ${ART_TARGET} (${art.length} octets) et ${CSS_TARGET} (${css.length} octets)`);
}
