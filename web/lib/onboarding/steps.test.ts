import { describe, expect, it } from "vitest";

import { isSkipped, nextPath, previousPath, progressFor, STEPS, visibleSteps } from "./steps";

describe("le parcours", () => {
  it("pose les questions d'abord, puis le compte, puis l'offre", () => {
    expect(STEPS.map((step) => step.path)).toEqual([
      "/commencer/bienvenue",
      "/commencer/pays",
      "/commencer/niveau",
      "/commencer/classe",
      "/commencer/matieres",
      "/commencer/freins",
      "/commencer/moyenne",
      "/commencer/rythme",
      "/commencer/examen",
      "/commencer/parcours",
      "/commencer/compte",
      "/commencer/offre",
    ]);
  });

  it("tient en douze écrans au plus, dont neuf questions au plus", () => {
    // Il en comptait dix-sept, et l'offre ne venait qu'après, sur le tableau de bord.
    expect(STEPS.length).toBeLessThanOrEqual(12);
    expect(STEPS.filter((step) => step.chrome).length).toBeLessThanOrEqual(9);
  });

  it("met l'offre juste après le compte", () => {
    expect(nextPath("/commencer/compte")).toBe("/commencer/offre");
    expect(nextPath("/commencer/offre")).toBe("/app");
  });

  it("ne demande l'année qu'aux pays dont on connaît les filières", () => {
    expect(isSkipped("/commencer/classe", { country: "us" })).toBe(true);
    expect(isSkipped("/commencer/classe", {})).toBe(false);
    expect(isSkipped("/commencer/classe", { country: "fr", trackId: "fr.lyceeGeneral" })).toBe(false);
    expect(nextPath("/commencer/niveau", { country: "us" })).toBe("/commencer/matieres");
    expect(nextPath("/commencer/niveau", { country: "fr", trackId: "fr.prepa" })).toBe("/commencer/classe");
    expect(previousPath("/commencer/matieres", { country: "it" })).toBe("/commencer/niveau");
    expect(previousPath("/commencer/matieres", { country: "tr", trackId: "tr.fen" })).toBe("/commencer/classe");
  });

  it("compte la jauge sur les écrans que cet étudiant traverse", () => {
    const american = visibleSteps({ country: "us" }).filter((step) => step.chrome);
    const french = visibleSteps({ country: "fr", trackId: "fr.lyceeGeneral" }).filter((step) => step.chrome);
    expect(french.length).toBe(american.length + 1);
    expect(progressFor("/commencer/parcours", { country: "us" })).toBe(1);
    expect(progressFor("/commencer/pays", { country: "us" })).toBeCloseTo(1 / american.length);
    expect(progressFor("/commencer/compte")).toBe(0);
  });

  it("donne à chaque étape le nom qu'elle affiche", () => {
    // La jauge lisait une liste tenue à part, qui avait fini par décaler d'un écran.
    expect(STEPS.every((step) => step.labelKey.startsWith("onboarding.step"))).toBe(true);
    expect(new Set(STEPS.map((step) => step.labelKey)).size).toBe(STEPS.length);
  });

  it("ramène le premier écran à la vitrine", () => {
    expect(previousPath("/commencer/bienvenue")).toBe("/");
  });

  it("ne met de jauge ni sur l'accueil, ni sur le compte, ni sur l'offre", () => {
    const withoutChrome = STEPS.filter((step) => !step.chrome).map((step) => step.path);
    expect(withoutChrome).toEqual(["/commencer/bienvenue", "/commencer/compte", "/commencer/offre"]);
  });
});
