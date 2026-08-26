import { cpSync, existsSync, lstatSync, readlinkSync, rmSync } from "node:fs";

/**
 * À la racine du dépôt, `app` (et les dossiers jumeaux) sont des liens vers `web/`.
 * Next compile à travers un lien, puis le collecteur de pages ne retrouve pas
 * `/_not-found`. On copie en vrais répertoires juste avant `next build`.
 * Lancé depuis `web/`, rien n'est un lien : le script ne fait rien.
 */
for (const name of ["app", "components", "lib", "packages"]) {
  if (!existsSync(name)) continue;
  if (!lstatSync(name).isSymbolicLink()) continue;
  const target = readlinkSync(name);
  rmSync(name);
  cpSync(target, name, { recursive: true });
}
