/**
 * Le chemin d'une leçon, toujours construit de la même façon (`docs/refonte-parcours.md` § 5.1).
 * Les valeurs attendues sont celles de `MicaboTests/LessonModelTests.swift`.
 */

import { describe, expect, it } from "vitest";

import { uniqueSymbols } from "../src/lesson/symbols";
import {
  circleState,
  currentCircle,
  lessonCircles,
  migratedDone,
  pathCircles,
  pathProgress,
  pathThemes,
  symbolForIcon,
  themeGroups,
  type PathTheme,
} from "../src/lesson/path-layout";
import { readLessonPath } from "../src/lesson/types";

const labels = { intro: "Intro", checkpoint: "Checkpoint", final: "Quiz final" };

function themes(count: number): PathTheme[] {
  return Array.from({ length: count }, (_, index) => ({ title: `Thème ${index + 1}`, icon: "livre-ouvert", symbol: "book" }));
}

describe("le chemin", () => {
  it("compte 7 étapes pour 4 thèmes, 10 pour 6, 17 pour 12", () => {
    expect(pathCircles(themes(4), labels)).toHaveLength(7);
    expect(pathCircles(themes(6), labels)).toHaveLength(10);
    expect(pathCircles(themes(12), labels)).toHaveLength(17);
    expect(pathCircles([], labels)).toEqual([]);
  });

  it("fait des groupes de deux, puis de trois au-delà de huit", () => {
    const sizes = (count: number) => themeGroups(count).map((group) => group.length);
    expect(sizes(4)).toEqual([2, 2]);
    expect(sizes(5)).toEqual([2, 3]);
    expect(sizes(7)).toEqual([2, 2, 3]);
    expect(sizes(8)).toEqual([2, 2, 2, 2]);
    expect(sizes(9)).toEqual([3, 3, 3]);
    expect(sizes(10)).toEqual([3, 3, 2, 2]);
    expect(sizes(11)).toEqual([3, 3, 3, 2]);
    expect(sizes(12)).toEqual([3, 3, 3, 3]);
  });

  it("couvre chaque thème une fois, dans l'ordre, de 1 à 30, sans quiz de plus de 3 thèmes", () => {
    for (let count = 1; count <= 30; count += 1) {
      const groups = themeGroups(count);
      expect(groups.flat(), `${count} thèmes`).toEqual(Array.from({ length: count }, (_, index) => index));
      for (const group of groups) expect(group.length, `${count} thèmes`).toBeLessThanOrEqual(3);
    }
  });

  it("va droit au Quiz final pour une leçon très courte", () => {
    expect(pathCircles(themes(4), labels, { singleQuiz: true }).map((circle) => circle.id)).toEqual([
      "intro", "notes:0", "notes:1", "notes:2", "notes:3", "final",
    ]);
  });

  it("se lit comme la référence", () => {
    const circles = pathCircles(themes(4), labels, { groupNames: ["Les causes", "Les suites"] });
    expect(circles.map((circle) => circle.id)).toEqual(["intro", "notes:0", "notes:1", "quiz:0", "notes:2", "notes:3", "final"]);
    expect(circles.map((circle) => circle.number)).toEqual([1, 2, 3, 4, 5, 6, 7]);
    expect(circles[1]!.title).toBe("Thème 1");
    expect(circles[3]!.subtitle).toBe("Les causes");
    expect(circles[3]!.isMilestone).toBe(true);
    expect(circles[1]!.isMilestone).toBe(false);
    expect(circles[3]!.kind).toEqual({ type: "quiz", group: 0, themes: [0, 1] });
    expect(circles[6]!.kind).toEqual({ type: "final", themes: [0, 1, 2, 3] });
    expect(circles[0]!.activity).toBeNull();
    expect(circles[1]!.activity).toBe("notes");
    expect(circles[6]!.activity).toBe("quiz");
  });

  it("garde la fin d'une progression d'avant le Quiz final", () => {
    const circles = pathCircles(themes(4), labels);
    expect(migratedDone(["conclusion"], circles, false)).toContain("final");
    expect(migratedDone(["quiz:1"], circles, false)).toContain("final");
    expect(migratedDone([], circles, true)).toContain("final");
    expect(migratedDone(["quiz:0"], circles, false)).not.toContain("final");
  });

  it("ne donne jamais deux ronds pareils", () => {
    const symbols = uniqueSymbols(Array(12).fill("flag"));
    const circles = pathCircles(
      themes(12).map((theme, index) => ({ ...theme, symbol: symbols[index]! })),
      labels,
    );
    const all = circles.map((circle) => circle.symbol);
    expect(new Set(all).size).toBe(all.length);
  });

  it("tient la première étape non cochée pour l'étape en cours, et rien d'autre", () => {
    const circles = pathCircles(themes(4), labels);
    const done = ["intro", "notes:0"];
    expect(currentCircle(circles, done)?.id).toBe("notes:1");
    expect(circleState(circles[0]!, circles, done)).toBe("done");
    expect(circleState(circles[2]!, circles, done)).toBe("current");
    expect(circleState(circles[3]!, circles, done)).toBe("upcoming");
    expect(currentCircle(circles, circles.map((circle) => circle.id))).toBeNull();
    expect(pathProgress(circles, done)).toEqual({ done: 2, total: 7, percent: 29 });
  });

  it("construit le chemin d'une leçon depuis son plan, avec les pictogrammes du plan ou de l'icône", () => {
    const path = readLessonPath({
      icon: "globe",
      intro: { lines: ["a", "b", "c"], minutes: 25 },
      takeaways: [],
      groups: [{ name: "Les causes", themes: [0, 1] }, { name: "Les suites", themes: [2, 3] }],
      status: "ready",
      symbols: ["flag", "flag", "", "atom"],
    })!;
    const circles = lessonCircles(path, [
      { title: "A", icon: "globe" },
      { title: "B", icon: "fiole" },
      { title: "C", icon: null },
      { title: "D", icon: "atome" },
    ], labels);
    expect(circles.map((circle) => circle.id)).toEqual(["intro", "notes:0", "notes:1", "quiz:0", "notes:2", "notes:3", "final"]);
    const symbols = circles.filter((circle) => circle.kind.type === "notes").map((circle) => circle.symbol);
    expect(symbols[0]).toBe("flag");
    expect(new Set(symbols).size).toBe(4);
    expect(symbols[3]).toBe("atom");
    expect(circles[3]!.subtitle).toBe("Les causes");
    expect(pathThemes(null, [{ title: "X", icon: "fiole" }])[0]!.symbol).toBe(symbolForIcon("fiole"));
    expect(symbolForIcon("licorne")).toBe("book");
  });
});
