/**
 * Les deux palettes qui sont des **données** et non du style.
 *
 * Le reste des jetons vit dans `app/globals.css`, où Tailwind en fait des utilitaires : une
 * couleur déclarée deux fois finit par différer. Ces deux tableaux-là sont ici parce qu'on
 * choisit dedans **par index** - la teinte d'un cours se déduit de son identifiant, ce qui est
 * de la logique, pas de la présentation. Et la même logique doit donner la même couleur au
 * même cours sur le téléphone et sur le web, sinon l'étagère change de couleur en changeant
 * d'appareil.
 *
 * Recopiées depuis `MicaboColor.courseAccents` et `MicaboColor.tilePastels`.
 */

/** Teintes de couverture attribuées aux cours, lisibles avec du texte blanc. */
export const COURSE_ACCENTS: readonly string[] = [
  "#2E7D63",
  "#9A5B36",
  "#3F5F8A",
  "#8A4A6B",
  "#0B8A66",
  "#B07A2E",
  "#4C7A3A",
  "#6B4E8A",
];

/** Pastels des tuiles d'icône, quand aucune teinte de cours n'est disponible. */
export const TILE_PASTELS: readonly string[] = [
  "#DFF2E8",
  "#E4F0DC",
  "#FBEBDA",
  "#DFEAF8",
  "#F8E4EC",
  "#F6F0D6",
];

/**
 * Somme stable des octets d'une chaîne : deux appareils doivent tomber sur la même teinte pour
 * le même cours, donc on ne peut pas se reposer sur un hachage dépendant de la plateforme.
 */
function stableHash(value: string): number {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.charCodeAt(index)) % 0x7fffffff;
  }
  return hash;
}

export function courseAccent(seed: string): string {
  return COURSE_ACCENTS[stableHash(seed) % COURSE_ACCENTS.length]!;
}

export function tilePastel(seed: string): string {
  return TILE_PASTELS[stableHash(seed) % TILE_PASTELS.length]!;
}

/** Mélange avec du blanc : dérive un fond pastel à partir d'une teinte de cours. */
export function lightened(hex: string, amount: number): string {
  const value = hex.replace("#", "");
  const red = parseInt(value.slice(0, 2), 16);
  const green = parseInt(value.slice(2, 4), 16);
  const blue = parseInt(value.slice(4, 6), 16);
  const mix = (channel: number) => Math.round(channel + (255 - channel) * amount);
  return `#${[mix(red), mix(green), mix(blue)]
    .map((channel) => channel.toString(16).padStart(2, "0").toUpperCase())
    .join("")}`;
}
