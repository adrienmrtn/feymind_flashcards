import { describe, expect, it } from "vitest";

import { latexCommandsToUnicode, latexToUnicode } from "../src/formula";

describe("les commandes LaTeX nues", () => {
  it("transposent une flèche hors formule, le cas des cartes générées", () => {
    expect(latexCommandsToUnicode("1914 \\rightarrow 1918")).toBe("1914 → 1918");
    expect(latexCommandsToUnicode("de A \\to B")).toBe("de A → B");
    expect(latexCommandsToUnicode("A \\Rightarrow B")).toBe("A ⇒ B");
  });

  it("laisse un texte sans antislash intact", () => {
    expect(latexCommandsToUnicode("Bornes chronologiques de la Première Guerre Mondiale.")).toBe(
      "Bornes chronologiques de la Première Guerre Mondiale.",
    );
  });

  it("ne laisse pas \\int se faire manger par \\in", () => {
    expect(latexCommandsToUnicode("\\int")).toBe("∫");
    expect(latexCommandsToUnicode("x \\in \\mathbb{R}")).toBe("x ∈ ℝ");
  });
});

describe("une formule complète", () => {
  it("transpose indices, exposants et symboles", () => {
    expect(latexToUnicode("H_2O")).toBe("H₂O");
    expect(latexToUnicode("x^{10}")).toBe("x¹⁰");
    expect(latexToUnicode("\\Delta v = a \\times t")).toBe("Δv = a × t");
    expect(latexToUnicode("\\alpha + \\beta \\leq \\pi")).toBe("α + β ≤ π");
  });

  it("écrit les fractions et les racines", () => {
    expect(latexToUnicode("\\frac{1}{2}")).toBe("1/2");
    expect(latexToUnicode("\\frac{a + b}{c}")).toBe("(a + b)/c");
    expect(latexToUnicode("\\sqrt{2}")).toBe("√2");
  });
});
