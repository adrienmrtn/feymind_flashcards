/**
 * Où poser le trou et la bulle.
 *
 * Du calcul sur des rectangles, sans DOM : c'est la partie qui se casse
 * silencieusement (une bulle à moitié hors de l'écran reste cliquable, donc
 * personne ne remonte le bug), et c'est donc celle qui doit se tester.
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
  const centered = anchor.left + anchor.width / 2 - bubble.width / 2;

  return {
    top: clamp(top, EDGE_MARGIN, Math.max(EDGE_MARGIN, viewport.height - bubble.height - EDGE_MARGIN)),
    left: clamp(centered, EDGE_MARGIN, Math.max(EDGE_MARGIN, viewport.width - bubble.width - EDGE_MARGIN)),
    side,
  };
}

function clamp(value: number, low: number, high: number): number {
  return Math.min(Math.max(value, low), high);
}
