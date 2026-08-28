import { describe, expect, it } from "vitest";

import { addDays } from "../src/srs/exam";
import {
  buildExamInsight,
  cardKindLabel,
  chartOffsets,
  learnedPercent,
  weakNote,
  type InsightCard,
} from "../src/srs/exam-insight";

const now = new Date(2026, 8, 1, 10, 0);

function card(id: string, overrides: Partial<InsightCard> = {}): InsightCard {
  return {
    id,
    courseId: "svt",
    front: `Question ${id}`,
    kind: "choice",
    state: "review",
    intervalDays: 4,
    dueDate: addDays(now, 2),
    lapses: 0,
    isSuspended: false,
    ...overrides,
  };
}

describe("learnedPercent", () => {
  it("compte les cartes déjà commencées", () => {
    expect(
      learnedPercent([
        card("a", { state: "review" }),
        card("b", { state: "new" }),
        card("c", { state: "learning" }),
        card("d", { state: "new" }),
      ]),
    ).toBe(50);
  });

  it("reste à zéro sans cartes", () => {
    expect(learnedPercent([])).toBe(0);
  });
});

describe("chartOffsets", () => {
  it("garde douze jours derrière et le jour J quand il est proche", () => {
    const offsets = chartOffsets(3);
    expect(offsets[0]).toBe(-12);
    expect(offsets).toContain(0);
    expect(offsets.at(-1)).toBe(3);
    expect(offsets).toHaveLength(16);
  });

  it("ne dessine pas un barreau par jour quand l'examen est loin", () => {
    const offsets = chartOffsets(30);
    expect(offsets[0]).toBe(-12);
    expect(offsets).toContain(0);
    expect(offsets.at(-1)).toBe(30);
    expect(offsets.length).toBeLessThan(20);
  });
});

describe("cardKindLabel", () => {
  it("reprend les noms de la carte", () => {
    expect(cardKindLabel("choice")).toEqual({ id: "qcm", label: "QCM" });
    expect(cardKindLabel("cloze")).toEqual({ id: "trou", label: "Trou" });
    expect(cardKindLabel("occlusion")).toEqual({ id: "schema", label: "Schéma" });
    expect(cardKindLabel("basic")).toEqual({ id: "question", label: "Question" });
  });
});

describe("buildExamInsight", () => {
  const examDate = addDays(now, 3);

  it("ignore les cartes hors cours et les suspendues", () => {
    const insight = buildExamInsight({
      id: "e1",
      name: "Devoir de SVT",
      examDate,
      intensity: "standard",
      targetScore: 16,
      courseIds: ["svt"],
      cards: [
        card("in"),
        card("out", { courseId: "maths" }),
        card("off", { isSuspended: true }),
      ],
      reviews: [],
      now,
      country: "fr",
    });

    expect(insight.cardCount).toBe(1);
    expect(insight.gradeLabel).toBe("16/20");
    expect(insight.daysRemaining).toBe(3);
    expect(insight.learnedPct).toBe(100);
  });

  it("fait monter la courbe Micabo et descendre l'oubli", () => {
    const cards = [
      card("a", { state: "review", intervalDays: 5 }),
      card("b", { state: "new", dueDate: now }),
      card("c", { state: "learning", intervalDays: 0, dueDate: now }),
    ];
    const insight = buildExamInsight({
      id: "e1",
      name: "Devoir de SVT",
      examDate,
      intensity: "intense",
      targetScore: 16,
      courseIds: ["svt"],
      cards,
      reviews: [
        { cardId: "a", at: addDays(now, -2) },
        { cardId: "a", at: addDays(now, -2) },
      ],
      now,
      country: "fr",
    });

    const { withMicabo, without, examIndex, todayIndex, reviews } = insight.chart;
    expect(withMicabo[examIndex]!).toBeGreaterThan(withMicabo[todayIndex]!);
    expect(without[examIndex]!).toBeLessThan(without[todayIndex]!);
    expect(reviews[todayIndex - 2]).toBe(2);
    expect(insight.weak.length).toBeGreaterThan(0);
  });

  it("classe les oublis avant les neuves", () => {
    const insight = buildExamInsight({
      id: "e1",
      name: "Devoir",
      examDate,
      intensity: "standard",
      targetScore: 15,
      courseIds: ["svt"],
      cards: [
        card("new", { state: "new", front: "Nouvelle carte", dueDate: now }),
        card("lapse", { lapses: 2, front: "Où se forme la condensation ?", dueDate: now }),
        card("due", { front: "Encore due", dueDate: addDays(now, -1) }),
      ],
      reviews: [],
      now,
    });

    expect(insight.weak[0]?.id).toBe("lapse");
    expect(insight.weak[0]?.note).toBe("2 oublis");
    expect(insight.weak[0]?.kindLabel).toBe("QCM");
  });

  it("reste lisible sans cartes", () => {
    const insight = buildExamInsight({
      id: "e1",
      name: "Devoir",
      examDate,
      intensity: "standard",
      targetScore: 15,
      courseIds: ["svt"],
      cards: [],
      reviews: [],
      now,
    });
    expect(insight.learnedPct).toBe(0);
    expect(insight.weak).toEqual([]);
    expect(insight.chart.reviews.every((count) => count === 0)).toBe(true);
  });
});

describe("weakNote", () => {
  it("dit pourquoi la carte est faible", () => {
    expect(weakNote(card("a", { lapses: 1 }), now)).toBe("1 oubli");
    expect(weakNote(card("a", { state: "new" }), now)).toBe("Nouvelle");
    expect(weakNote(card("a", { dueDate: addDays(now, -1) }), now)).toBe("Encore due");
  });
});
