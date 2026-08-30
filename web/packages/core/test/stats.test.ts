/**
 * Les séries et les niveaux de connaissance, calqués sur `MicaboTests/StudyStatsTests.swift`.
 */

import { describe, expect, it } from "vitest";

import {
  bestStreak,
  courseAudienceLabel,
  knowledgeDistribution,
  knowledgeLevel,
  knowledgePie,
  mostReviewedCards,
  rankReviewedCards,
  streak,
  weekStrip,
} from "../src/stats";

const now = new Date(1_700_000_000 * 1000);

function day(offset: number): Date {
  const date = new Date(now);
  date.setHours(0, 0, 0, 0);
  date.setDate(date.getDate() + offset);
  return date;
}

describe("la série", () => {
  it("compte les jours consécutifs", () => {
    expect(streak([day(0), day(-1), day(-2), day(-4)], now)).toBe(3);
  });

  it("tient encore si aujourd'hui n'a pas commencé", () => {
    expect(streak([day(-1), day(-2)], now)).toBe(2);
  });

  it("casse après un jour manqué", () => {
    expect(streak([day(-3)], now)).toBe(0);
    expect(streak([], now)).toBe(0);
  });

  it("calcule le record sur tout l'historique", () => {
    const dates = [day(-20), day(-19), day(-18), day(-17), day(-1), day(0)];
    expect(bestStreak(dates)).toBe(4);
    expect(streak(dates, now)).toBe(2);
  });

  it("compte des jours, pas des révisions", () => {
    expect(bestStreak([day(0), day(0), day(0)])).toBe(1);
    expect(bestStreak([])).toBe(0);
  });
});

describe("le niveau de connaissance", () => {
  it("classe une carte neuve, en cours, en révision ou maîtrisée", () => {
    expect(knowledgeLevel({ state: "new", intervalDays: 0 })).toBe("new");
    expect(knowledgeLevel({ state: "learning", intervalDays: 0 })).toBe("learning");
    expect(knowledgeLevel({ state: "relearning", intervalDays: 2 })).toBe("learning");
    expect(knowledgeLevel({ state: "review", intervalDays: 6 })).toBe("review");
    expect(knowledgeLevel({ state: "review", intervalDays: 21 })).toBe("mastered");
    expect(knowledgeLevel({ state: "new", intervalDays: 30 })).toBe("mastered");
  });

  it("distribue le paquet dans l'ordre des parts", () => {
    const buckets = knowledgeDistribution([
      { state: "new", intervalDays: 0 },
      { state: "new", intervalDays: 0 },
      { state: "learning", intervalDays: 0 },
      { state: "review", intervalDays: 4 },
      { state: "review", intervalDays: 40 },
    ]);

    expect(buckets.map((bucket) => [bucket.id, bucket.count])).toEqual([
      ["new", 2],
      ["learning", 1],
      ["review", 1],
      ["mastered", 1],
    ]);
  });

  it("découpe le camembert en parts qui font le tour", () => {
    const slices = knowledgePie([
      { id: "new", label: "Nouvelles", count: 2 },
      { id: "learning", label: "En cours", count: 1 },
      { id: "review", label: "En révision", count: 1 },
      { id: "mastered", label: "Parfaitement maîtrisées", count: 0 },
    ]);

    expect(slices.map((slice) => slice.sweep)).toEqual([0.5, 0.25, 0.25, 0]);
    expect(slices[0]?.start).toBe(0);
    expect(slices[2]?.start).toBeCloseTo(0.75);
    expect(slices.reduce((sum, slice) => sum + slice.sweep, 0)).toBeCloseTo(1);
  });
});

describe("les cartes les plus passées", () => {
  it("agrège les passages et ignore une carte inconnue", () => {
    const top = mostReviewedCards(
      [
        { cardId: "a" },
        { cardId: "a" },
        { cardId: "b" },
        { cardId: "ghost" },
        { cardId: null },
      ],
      [
        { id: "a", front: "1914" },
        { id: "b", front: "1789" },
      ],
      2,
    );

    expect(top).toEqual([
      { id: "a", front: "1914", passes: 2 },
      { id: "b", front: "1789", passes: 1 },
    ]);
  });

  it("donne le même classement à partir de passages déjà comptés", () => {
    const cards = [
      { id: "a", front: "1914" },
      { id: "b", front: "1789" },
    ];

    expect(
      rankReviewedCards(
        [
          { cardId: "b", passes: 1 },
          { cardId: "a", passes: 2 },
          { cardId: "ghost", passes: 9 },
        ],
        cards,
        2,
      ),
    ).toEqual(
      mostReviewedCards(
        [{ cardId: "a" }, { cardId: "a" }, { cardId: "b" }, { cardId: "ghost" }],
        cards,
        2,
      ),
    );
  });
});

describe("la semaine glissante", () => {
  it("étale trois jours avant, aujourd'hui, trois jours après", () => {
    const days = weekStrip([], [], now);
    expect(days.map((day) => day.offset)).toEqual([-3, -2, -1, 0, 1, 2, 3]);
    expect(days[3]?.date.getTime()).toBe(day(0).getTime());
  });

  it("pose les cartes en retard aujourd'hui, et garde les jours à venir", () => {
    const days = weekStrip(
      [
        { dueDate: day(-2) },
        { dueDate: day(0) },
        { dueDate: day(1) },
        { dueDate: day(1) },
        { dueDate: day(3) },
        { dueDate: day(8) },
        { dueDate: day(2), isSuspended: true },
      ],
      [],
      now,
    );

    expect(days.map((day) => day.planned)).toEqual([0, 0, 0, 2, 2, 0, 1]);
  });

  it("ne compte les neuves que dans le budget du jour", () => {
    const days = weekStrip(
      [
        { dueDate: day(0), state: "new" },
        { dueDate: day(0), state: "new" },
        { dueDate: day(0), state: "new" },
        { dueDate: day(-1), state: "review" },
        { dueDate: day(2), state: "review" },
      ],
      [],
      now,
      { newRemaining: 1 },
    );

    expect(days.map((day) => day.planned)).toEqual([0, 0, 0, 2, 0, 1, 0]);
  });

  it("compte les cartes révisées sur les jours passés, pas seulement aujourd'hui", () => {
    const days = weekStrip([], [day(-3), day(-3), day(0), day(4)], now);

    expect(days.map((day) => day.reviewed)).toEqual([
      true,
      false,
      false,
      true,
      false,
      false,
      false,
    ]);
    expect(days.map((day) => day.reviewCount)).toEqual([2, 0, 0, 1, 0, 0, 0]);
  });

  it("empile révisées et à réviser sur le même jour", () => {
    const days = weekStrip(
      [
        { dueDate: day(0), state: "review" },
        { dueDate: day(0), state: "review" },
        { dueDate: day(1), state: "review" },
      ],
      [day(-1), day(-1), day(-1), day(0)],
      now,
    );

    expect(days[2]?.reviewCount).toBe(3);
    expect(days[2]?.planned).toBe(0);
    expect(days[3]?.reviewCount).toBe(1);
    expect(days[3]?.planned).toBe(2);
    expect(days[4]?.planned).toBe(1);
    expect(days[4]?.reviewCount).toBe(0);
  });
});

describe("l'audience d'un cours", () => {
  it("accorde vue et ajout", () => {
    expect(courseAudienceLabel(0, 0)).toBe("0 vue · 0 ajout");
    expect(courseAudienceLabel(1, 1)).toBe("1 vue · 1 ajout");
    expect(courseAudienceLabel(12, 3)).toBe("12 vues · 3 ajouts");
  });
});
