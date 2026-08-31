import { readdirSync } from "node:fs";
import { join } from "node:path";

/**
 * Les extraits vraiment déposés dans `public/landing/sources/`.
 *
 * La vitrine ne doit demander que ceux-là. Pointer un `.webp` absent envoie
 * Google (et le navigateur) sur une 404, et Search Console compte ça comme
 * une ressource de page qui n'a pas pu être chargée.
 */
export function listedLandingSourceImages(): readonly string[] {
  const dirs = [
    join(process.cwd(), "public/landing/sources"),
    join(process.cwd(), "web/public/landing/sources"),
  ];

  for (const dir of dirs) {
    try {
      return readdirSync(dir)
        .filter((name) => name.endsWith(".webp"))
        .map((name) => name.slice(0, -".webp".length))
        .sort();
    } catch {
      // Le dossier n'est pas à cet endroit-là ; on essaie le suivant.
    }
  }

  return [];
}
