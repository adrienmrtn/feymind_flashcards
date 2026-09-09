import { describe, expect, it } from "vitest";

import { LANDING_NAV, LANDING_SECTIONS } from "./landing-sections";

describe("la vitrine", () => {
  it("navigue dans l'ordre du produit, sans annoncer l'iPhone ni le prix", () => {
    expect(LANDING_NAV.map((item) => item.label)).toEqual([
      "Comment ça marche",
      "La méthode",
      "Mode examen",
      "Questions",
    ]);
    expect(LANDING_SECTIONS).not.toHaveProperty("iphone");
    expect(LANDING_SECTIONS).not.toHaveProperty("pricing");
    expect(LANDING_NAV.some((item) => /iphone|prix/i.test(item.href + item.label))).toBe(false);
  });

  it("pointe chaque lien de la barre vers une section qui existe", () => {
    const ids = new Set<string>(Object.values(LANDING_SECTIONS));
    for (const item of LANDING_NAV) {
      expect(ids.has(item.href.slice(1))).toBe(true);
    }
  });
});
