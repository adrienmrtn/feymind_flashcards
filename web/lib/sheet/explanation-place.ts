/**
 * La carte d'explication, **dans** la fenêtre.
 *
 * Elle s'ancre au passage sélectionné, au-dessus s'il n'y a pas la place
 * dessous. Un `translateY(-100 %)` plus un plafond à 70 vh la faisait
 * sortir par le haut : le titre et la croix disparaissaient. On pince
 * maintenant le bord libre (top ou bottom) et on borne la hauteur à l'espace
 * vraiment disponible, en-tête comprise.
 */

export const EXPLANATION_WIDTH = 420;
export const EXPLANATION_MAX_HEIGHT = 560;
export const EXPLANATION_GAP = 10;
export const EXPLANATION_MARGIN = 12;
/** `h-14` du chrome collant, plus sa bordure. */
export const APP_HEADER = 56;
/** En dessous de ça, on préfère basculer au-dessus du passage. */
export const PREFER_BELOW_MIN = 220;
const MIN_USABLE = 120;

export interface PassageRect {
  top: number;
  bottom: number;
  left: number;
}

export interface Viewport {
  width: number;
  height: number;
  topInset: number;
}

export interface ExplanationAnchor {
  left: number;
  maxHeight: number;
  /** Distance au haut de la fenêtre : la carte pend sous le passage. */
  top?: number;
  /** Distance au bas de la fenêtre : la carte pend au-dessus du passage. */
  bottom?: number;
}

export function windowViewport(): Viewport {
  return {
    width: window.innerWidth,
    height: window.innerHeight,
    topInset: APP_HEADER,
  };
}

export function placeExplanation(rect: PassageRect, viewport: Viewport): ExplanationAnchor {
  const width = Math.min(EXPLANATION_WIDTH, Math.max(0, viewport.width - EXPLANATION_MARGIN * 2));
  const left = Math.min(
    Math.max(EXPLANATION_MARGIN, rect.left),
    Math.max(EXPLANATION_MARGIN, viewport.width - width - EXPLANATION_MARGIN),
  );

  const topBound = viewport.topInset + EXPLANATION_MARGIN;
  const bottomBound = viewport.height - EXPLANATION_MARGIN;
  const belowTop = rect.bottom + EXPLANATION_GAP;
  const aboveBottom = rect.top - EXPLANATION_GAP;

  const spaceBelow = bottomBound - belowTop;
  const spaceAbove = aboveBottom - topBound;
  const preferAbove = spaceBelow < PREFER_BELOW_MIN && spaceAbove > spaceBelow;

  if (preferAbove && spaceAbove >= MIN_USABLE) {
    return {
      left,
      bottom: viewport.height - aboveBottom,
      maxHeight: Math.min(EXPLANATION_MAX_HEIGHT, spaceAbove),
    };
  }

  if (spaceBelow >= MIN_USABLE) {
    return {
      left,
      top: belowTop,
      maxHeight: Math.min(EXPLANATION_MAX_HEIGHT, spaceBelow),
    };
  }

  // Les deux côtés sont trop justes : on remplit la fenêtre, quitte à
  // recouvrir le passage. Mieux qu'une carte coupée.
  return {
    left,
    top: topBound,
    maxHeight: Math.min(EXPLANATION_MAX_HEIGHT, Math.max(MIN_USABLE, bottomBound - topBound)),
  };
}

/** Boîte que la carte occuperait si elle prenait toute sa hauteur max. */
export function explanationBox(
  anchor: ExplanationAnchor,
  viewport: Viewport,
): { top: number; bottom: number } {
  const height = anchor.maxHeight;
  if (anchor.bottom != null) {
    const bottom = viewport.height - anchor.bottom;
    return { top: bottom - height, bottom };
  }
  const top = anchor.top ?? 0;
  return { top, bottom: top + height };
}
