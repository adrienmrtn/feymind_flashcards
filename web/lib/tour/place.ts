/**
 * Où poser le trou et la bulle.
 *
 * Du calcul sur des rectangles, sans DOM : une bulle trop basse coupe son
 * bouton, et un clic qui n'atteint rien ne remonte pas le placement. C'est
 * donc celle qui doit se tester.
 *
 * Les coordonnées sont celles de la fenêtre, comme `getBoundingClientRect`.
 */

export interface Rect {
  top: number;
  left: number;
  width: number;
  height: number;
}

export interface Size {
  width: number;
  height: number;
}

/** L'air laissé autour de la zone montrée. */
export const HOLE_PADDING = 8;
/** Entre le trou et la bulle. */
export const BUBBLE_GAP = 14;
/** Ce qu'on ne mord jamais sur les bords de la fenêtre. */
export const EDGE_MARGIN = 12;

export function holeAround(anchor: Rect, padding = HOLE_PADDING): Rect {
  return {
    top: anchor.top - padding,
    left: anchor.left - padding,
    width: anchor.width + padding * 2,
    height: anchor.height + padding * 2,
  };
}

export type BubbleSide = "above" | "below";

export interface Placement {
  top: number;
  left: number;
  side: BubbleSide;
}

/**
 * La bulle se pose **sous** la zone, et au-dessus seulement s'il n'y a pas la
 * place dessous.
 *
 * Dessous par défaut parce qu'on lit de haut en bas : la zone montrée est vue
 * avant son explication. Le repli n'est pas « au-dessus dès que ça dépasse »
 * mais « au-dessus si on y est moins à l'étroit » : sur un petit écran les
 * deux côtés peuvent déborder, et il faut alors choisir le moins mauvais.
 */
export function bubblePlacement(anchor: Rect, bubble: Size, viewport: Size): Placement {
  const hole = holeAround(anchor);
  const below = hole.top + hole.height + BUBBLE_GAP;
  const above = hole.top - BUBBLE_GAP - bubble.height;

  const roomBelow = viewport.height - EDGE_MARGIN - (below + bubble.height);
  const roomAbove = above - EDGE_MARGIN;

  const side: BubbleSide = roomBelow >= 0 || roomBelow >= roomAbove ? "below" : "above";
  const top = side === "below" ? below : above;

  // Centrée sur la zone, puis ramenée dans la fenêtre. Une bulle centrée sur
  // un élément collé au bord sortirait de l'écran de la moitié de sa largeur.
  // Le bas compte autant que les côtés : une carte trop basse rend « Suivant »
  // invisible, donc incliquable.
  const centered = anchor.left + anchor.width / 2 - bubble.width / 2;

  return {
    top: clamp(top, EDGE_MARGIN, maxStart(viewport.height, bubble.height)),
    left: clamp(centered, EDGE_MARGIN, maxStart(viewport.width, bubble.width)),
    side,
  };
}

/** Premier pixel où un bloc de `size` tient encore, marge comprise. */
function maxStart(span: number, size: number): number {
  return Math.max(EDGE_MARGIN, span - size - EDGE_MARGIN);
}

function clamp(value: number, low: number, high: number): number {
  return Math.min(Math.max(value, low), high);
}
