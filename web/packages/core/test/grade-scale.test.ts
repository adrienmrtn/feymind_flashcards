import { describe, expect, it } from "vitest";

import {
  desiredGradeLabel,
  desiredGradeScale,
  gradeIndexFor,
  intensityFromGradeIndex,
} from "../src/index";

describe("la note souhaitée", () => {
  it("parle /20 à un Français, des lettres à un Américain", () => {
    expect(desiredGradeScale("fr")).toEqual({ min: "10/20", mid: "15/20", max: "20/20" });
    expect(desiredGradeScale("us")).toEqual({ min: "C-", mid: "B", max: "A+" });
    expect(desiredGradeScale("uk")).toEqual({ min: "C", mid: "B", max: "A*" });
    expect(desiredGradeScale("de")).toEqual({ min: "4,0", mid: "2,3", max: "1,0" });
  });

  it("retombe sur le /20 quand le pays n'est pas encore choisi", () => {
    expect(desiredGradeScale(null)).toEqual(desiredGradeScale("fr"));
  });

  it("aligne les trois crans sur l'intensité", () => {
    expect(desiredGradeLabel("light", "fr")).toBe("10/20");
    expect(desiredGradeLabel("standard", "fr")).toBe("15/20");
    expect(desiredGradeLabel("intense", "us")).toBe("A+");
    expect(gradeIndexFor("standard")).toBe(1);
    expect(intensityFromGradeIndex(2)).toBe("intense");
  });
});
