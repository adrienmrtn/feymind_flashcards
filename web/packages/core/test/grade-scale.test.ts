import { describe, expect, it } from "vitest";

import {
  desiredGradeLabel,
  desiredGradeScale,
  gradeTicks,
  intensityFromTargetScore,
  targetPercent,
  targetScoreFromIntensity,
} from "../src/index";

describe("la note souhaitée", () => {
  it("parle /20 à un Français, des lettres à un Américain", () => {
    expect(desiredGradeScale("fr")).toEqual({ min: "10/20", mid: "15/20", max: "20/20" });
    expect(desiredGradeLabel(10, "fr")).toBe("10/20");
    expect(desiredGradeLabel(16, "fr")).toBe("16/20");
    expect(desiredGradeLabel(20, "us")).toBe("A+");
    expect(gradeTicks("fr")).toHaveLength(11);
  });

  it("découpe l'intensité sur 10–13, 14–17, puis le reste", () => {
    expect(intensityFromTargetScore(10)).toBe("light");
    expect(intensityFromTargetScore(13)).toBe("light");
    expect(intensityFromTargetScore(14)).toBe("standard");
    expect(intensityFromTargetScore(17)).toBe("standard");
    expect(intensityFromTargetScore(18)).toBe("intense");
    expect(intensityFromTargetScore(20)).toBe("intense");
  });

  it("retombe sur le milieu de bande quand on n'a que l'ancien palier", () => {
    expect(targetScoreFromIntensity("light")).toBe(12);
    expect(desiredGradeLabel("standard", "fr")).toBe("15/20");
    expect(desiredGradeLabel("intense", "us")).toBe("A");
  });
});

describe("la note visée en pourcentage de copie", () => {
  it("lit l'échelle sur vingt", () => {
    // 20/20 est la copie parfaite ; c'est ce que « objectif : 20 % » disait de travers.
    expect(targetPercent(20)).toBe(100);
    expect(targetPercent(15)).toBe(75);
    expect(targetPercent(10)).toBe(50);
  });

  it("ne dessine pas d'objectif quand il n'y en a pas", () => {
    expect(targetPercent(null)).toBeNull();
    expect(targetPercent(undefined)).toBeNull();
  });

  it("ramène une valeur hors échelle dans l'échelle", () => {
    expect(targetPercent(35)).toBe(100);
    expect(targetPercent(2)).toBe(50);
  });
});
