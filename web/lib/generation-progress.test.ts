import { describe, expect, it } from "vitest";

import {
  displayGenerationPercent,
  elapsedGenerationProgress,
  knownGenerationProgress,
} from "./generation-progress";

describe("la jauge d'écriture", () => {
  it("part de zéro et ne touche pas 100 % en attendant", () => {
    expect(elapsedGenerationProgress(0)).toBe(0);
    expect(elapsedGenerationProgress(8_000)).toBeGreaterThan(0.3);
    expect(elapsedGenerationProgress(8_000)).toBeLessThan(0.7);
    expect(elapsedGenerationProgress(120_000)).toBeLessThan(0.95);
    expect(elapsedGenerationProgress(120_000)).toBe(0.94);
  });

  it("prend le ratio réel d'un versement Anki", () => {
    expect(knownGenerationProgress(0, 200)).toBe(0);
    expect(knownGenerationProgress(50, 200)).toBe(0.25);
    expect(knownGenerationProgress(200, 200)).toBe(1);
    expect(knownGenerationProgress(12, 0)).toBe(0);
  });

  it("affiche 1 % tout de suite, et 100 % seulement quand on le sait", () => {
    expect(displayGenerationPercent(0, { known: false })).toBe(1);
    expect(displayGenerationPercent(0.94, { known: false })).toBe(94);
    expect(displayGenerationPercent(1, { known: false })).toBe(99);
    expect(displayGenerationPercent(1, { known: true })).toBe(100);
    expect(displayGenerationPercent(0, { known: true })).toBe(0);
  });
});
