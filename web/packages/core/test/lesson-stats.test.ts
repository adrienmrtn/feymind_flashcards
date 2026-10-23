/**
 * Les trois chiffres de Home et « Reprendre » (`MicaboTests/HomeStatsTests.swift`), les
 * tons d'une leçon (`LessonTone.swift`) et la porte du gratuit (`LessonAllowance`).
 */

import { describe, expect, it } from "vitest";

import { EXTRA_ALLOWANCE, MIKA_ALLOWANCE, courseSourceFor, hasUsedFreeLesson, isImportSource, lessonGate } from "../src/lesson/allowance";
import { pathCircles } from "../src/lesson/path-layout";
import { homeStats, learnedCardCount, resumeTarget, studyTime } from "../src/lesson/stats";
import { LESSON_TONES, lessonTone, nextTone, readTone, stableTone, toneVars } from "../src/lesson/tone";
import { addTime, emptyProgress } from "../src/lesson/types";

const now = new Date(2026, 9, 22, 12, 0);
const day = 24 * 3600 * 1000;
const labels = { intro: "Intro", checkpoint: "Checkpoint", final: "Quiz final" };

describe("les chiffres de Home", () => {
  it("sont mesurés : le temps s'additionne, une leçon finie compte, une carte à plus de sept jours aussi", () => {
    let first = addTime(emptyProgress(), 1800, "notes");
    first = addTime(first, 600, "quiz");
    first = { ...first, finishedAt: now.toISOString() };
    const second = addTime(emptyProgress(), 1200, "flashcards");
    const cards = [
      { state: "review", dueDate: new Date(now.getTime() + 10 * day), isSuspended: false },
      { state: "review", dueDate: new Date(now.getTime() + 2 * day), isSuspended: false },
      { state: "new", dueDate: new Date(now.getTime() + 30 * day), isSuspended: false },
      { state: "review", dueDate: new Date(now.getTime() + 30 * day), isSuspended: true },
    ];
    expect(homeStats([{ progress: first }, { progress: second }], cards, now)).toEqual({
      seconds: 3600, learnedLessons: 1, learnedCards: 1,
    });
    expect(learnedCardCount([], now)).toBe(0);
  });

  it("se lisent en minutes puis en heures", () => {
    expect(studyTime(12 * 60)).toEqual({ unit: "minutes", value: 12 });
    expect(studyTime(5400)).toEqual({ unit: "hours", value: 1.5 });
    expect(studyTime(3600)).toEqual({ unit: "hours", value: 1 });
    expect(studyTime(14 * 3600 + 100)).toEqual({ unit: "hours", value: 14 });
  });

  it("reprennent la dernière leçon ouverte, à l'étape où elle attend", () => {
    const circles = pathCircles([
      { title: "Thème 1", icon: "livre-ouvert", symbol: "book" },
      { title: "Thème 2", icon: "livre-ouvert", symbol: "atom" },
    ], labels);
    const picked = resumeTarget([
      { id: "old", title: "Ancienne", lastOpenedAt: new Date(now.getTime() - 3600_000), circles, done: [] },
      { id: "recent", title: "Récente", lastOpenedAt: now, circles, done: ["intro", "notes:0"] },
      { id: "never", title: "Jamais ouverte", lastOpenedAt: null, circles, done: [] },
    ])!;
    expect(picked.lessonId).toBe("recent");
    expect(picked.circleNumber).toBe(3);
    expect(picked.circleTitle).toBe("Thème 2");
    expect(picked.percent).toBeGreaterThan(0);
    expect(resumeTarget([{ id: "never", title: "x", lastOpenedAt: null, circles, done: [] }])).toBeNull();
  });
});

describe("les tons", () => {
  it("tournent, et retombent sur le bleu", () => {
    expect(nextTone(null)).toBe("yellow");
    expect(nextTone("yellow")).toBe("mint");
    expect(nextTone("lilac")).toBe("yellow");
    expect(readTone("licorne")).toBe("blue");
    expect(readTone("pink")).toBe("pink");
    expect(toneVars("mint").vivid).toBe("var(--color-tone-mint-vivid)");
  });

  it("donnent un ton stable à un ancien cours, le même que l'app", () => {
    const id = "0b4f3b9c-1c5b-4e2e-9c7f-0a1b2c3d4e5f";
    expect(stableTone(id)).toBe(stableTone(id.toUpperCase()));
    expect(LESSON_TONES).toContain(stableTone(id));
    expect(lessonTone(id, "mint")).toBe("mint");
    expect(lessonTone(id, "")).toBe(stableTone(id));
    // Sur beaucoup d'identifiants, les cinq tons sortent.
    const seen = new Set(Array.from({ length: 200 }, (_, index) => stableTone(`id-${index}`)));
    expect(seen.size).toBe(5);
  });
});

describe("la porte du gratuit", () => {
  const own = { source: "text", isFromLibrary: false };
  it("offre une leçon depuis un sujet ou un texte, et pas plus", () => {
    expect(lessonGate({ isPro: false, source: "topic", courses: [] })).toBeNull();
    expect(lessonGate({ isPro: false, source: "text", courses: [] })).toBeNull();
    expect(lessonGate({ isPro: false, source: "pdf", courses: [] })).toBe("import_pro");
    expect(lessonGate({ isPro: false, source: "topic", courses: [own] })).toBe("free_limit");
    expect(lessonGate({ isPro: true, source: "pdf", courses: [own] })).toBeNull();
  });

  it("ne compte ni les exemples, ni la bibliothèque, ni les paquets", () => {
    expect(hasUsedFreeLesson([{ source: "sample", isFromLibrary: false }])).toBe(false);
    expect(hasUsedFreeLesson([{ source: "deck", isFromLibrary: false }])).toBe(false);
    expect(hasUsedFreeLesson([{ source: "text", isFromLibrary: true }])).toBe(false);
    expect(hasUsedFreeLesson([{ source: "pdf", isFromLibrary: false }])).toBe(true);
    expect(isImportSource("youtube")).toBe(true);
    expect(courseSourceFor("audio")).toBe("text");
    expect(courseSourceFor("docx")).toBe("docx");
  });

  it("tient les mêmes nombres que le serveur pour Mika et les suppléments", () => {
    expect(MIKA_ALLOWANCE).toEqual({ freeQuestions: 1, proMessagesPerDay: 30 });
    expect(EXTRA_ALLOWANCE.proPracticePerDay).toBe(40);
    expect(EXTRA_ALLOWANCE.proExamsPerDay).toBe(10);
  });
});
