import { describe, expect, it } from "vitest";

import { BELOW_SCORE, gradeChoices, gradeLabel, targetChoices } from "./grades";

describe("les moyennes proposées", () => {
  it("parle le barème du pays", () => {
    expect(gradeChoices("fr").map((choice) => choice.label)).toContain("15/20");
    expect(gradeChoices("de").map((choice) => choice.label)).toContain("1,3");
    expect(gradeChoices("us").map((choice) => choice.label)).toContain("B+");
  });

  it("ne propose jamais deux fois le même libellé", () => {
    for (const country of ["fr", "us", "uk", "de", "se", "nl", "ro", "ch"]) {
      const labels = gradeChoices(country).map((choice) => choice.label);
      expect(new Set(labels).size, country).toBe(labels.length);
    }
  });

  it("garde la plus basse valeur d'un libellé répété", () => {
    // « C- » couvre 10 et 11 aux États-Unis : répondre « C- » ne doit pas créditer 11.
    expect(gradeChoices("us")[0]).toEqual({ score: 10, label: "C-" });
  });

  it("monte toujours", () => {
    const scores = gradeChoices("fr").map((choice) => choice.score);
    expect([...scores].sort((a, b) => a - b)).toEqual(scores);
  });
});

describe("la moyenne visée", () => {
  it("ne peut être que plus haute que l'actuelle", () => {
    const choices = targetChoices(15, "fr");
    expect(choices.every((choice) => choice.score > 15)).toBe(true);
    expect(choices.map((choice) => choice.label)).toContain("16/20");
    expect(choices.map((choice) => choice.label)).not.toContain("15/20");
  });

  it("ouvre tout le barème à celui qui part en dessous", () => {
    expect(targetChoices(BELOW_SCORE, "fr")).toEqual(gradeChoices("fr"));
    expect(targetChoices(undefined, "fr")).toEqual(gradeChoices("fr"));
  });

  it("ne propose rien à celui qui est déjà au sommet", () => {
    expect(targetChoices(20, "fr")).toEqual([]);
  });
});

describe("le libellé d'une valeur enregistrée", () => {
  it("se relit dans le barème", () => {
    expect(gradeLabel(17, "fr")).toBe("17/20");
  });

  it("n'existe pas pour « en dessous »", () => {
    expect(gradeLabel(BELOW_SCORE, "fr")).toBeNull();
  });
});
