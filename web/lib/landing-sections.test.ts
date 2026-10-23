import { describe, expect, it } from "vitest";

import { fr } from "./i18n/catalogs";
import { lookup, type MessageTree } from "./i18n/format";
import { LANDING_NAV, LANDING_SECTIONS } from "./landing-sections";

describe("la vitrine", () => {
  it("navigue dans l'ordre du produit : les étapes, la leçon, le prix, les questions", () => {
    expect(LANDING_NAV.map((item) => item.label)).toEqual([
      "Comment ça marche",
      "La leçon",
      "Prix",
      "Questions",
    ]);
  });

  it("annonce les applis et le prix, maintenant qu'ils sont publics", () => {
    expect(LANDING_SECTIONS).toHaveProperty("apps");
    expect(LANDING_SECTIONS).toHaveProperty("pricing");
  });

  it("pointe chaque lien de la barre vers une section qui existe", () => {
    const ids = new Set<string>(Object.values(LANDING_SECTIONS));
    for (const item of LANDING_NAV) {
      expect(ids.has(item.href.slice(1))).toBe(true);
    }
  });

  it("donne à chaque lien une clé de catalogue dont le français est le libellé testé", () => {
    for (const item of LANDING_NAV) {
      expect(lookup(fr as unknown as MessageTree, item.key)).toBe(item.label);
    }
  });

  it("n'a pas deux sections sous la même ancre", () => {
    const ids = Object.values(LANDING_SECTIONS);
    expect(new Set(ids).size).toBe(ids.length);
  });
});
