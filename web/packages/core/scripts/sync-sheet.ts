/**
 * Recopie le module de fiche du serveur dans `src/sheet/canonical.ts`.
 *
 * L'original, `supabase/functions/_shared/sheet.ts`, fait foi : c'est lui qui normalise la
 * fiche quand le modèle la rend, et qui calcule le `context_text` enregistré en base. Le site
 * en garde une copie parce que l'original tourne sous Deno et vit hors du `rootDirectory` de
 * Vercel — et `test/sheet-parity.test.ts` échoue à l'octet près si les deux divergent.
 *
 * Usage : pnpm --filter @micabo/core sync:sheet
 */

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "../../../..");

export const SOURCE = resolve(repoRoot, "supabase/functions/_shared/sheet.ts");
export const TARGET = resolve(here, "../src/sheet/canonical.ts");
export const ANCHOR = "export type SheetBlock =";

export const HEADER = `/**
 * Le module de fiche, **copie conforme du serveur**.
 *
 * L'original est \`supabase/functions/_shared/sheet.ts\`, et c'est lui qui fait foi : c'est ce
 * code qui normalise la fiche au moment où le modèle la rend, et qui calcule le
 * \`context_text\` enregistré en base. Le site doit donc lire une fiche exactement comme le
 * serveur l'a écrite — un plafond appliqué d'un côté et pas de l'autre donnerait une page
 * différente selon l'appareil.
 *
 * Pourquoi une copie plutôt qu'un import : l'original tourne sous Deno, importe ses modules
 * avec l'extension \`.ts\`, et le \`rootDirectory\` de Vercel est \`web/\`, donc \`supabase/\` n'est
 * même pas dans le contexte de compilation du site. La copie est le compromis honnête, et elle
 * est **surveillée** : \`test/sheet-parity.test.ts\` relit les deux fichiers et échoue à l'octet
 * près si l'un des deux bouge. Le jour où les Edge Functions passeront au jeton de
 * l'utilisateur — étape 4 — sera le bon moment pour n'en garder qu'un seul.
 *
 * Une seule différence avec l'original, et le test la connaît : \`stripEmDashes\` est importé
 * d'ici et non de \`fal.ts\`, qui lit \`Deno.env\`.
 *
 * NE PAS MODIFIER CE FICHIER À LA MAIN. Modifier l'original, puis relancer :
 *   pnpm --filter @micabo/core sync:sheet
 */

// @ts-nocheck — et c'est le seul fichier du dépôt qui y a droit.
//
// Le site compile avec \`noUncheckedIndexedAccess\`, l'original tourne sous \`deno check\`, qui ne
// l'active pas : une dizaine d'accès indexés du corps ne passent donc pas ici. Les corriger
// serait modifier la copie, donc la faire diverger, donc casser la seule garantie qu'on a — et
// les corriger en amont serait durcir du code serveur pour un réglage du site.
//
// Ce qui vérifie ce fichier, à la place : \`deno task verify\` en amont, le test de parité qui le
// compare à l'octet près, et les tests de \`@micabo/core\` qui le font tourner. La suppression
// s'arrête à ce fichier ; tout ce qui l'importe est vérifié normalement.

import { stripEmDashes } from "./em-dashes";

`;

/** Le corps canonique : tout l'original à partir de la première déclaration exportée. */
export function canonicalBody(source = readFileSync(SOURCE, "utf8")) {
  const index = source.indexOf(ANCHOR);
  if (index < 0) {
    throw new Error(`Ancre « ${ANCHOR} » introuvable dans ${SOURCE}.`);
  }
  return source.slice(index);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const contents = HEADER + canonicalBody();
  writeFileSync(TARGET, contents, "utf8");
  console.log(`Copié ${SOURCE}\n     -> ${TARGET} (${contents.length} octets)`);
}
