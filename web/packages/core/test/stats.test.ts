/**
 * Les séries et les niveaux de connaissance, calqués sur `MicaboTests/StudyStatsTests.swift`.
 */

import { describe, expect, it } from "vitest";

import {
  bestStreak,
  courseAudienceLabel,
  knowledgeDistribution,
  knowledgeLevel,
  mostReviewedCards,
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

  it("distribue le paquet dans l'ordre des barres", () => {
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

  it("marque d'une flamme les jours déjà révisés", () => {
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
    expect(days[0]?.reviewCount).toBe(2);
    expect(days[3]?.reviewCount).toBe(1);
  });
});

describe("l'audience d'un cours", () => {
  it("accorde vue et ajout", () => {
    expect(courseAudienceLabel(0, 0)).toBe("0 vue · 0 ajout");
    expect(courseAudienceLabel(1, 1)).toBe("1 vue · 1 ajout");
    expect(courseAudienceLabel(12, 3)).toBe("12 vues · 3 ajouts");
  });
});
