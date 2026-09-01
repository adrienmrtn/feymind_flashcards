import { describe, expect, it } from "vitest";

import { LANDING_NAV, LANDING_SECTIONS } from "./landing-sections";

describe("la vitrine", () => {
  it("n'annonce plus l'iPhone dans la navigation", () => {
    expect(LANDING_NAV.map((item) => item.label)).toEqual([
      "La méthode",
      "Mode examen",
      "Questions",
    ]);
    expect(LANDING_SECTIONS).not.toHaveProperty("iphone");
    expect(LANDING_NAV.some((item) => /iphone/i.test(item.href + item.label))).toBe(false);
  });
});
