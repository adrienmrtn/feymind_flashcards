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
      "/commencer/repos",
      "/commencer/moyenne",
      "/commencer/objectif",
      "/commencer/ensemble",
      "/commencer/parcours",
      "/commencer/compte",
    ]);
  });

  it("pose le rythme et les moyennes entre les matières et le chargement", () => {
    expect(nextPath("/commencer/matieres")).toBe("/commencer/repos");
    expect(nextPath("/commencer/repos")).toBe("/commencer/moyenne");
    expect(nextPath("/commencer/moyenne")).toBe("/commencer/objectif");
    expect(nextPath("/commencer/objectif")).toBe("/commencer/ensemble");
    expect(nextPath("/commencer/ensemble")).toBe("/commencer/parcours");
    expect(previousPath("/commencer/moyenne")).toBe("/commencer/repos");
  });

  it("donne à chaque étape le nom qu'elle affiche", () => {
    // La jauge lisait une liste tenue à part, qui avait fini par décaler d'un écran.
    expect(STEPS.every((step) => step.labelKey.startsWith("onboarding.step"))).toBe(true);
    expect(new Set(STEPS.map((step) => step.labelKey)).size).toBe(STEPS.length);
  });

  it("ramène le premier écran à la vitrine", () => {
    expect(previousPath("/commencer/bienvenue")).toBe("/");
  });

  it("ne met de jauge ni sur l'accueil ni sur le compte", () => {
    const withoutChrome = STEPS.filter((step) => !step.chrome).map((step) => step.path);
    expect(withoutChrome).toEqual(["/commencer/bienvenue", "/commencer/compte"]);
  });
});
