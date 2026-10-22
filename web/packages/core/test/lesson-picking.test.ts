/**
 * Le tirage des quiz et des cartes d'une leçon. Les cas sont ceux de
 * `MicaboTests/LessonPickingTests.swift` ; le générateur est celui de l'app.
 */

import { describe, expect, it } from "vitest";

import { SeededGenerator, pickCards, pickQuiz, pickingSeed, progressive, shuffled, stableHash } from "../src/lesson/picking";
import { circleQuiz, circleReadiness, fullQuiz, themeOfQuestion } from "../src/lesson/session";
import { pathCircles } from "../src/lesson/path-layout";
import { emptyProgress, type QuizQuestion } from "../src/lesson/types";

/** Un thème : sa question de fin, puis trois de réserve. */
function theme(name: string, difficulty = 2): QuizQuestion[] {
  return Array.from({ length: 4 }, (_, index) => ({
    id: `${name}:${index}`, kind: "choice", prompt: `${name} ${index} ?`, choices: ["a", "b", "c", "d"], answer: 0, why: ".", matches: [], difficulty,
  }));
}

describe("le générateur", () => {
  it("hache comme FNV-1a et reste stable", () => {
    // Les valeurs de référence de FNV-1a 64 bits.
    expect(stableHash("")).toBe(0xcbf29ce484222325n);
    expect(stableHash("a")).toBe(0xaf63dc4c8601ec8cn);
    expect(pickingSeed("x", "y")).toBe(stableHash("x|y"));
  });

  it("rejoue la même suite pour la même graine", () => {
    const first = new SeededGenerator(42n);
    const second = new SeededGenerator(42n);
    const draws = Array.from({ length: 5 }, () => first.below(100));
    expect(Array.from({ length: 5 }, () => second.below(100))).toEqual(draws);
    expect(draws.every((value) => value >= 0 && value < 100)).toBe(true);
    // SplitMix64 : la première sortie pour la graine 0 est connue.
    expect(new SeededGenerator(0n).next()).toBe(0xe220a8397b1dcdafn);
  });

  it("mélange sans perdre ni doubler", () => {
    const items = Array.from({ length: 20 }, (_, index) => index);
    const mixed = shuffled(items, new SeededGenerator(7n));
    expect([...mixed].sort((a, b) => a - b)).toEqual(items);
    expect(mixed).not.toEqual(items);
  });
});

describe("le tirage des questions", () => {
  it("prend cinq questions de réserve, sur les deux thèmes", () => {
    const picked = pickQuiz([theme("A"), theme("B")], [], 5, 1n);
    expect(picked).toHaveLength(5);
    expect(new Set(picked.map((question) => question.id)).size).toBe(5);
    expect(picked.some((question) => question.id.endsWith(":0"))).toBe(false);
    expect(picked.filter((question) => question.id.startsWith("A")).length).toBeGreaterThanOrEqual(2);
    expect(picked.filter((question) => question.id.startsWith("B")).length).toBeGreaterThanOrEqual(2);
  });

  it("pose les ratées d'abord, les plus récentes en tête", () => {
    const picked = pickQuiz([theme("A"), theme("B")], ["A:2", "B:3", "Z:1"], 5, 7n);
    expect(picked.slice(0, 2).map((question) => question.id)).toEqual(["B:3", "A:2"]);
  });

  it("retombe sur les questions de fin quand la réserve est courte", () => {
    const short = [theme("A").slice(0, 2), theme("B").slice(0, 2)];
    expect(pickQuiz(short, [], 10, 3n)).toHaveLength(4);
  });

  it("donne le même quiz pour la même graine, et un autre la plupart du temps", () => {
    const themes = [theme("A"), theme("B"), theme("C")];
    const first = pickQuiz(themes, [], 5, 42n).map((question) => question.id);
    expect(pickQuiz(themes, [], 5, 42n).map((question) => question.id)).toEqual(first);
    const others = Array.from({ length: 10 }, (_, seed) => pickQuiz(themes, [], 5, BigInt(seed)).map((question) => question.id));
    expect(others.some((ids) => ids.join() !== first.join())).toBe(true);
  });

  it("range du plus simple au plus exigeant sans changer l'ordre à difficulté égale", () => {
    const ordered = progressive([...theme("A", 3), ...theme("B", 1)]);
    expect(ordered.slice(0, 4).every((question) => question.id.startsWith("B"))).toBe(true);
    expect(ordered.slice(0, 4).map((question) => question.id)).toEqual(["B:0", "B:1", "B:2", "B:3"]);
  });
});

describe("le tirage des cartes", () => {
  it("préfère les ratées, puis les dues, puis les neuves", () => {
    const candidates = Array.from({ length: 14 }, (_, index) => ({
      id: `c${index}`, isMissedQuestion: false, isDue: false, isNew: false, position: index,
    }));
    candidates[13]!.isMissedQuestion = true;
    candidates[5]!.isDue = true;
    candidates[0]!.isNew = true;
    candidates[1]!.isNew = true;

    const picked = pickCards(candidates, 10, 1n);
    expect(picked).toHaveLength(10);
    expect(picked[0]).toBe("c13");
    expect(picked[1]).toBe("c5");
    expect(picked.slice(2, 4)).toEqual(["c0", "c1"]);
    expect(new Set(picked).size).toBe(10);
  });
});

describe("les questions d'une étape", () => {
  const labels = { intro: "Intro", checkpoint: "Checkpoint", final: "Quiz final" };
  const themes = Array.from({ length: 4 }, (_, index) => ({ title: `T${index}`, icon: "livre-ouvert", symbol: "book" }));
  const circles = pathCircles(themes, labels);
  const quizzes = ["A", "B", "C", "D"].map((name) => ({ questions: theme(name) }));

  it("posent cinq questions du palier et deux des paliers d'avant", () => {
    const lessonId = "0b4f3b9c-1c5b-4e2e-9c7f-0a1b2c3d4e5f";
    const checkpoint = circles.find((circle) => circle.id === "quiz:0")!;
    const first = circleQuiz(lessonId, checkpoint, quizzes, emptyProgress());
    expect(first).toHaveLength(5);
    expect(first.every((question) => /^[AB]:/.test(question.id))).toBe(true);
    // Même tentative, même tirage ; une tentative de plus, et l'app comme le site changent.
    expect(circleQuiz(lessonId, checkpoint, quizzes, emptyProgress()).map((q) => q.id)).toEqual(first.map((q) => q.id));
    const final = circles[circles.length - 1]!;
    const all = circleQuiz(lessonId, final, quizzes, emptyProgress());
    expect(all).toHaveLength(8);
    expect(new Set(all.map((question) => question.id)).size).toBe(8);
    expect(fullQuiz(lessonId, quizzes, emptyProgress(), 1)).toHaveLength(10);
    expect(circleQuiz(lessonId, circles[0]!, quizzes, emptyProgress())).toEqual([]);
  });

  it("retrouvent le thème d'une question par son identifiant", () => {
    expect(themeOfQuestion("ABCD:3", ["x", "abcd"])).toBe(1);
    expect(themeOfQuestion("zzz:3", ["x", "abcd"])).toBe(-1);
  });

  it("disent ce qu'une étape attend", () => {
    expect(circleReadiness(circles[1]!, ["pending", "ready", "ready", "ready"], quizzes)).toBe("writing");
    expect(circleReadiness(circles[2]!, ["pending", "failed", "ready", "ready"], quizzes)).toBe("failed");
    expect(circleReadiness(circles[3]!, ["pending", "ready", "ready", "ready"], quizzes)).toBe("writing");
    expect(circleReadiness(circles[3]!, ["failed", "ready", "ready", "ready"], quizzes)).toBe("ready");
    expect(circleReadiness(circles[3]!, ["failed", "failed", "ready", "ready"], [null, null, null, null])).toBe("failed");
    expect(circleReadiness(circles[0]!, [], [])).toBe("ready");
  });
});
