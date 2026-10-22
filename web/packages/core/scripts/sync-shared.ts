/**
 * Recopie les catalogues partagés du serveur dans `src/lesson/`.
 *
 * Deux listes font foi côté serveur, parce que c'est là qu'elles partent dans le prompt :
 * les icônes 3D qu'un modèle peut donner à une leçon ou à un thème
 * (`supabase/functions/_shared/icons.ts`) et les pictogrammes du chemin
 * (`supabase/functions/_shared/symbols.ts`). L'app en garde une copie Swift, vérifiée par
 * ses tests ; le site en garde une copie TypeScript, vérifiée par
 * `test/shared-parity.test.ts` — à l'octet près, comme la fiche.
 *
 * Pourquoi une copie plutôt qu'un import : l'original vit hors du `rootDirectory` de Vercel.
 *
 * Usage : pnpm --filter @micabo/core sync:shared
 */

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "../../../..");

export interface SharedCopy {
  /** Le nom, pour le journal et les messages. */
  name: string;
  source: string;
  target: string;
  header: string;
}

function header(original: string, script: string): string {
  return `/**
 * **Copie conforme du serveur** : l'original est \`${original}\`, et c'est lui qui fait foi,
 * parce que c'est lui qui part dans le prompt. \`test/shared-parity.test.ts\` relit les deux
 * fichiers et échoue à l'octet près si l'un des deux bouge.
 *
 * NE PAS MODIFIER CE FICHIER À LA MAIN. Modifier l'original, puis relancer :
 *   pnpm --filter @micabo/core ${script}
 */

`;
}

export const SHARED_COPIES: readonly SharedCopy[] = [
  {
    name: "icônes",
    source: resolve(repoRoot, "supabase/functions/_shared/icons.ts"),
    target: resolve(here, "../src/lesson/icons.ts"),
    header: header("supabase/functions/_shared/icons.ts", "sync:shared"),
  },
  {
    name: "pictogrammes",
    source: resolve(repoRoot, "supabase/functions/_shared/symbols.ts"),
    target: resolve(here, "../src/lesson/symbols.ts"),
    header: header("supabase/functions/_shared/symbols.ts", "sync:shared"),
  },
];

/** Ce que la copie doit contenir : l'en-tête, puis l'original tel quel. */
export function expectedCopy(copy: SharedCopy, source = readFileSync(copy.source, "utf8")): string {
  if (/^import\s/m.test(source)) {
    throw new Error(`${copy.source} importe un module : la copie ne saurait pas le résoudre.`);
  }
  return copy.header + source;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  for (const copy of SHARED_COPIES) {
    const contents = expectedCopy(copy);
    writeFileSync(copy.target, contents, "utf8");
    console.log(`Copié ${copy.source}\n     -> ${copy.target} (${contents.length} octets)`);
  }
}
