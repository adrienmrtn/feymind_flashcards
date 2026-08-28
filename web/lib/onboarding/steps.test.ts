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
      "/commencer/examen",
      "/commencer/comment",
      "/commencer/ecole",
      "/commencer/parcours",
      "/commencer/compte",
    ]);
  });

  it("saute la démo en trois temps : après le mode d'emploi, l'école", () => {
    expect(nextPath("/commencer/comment")).toBe("/commencer/ecole");
    expect(previousPath("/commencer/ecole")).toBe("/commencer/comment");
  });

  it("ramène le premier écran à la vitrine", () => {
    expect(previousPath("/commencer/bienvenue")).toBe("/");
  });
});
