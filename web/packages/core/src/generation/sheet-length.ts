/**
 * La longueur d'une fiche, en blocs.
 *
 * Port de `SheetLength` et `SheetPreferences` (`Micabo/Services/AIService.swift`). **Le nombre de
 * blocs est la source de vérité**, et le format n'en est qu'un nom : c'est ce que l'app a tranché
 * en passant de trois boutons à un curseur continu. Le format reste envoyé à la fonction Edge, qui
 * le comprend depuis toujours, et c'est lui que la colonne `sheet_length` du profil retient.
 */

export type SheetLength = "brief" | "standard" | "deep";

export const DEFAULT_SHEET_LENGTH: SheetLength = "standard";

/** Ce que le curseur couvre, d'un bout à l'autre. Mêmes bornes que l'app. */
export const BLOCK_BOUNDS = { min: 8, max: 34 } as const;

const RANGES: Record<SheetLength, { min: number; max: number }> = {
  brief: { min: 8, max: 13 },
  standard: { min: 14, max: 23 },
  deep: { min: 24, max: 34 },
};

const TITLES: Record<SheetLength, string> = {
  brief: "L'essentiel",
  standard: "Équilibrée",
  deep: "Approfondie",
};

export const SHEET_LENGTHS: readonly SheetLength[] = ["brief", "standard", "deep"];

export function sheetLengthTitle(length: SheetLength): string {
  return TITLES[length];
}

export function blockRange(length: SheetLength): { min: number; max: number } {
  return RANGES[length];
}

/**
 * Le nombre de blocs d'un format choisi sans toucher au curseur : le milieu de sa plage, qui est
 * ce que le format décrit le mieux.
 */
export function defaultBlocks(length: SheetLength): number {
  const range = RANGES[length];
  return Math.floor((range.min + range.max) / 2);
}

/**
 * Le format auquel appartient un nombre de blocs.
 *
 * Les plages laissent des trous — c'est voulu côté modèle, ce sont des consignes et pas une
 * partition — donc il faut décider où bascule le nom. Il bascule au milieu du trou, comme là-bas.
 */
export function lengthContaining(blocks: number): SheetLength {
  if (blocks <= 13) return "brief";
  if (blocks <= 23) return "standard";
  return "deep";
}

export function clampBlocks(blocks: number): number {
  return Math.min(BLOCK_BOUNDS.max, Math.max(BLOCK_BOUNDS.min, Math.round(blocks)));
}

/** La durée de lecture annoncée, tirée du volume demandé et non d'une estimation d'ambiance. */
export function readingHint(blocks: number): string {
  return `≈ ${Math.max(1, Math.round(blocks / 4.5))} min`;
}

export function isSheetLength(value: string | null | undefined): value is SheetLength {
  return value === "brief" || value === "standard" || value === "deep";
}
