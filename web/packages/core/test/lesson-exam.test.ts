/**
 * L'examen blanc : la copie lue du serveur, son résultat, la note dans le barème du pays.
 */

import { describe, expect, it } from "vitest";

import { examFraction, examGradeLabel, examPasses, examQuestionCount, examResult, readExamPaper, readExamResponse, type ExamPaper } from "../src/lesson/exam";

const lessons = [
  { courseId: "a", title: "Leçon A", chapterIds: ["a1", "a2"] },
  { courseId: "b", title: "Leçon B", chapterIds: ["b1"] },
];

function question(number: number, extra: Record<string, unknown> = {}) {
  return { kind: "choice", prompt: `Q${number}`, choices: ["x", "y", "z"], answer: 0, why: "", ...extra };
}

describe("la copie", () => {
  it("lit les questions avec leur leçon et leur thème, et laisse le reste", () => {
    const paper = readExamResponse(
      { exam: { title: "Bac blanc", questions: [question(1, { lesson: 1, theme: 0 }), question(2, { lesson: 7, theme: 9 }), { kind: "choice", prompt: "" }, question(3, { kind: "order", choices: ["a"] })] } },
      { paperId: "p", examId: "e", title: "Examen", minutes: 30, lessons },
    );
    expect(paper).not.toBeNull();
    expect(paper!.title).toBe("Bac blanc");
    expect(paper!.items.map((item) => [item.question.id, item.lesson, item.theme])).toEqual([
      ["p:0", 1, 0],
      ["p:1", 0, 0],
    ]);
    expect(readExamResponse({ exam: { questions: [] } }, { paperId: "p", examId: null, title: "t", minutes: 15, lessons })).toBeNull();
  });

  it("se relit depuis ce qu'on en a gardé", () => {
    const paper = readExamResponse({ exam: { questions: [question(1, { lesson: 0, theme: 1 })] } }, { paperId: "p", examId: null, title: "t", minutes: 45, lessons })!;
    const again = readExamPaper(JSON.parse(JSON.stringify(paper)));
    expect(again).toEqual(paper);
    expect(readExamPaper({ id: "x" })).toBeNull();
  });

  it("compte une question sans réponse comme fausse, leçon par leçon", () => {
    const paper: ExamPaper = readExamResponse(
      { exam: { questions: [question(1, { lesson: 0 }), question(2, { lesson: 0 }), question(3, { lesson: 1 })] } },
      { paperId: "p", examId: "e", title: "t", minutes: 30, lessons },
    )!;
    const result = examResult(paper, { "p:0": { right: true }, "p:2": { right: false } }, 601.4, new Date("2026-10-22T10:00:00Z"));
    expect(result.correct).toBe(1);
    expect(result.total).toBe(3);
    expect(result.seconds).toBe(601);
    expect(result.lessons).toEqual([
      { title: "Leçon A", correct: 1, total: 2 },
      { title: "Leçon B", correct: 0, total: 1 },
    ]);
    expect(examFraction(result)).toBeCloseTo(1 / 3);
    expect(examPasses(0.5)).toBe(true);
    expect(examPasses(0.49)).toBe(false);
  });

  it("compte une question et demie par minute, entre six et trente", () => {
    expect(examQuestionCount(15)).toBe(10);
    expect(examQuestionCount(30)).toBe(20);
    expect(examQuestionCount(60)).toBe(30);
    expect(examQuestionCount(2)).toBe(6);
  });
});

describe("la note dans le barème du pays", () => {
  it("dit la même copie comme chaque pays la lit", () => {
    expect(examGradeLabel(0.675, "fr", "fr")).toBe("13,5/20");
    expect(examGradeLabel(0.675, "fr", "en")).toBe("13.5/20");
    expect(examGradeLabel(0.75, "de")).toBe("2,3");
    expect(examGradeLabel(0.7, "ch", "fr")).toBe("4,5");
    expect(examGradeLabel(0.87, "us")).toBe("B+");
    expect(examGradeLabel(0.87, null)).toBe("B+");
    expect(examGradeLabel(0.75, "it", "en")).toBe("7.5/10");
    expect(examGradeLabel(0.5, "lu")).toBe("30/60");
    expect(examGradeLabel(0.5, "tr")).toBe("50 %");
    expect(examGradeLabel(0.95, "uk")).toBe("A*");
    expect(examGradeLabel(0.2, "se")).toBe("F");
    expect(examGradeLabel(1.4, "fr", "fr")).toBe("20/20");
  });
});
