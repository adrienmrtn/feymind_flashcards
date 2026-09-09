import { describe, expect, it } from "vitest";

import { nextPath, previousPath, STEPS } from "./steps";

describe("le parcours", () => {
  it("ouvre sur l'accueil, puis montre le produit avant le pays", () => {
    expect(STEPS.map((step) => step.path)).toEqual([
      "/commencer/bienvenue",
      "/commencer/examen",
      "/commencer/importer",
      "/commencer/plan",
      "/commencer/ia",
      "/commencer/feynman",
      "/commencer/resultats",
      "/commencer/personnaliser",
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

  it("ne met de jauge ni sur l'accueil ni sur le compte", () => {
    const withoutChrome = STEPS.filter((step) => !step.chrome).map((step) => step.path);
    expect(withoutChrome).toEqual(["/commencer/bienvenue", "/commencer/compte"]);
  });
});
