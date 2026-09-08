import { describe, expect, it } from "vitest";

import {
  APP_HEADER,
  EXPLANATION_MARGIN,
  explanationBox,
  placeExplanation,
  type Viewport,
} from "./explanation-place";

const desktop: Viewport = { width: 1280, height: 800, topInset: APP_HEADER };

function fits(rect: { top: number; bottom: number }, viewport: Viewport) {
  const floor = viewport.topInset + EXPLANATION_MARGIN;
  const ceil = viewport.height - EXPLANATION_MARGIN;
  expect(rect.top).toBeGreaterThanOrEqual(floor - 0.5);
  expect(rect.bottom).toBeLessThanOrEqual(ceil + 0.5);
}

describe("la carte d'explication", () => {
  it("reste dans la fenêtre quand elle pend au-dessus d'un passage bas", () => {
    // Le cas du screenshot : le passage est dans le bas de l'écran, la carte
    // est longue, et un plafond à 70 vh la faisait sortir par le haut.
    const anchor = placeExplanation({ top: 580, bottom: 608, left: 420 }, desktop);
    expect(anchor.bottom).toBeDefined();
    expect(anchor.top).toBeUndefined();
    const box = explanationBox(anchor, desktop);
    fits(box, desktop);
    expect(box.bottom - box.top).toBeLessThan(desktop.height * 0.7);
  });

  it("se place dessous quand il y a de la place, sans dépasser le bas", () => {
    const anchor = placeExplanation({ top: 120, bottom: 148, left: 80 }, desktop);
    expect(anchor.top).toBeDefined();
    expect(anchor.bottom).toBeUndefined();
    fits(explanationBox(anchor, desktop), desktop);
  });

  it("ne force pas une hauteur plus grande que l'espace restant", () => {
    const viewport: Viewport = { width: 390, height: 700, topInset: APP_HEADER };
    const anchor = placeExplanation({ top: 140, bottom: 170, left: 24 }, viewport);
    const box = explanationBox(anchor, viewport);
    expect(box.bottom - box.top).toBe(anchor.maxHeight);
    fits(box, viewport);
  });

  it("remplit la fenêtre plutôt que de sortir quand les deux côtés sont justes", () => {
    const viewport: Viewport = { width: 390, height: 640, topInset: APP_HEADER };
    const anchor = placeExplanation({ top: 300, bottom: 420, left: 16 }, viewport);
    fits(explanationBox(anchor, viewport), viewport);
  });

  it("garde la carte dans la largeur", () => {
    const anchor = placeExplanation({ top: 200, bottom: 220, left: 2000 }, desktop);
    expect(anchor.left + 420).toBeLessThanOrEqual(desktop.width - EXPLANATION_MARGIN + 0.5);
    expect(anchor.left).toBeGreaterThanOrEqual(EXPLANATION_MARGIN);
  });
});
