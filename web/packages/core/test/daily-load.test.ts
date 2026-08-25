/**
 * Le rythme quotidien, et son arrondi.
 *
 * L'arrondi est la raison pour laquelle ce port s'est fait sur le Swift et non sur une
 * description : `25` minutes donnent `12,5` cartes, que Swift arrondit **au plus loin de
 * zéro**, donc à 13. Une note de synthèse lue de mémoire disait 12. Sur un an, c'est une carte
 * par jour de moins, tous les jours.
 */

import { describe, expect, it } from "vitest";

import {
  DAILY_MINUTES_STEPS,
  DEFAULT_DAILY_MINUTES,
  cardsPerYear,
  dailyMinutesLabel,
  minutesAtStepIndex,
  nearestStep,
  newCardsPerDay,
  paceFor,
  stepIndexFor,
} from "../src/srs/daily-load";

describe("plafond de cartes neuves", () => {
  it("suit la table des paliers, arrondi compris", () => {
    const expected: Record<number, number> = {
      5: 3,
      10: 5,
      15: 8,
      20: 10,
      25: 13,
      30: 15,
      45: 23,
      60: 30,
      75: 38,
      90: 45,
      105: 53,
      120: 60,
    };

    for (const step of DAILY_MINUTES_STEPS) {
      expect(newCardsPerDay(step)).toBe(expected[step]);
    }
  });

  it("ne descend jamais sous deux cartes", () => {
    expect(newCardsPerDay(0)).toBe(2);
    expect(newCardsPerDay(1)).toBe(2);
    expect(newCardsPerDay(3)).toBe(2);
  });

  it("le défaut du produit sert huit cartes neuves par jour", () => {
    expect(DEFAULT_DAILY_MINUTES).toBe(15);
    expect(newCardsPerDay(DEFAULT_DAILY_MINUTES)).toBe(8);
  });
});

describe("paliers", () => {
  it("ramène une valeur quelconque sur un cran existant", () => {
    expect(nearestStep(7)).toBe(5);
    expect(nearestStep(8)).toBe(10);
    expect(nearestStep(38)).toBe(45);
    expect(nearestStep(1_000)).toBe(120);
  });

  it("retrouve l'index d'un palier, et l'inverse", () => {
    expect(stepIndexFor(15)).toBe(2);
    expect(minutesAtStepIndex(2)).toBe(15);
    expect(minutesAtStepIndex(99)).toBe(5);
  });
});

describe("libellés", () => {
  it("passe des minutes aux heures au bon endroit", () => {
    expect(dailyMinutesLabel(15)).toBe("15 min");
    expect(dailyMinutesLabel(45)).toBe("45 min");
    expect(dailyMinutesLabel(60)).toBe("1 h");
    expect(dailyMinutesLabel(90)).toBe("1 h 30");
    expect(dailyMinutesLabel(120)).toBe("2 h");
  });

  it("nomme le rythme", () => {
    expect(paceFor(10)).toBe("gentle");
    expect(paceFor(15)).toBe("cruising");
    expect(paceFor(30)).toBe("solid");
    expect(paceFor(60)).toBe("intense");
  });
});

describe("projection annuelle", () => {
  it("arrondit à la dizaine, comme l'écran qui l'affiche", () => {
    // C'est le nombre du titre : « dans un an, tu auras appris N cartes ».
    expect(cardsPerYear(15)).toBe(2_740);
    expect(cardsPerYear(30)).toBe(5_480);
    expect(cardsPerYear(120)).toBe(21_900);
  });
});
