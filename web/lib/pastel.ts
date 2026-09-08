/**
 * Le pastel du site, **un seul interrupteur**.
 *
 * À `true`, le papier se teinte, les lueurs du hero et le lavage de
 * fermeture prennent les pastels des tuiles, et une nappe de taches
 * s'installe derrière les pages. À `false`, tout ça s'éteint : le site
 * reprend le gris froid de `globals.css`, sans autre modification.
 *
 * Les teintes viennent de `TILE_PASTELS` : les mêmes que les tuiles de
 * cours, pour que l'étagère et la vitrine parlent la même langue.
 */

import { TILE_PASTELS } from "@micabo/core";

type Appearance = "day" | "night" | "twilight";

/** Mettre à `false` pour retirer le pastel du site. */
export const WEBSITE_PASTEL = true;

export const PASTEL_MINT = TILE_PASTELS[0]!;
export const PASTEL_SAGE = TILE_PASTELS[1]!;
export const PASTEL_PEACH = TILE_PASTELS[2]!;
export const PASTEL_POWDER = TILE_PASTELS[3]!;
export const PASTEL_BLUSH = TILE_PASTELS[4]!;
export const PASTEL_BUTTER = TILE_PASTELS[5]!;

/** Papier du jour, assez teinté pour se voir, pas assez pour devenir de la crème. */
export const PASTEL_THEME_COLOR: Record<Appearance, string> = {
  day: "#f3f1f8",
  night: "#13141c",
  twilight: "#1e1716",
};

export const PASTEL_SHADER: Record<
  Appearance,
  { mesh: string[]; grain: string[]; back: string }
> = {
  day: {
    mesh: [PASTEL_BLUSH, PASTEL_THEME_COLOR.day, PASTEL_POWDER, PASTEL_MINT],
    grain: [PASTEL_BLUSH, PASTEL_MINT, PASTEL_POWDER],
    back: PASTEL_THEME_COLOR.day,
  },
  night: {
    mesh: ["#3a2a38", "#13141c", "#24344a", "#1e3a32"],
    grain: ["#3a2a38", "#13141c", "#24344a"],
    back: PASTEL_THEME_COLOR.night,
  },
  twilight: {
    mesh: ["#4a3040", "#1e1716", PASTEL_POWDER, PASTEL_PEACH],
    grain: ["#4a3040", "#1e1716", PASTEL_PEACH],
    back: PASTEL_THEME_COLOR.twilight,
  },
};
