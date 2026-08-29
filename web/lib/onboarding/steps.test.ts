import { describe, expect, it } from "vitest";

import { nextPath, previousPath, STEPS } from "./steps";

describe("le parcours", () => {
  it("ouvre sur l'accueil, puis montre le produit avant le pays", () => {
    expect(STEPS.map((step) => step.path)).toEqual([
      "/commencer/bienvenue",
      "/commencer/importer",
      "/commencer/cartes",
      "/commencer/reussir",
      "/commencer/pays",
      "/commencer/niveau",
      "/commencer/matieres",
      "/commencer/ecole",
      "/commencer/parcours",
      "/commencer/compte",
    ]);
  });

  it("enchaîne les matières sur l'école", () => {
    expect(nextPath("/commencer/matieres")).toBe("/commencer/ecole");
    expect(previousPath("/commencer/ecole")).toBe("/commencer/matieres");
  });

  it("ramène le premier écran à la vitrine", () => {
    expect(previousPath("/commencer/bienvenue")).toBe("/");
  });
});
