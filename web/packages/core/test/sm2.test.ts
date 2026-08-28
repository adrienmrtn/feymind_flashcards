/**
 * SM-2 d'Anki, réglages legacy par défaut.
 *
 * Les nombres sont ceux d'Anki, vérifiés des deux côtés : ici et dans
 * `MicaboTests/SM2SchedulerTests.swift`.
 */

import { describe, expect, it } from "vitest";

import {
  DETERMINISTIC_CONFIG,
  delaySeconds,
  formatDelay,
  hardStepMinutes,
  newCardSnapshot,
  previewLabels,
  schedule,
} from "../src/srs/sm2";
import { ReviewRating, type CardSnapshot } from "../src/srs/types";

const now = new Date(1_700_000_000 * 1000);
const config = DETERMINISTIC_CONFIG;

function snapshot(overrides: Partial<CardSnapshot>): CardSnapshot {
  return newCardSnapshot(overrides);
}

describe("apprentissage — Anki SM-2", () => {
  it("À revoir ramène au premier palier, une minute", () => {
    const outcome = schedule(newCardSnapshot(), ReviewRating.again, { now, config });

    expect(outcome.state).toBe("learning");
    expect(outcome.stepIndex).toBe(0);
    expect(delaySeconds(outcome, now)).toBeCloseTo(60, 0);
  });

  it("Difficile au premier palier est la moyenne des deux premiers (6 min)", () => {
    const outcome = schedule(newCardSnapshot(), ReviewRating.hard, { now, config });

    expect(outcome.state).toBe("learning");
    expect(outcome.stepIndex).toBe(0);
    expect(delaySeconds(outcome, now)).toBeCloseTo(5.5 * 60, 0);
    expect(hardStepMinutes([1, 10], 0)).toBe(5.5);
  });

  it("Correct avance au palier de dix minutes, sans diplômer", () => {
    const outcome = schedule(newCardSnapshot(), ReviewRating.good, { now, config });

    expect(outcome.state).toBe("learning");
    expect(outcome.stepIndex).toBe(1);
    expect(delaySeconds(outcome, now)).toBeCloseTo(10 * 60, 0);
    expect(outcome.repetitions).toBe(0);
  });

  it("Correct depuis le dernier palier diplôme à un jour", () => {
    const outcome = schedule(snapshot({ state: "learning", stepIndex: 1 }), ReviewRating.good, {
      now,
      config,
    });

    expect(outcome.state).toBe("review");
    expect(outcome.intervalDays).toBe(1);
    expect(outcome.repetitions).toBe(1);
  });

  it("Difficile au dernier palier rejoue ce palier", () => {
    const outcome = schedule(snapshot({ state: "learning", stepIndex: 1 }), ReviewRating.hard, {
      now,
      config,
    });

    expect(outcome.state).toBe("learning");
    expect(outcome.stepIndex).toBe(1);
    expect(delaySeconds(outcome, now)).toBeCloseTo(10 * 60, 0);
  });

  it("Facile sur une carte neuve saute à quatre jours", () => {
    const outcome = schedule(newCardSnapshot(), ReviewRating.easy, { now, config });

    expect(outcome.state).toBe("review");
    expect(outcome.intervalDays).toBe(4);
  });
});

describe("révision — Anki SM-2", () => {
  const reviewing = snapshot({
    state: "review",
    intervalDays: 10,
    easeFactor: 2.5,
    repetitions: 3,
  });

  it("Correct multiplie par la facilité, sans la changer", () => {
    const outcome = schedule(reviewing, ReviewRating.good, { now, config });

    expect(outcome.intervalDays).toBe(25);
    expect(outcome.easeFactor).toBeCloseTo(2.5, 3);
  });

  it("Difficile baisse la facilité et applique 1,2", () => {
    const outcome = schedule(reviewing, ReviewRating.hard, { now, config });

    expect(outcome.easeFactor).toBeCloseTo(2.35, 3);
    expect(outcome.intervalDays).toBe(12);
  });

  it("Facile utilise la facilité actuelle, puis la remonte", () => {
    const outcome = schedule(reviewing, ReviewRating.easy, { now, config });

    expect(outcome.easeFactor).toBeCloseTo(2.65, 3);
    // 10 × 2,5 × 1,3 = 32,5 → Anki tronque à 32.
    expect(outcome.intervalDays).toBe(32);
  });

  it("l'intervalle grandit toujours d'au moins un jour", () => {
    const outcome = schedule(
      snapshot({ state: "review", intervalDays: 30, easeFactor: 1.3, repetitions: 8 }),
      ReviewRating.hard,
      { now, config },
    );

    expect(outcome.intervalDays).toBeGreaterThanOrEqual(31);
  });

  it("un retard de quatre jours s'ajoute à moitié à Correct", () => {
    const due = new Date(now.getTime() - 4 * 86_400 * 1000);
    const outcome = schedule(
      snapshot({ state: "review", intervalDays: 10, easeFactor: 2.5, dueDate: due }),
      ReviewRating.good,
      { now, config },
    );

    // (10 + 4/2) × 2,5 = 30
    expect(outcome.intervalDays).toBe(30);
  });
});

describe("rechute — Anki SM-2", () => {
  it("À revoir en révision entre en réapprentissage à dix minutes", () => {
    const outcome = schedule(
      snapshot({
        state: "review",
        intervalDays: 30,
        easeFactor: 2.5,
        repetitions: 6,
        lapses: 1,
      }),
      ReviewRating.again,
      { now, config },
    );

    expect(outcome.state).toBe("relearning");
    expect(outcome.lapses).toBe(2);
    expect(outcome.easeFactor).toBeCloseTo(2.3, 3);
    expect(delaySeconds(outcome, now)).toBeCloseTo(10 * 60, 0);
    expect(outcome.intervalDays).toBe(1);
  });

  it("Correct en réapprentissage ramène en révision", () => {
    const outcome = schedule(
      snapshot({
        state: "relearning",
        intervalDays: 1,
        easeFactor: 2.3,
        repetitions: 6,
        lapses: 2,
      }),
      ReviewRating.good,
      { now, config },
    );

    expect(outcome.state).toBe("review");
    expect(outcome.intervalDays).toBe(1);
    expect(outcome.repetitions).toBe(7);
  });

  it("Facile en réapprentissage ajoute un jour", () => {
    const outcome = schedule(
      snapshot({
        state: "relearning",
        intervalDays: 1,
        easeFactor: 2.3,
        repetitions: 6,
        lapses: 2,
      }),
      ReviewRating.easy,
      { now, config },
    );

    expect(outcome.state).toBe("review");
    expect(outcome.intervalDays).toBe(2);
  });

  it("Difficile en réapprentissage, palier unique, vaut 15 min", () => {
    const outcome = schedule(
      snapshot({
        state: "relearning",
        intervalDays: 1,
        easeFactor: 2.3,
        repetitions: 6,
        lapses: 2,
      }),
      ReviewRating.hard,
      { now, config },
    );

    expect(outcome.state).toBe("relearning");
    expect(delaySeconds(outcome, now)).toBeCloseTo(15 * 60, 0);
  });

  it("la facilité ne descend jamais sous son plancher", () => {
    let current = snapshot({
      state: "review",
      intervalDays: 5,
      easeFactor: 1.35,
      repetitions: 4,
    });

    for (let pass = 0; pass < 5; pass += 1) {
      const outcome = schedule(current, ReviewRating.hard, { now, config });
      current = {
        state: outcome.state,
        intervalDays: outcome.intervalDays,
        easeFactor: outcome.easeFactor,
        repetitions: outcome.repetitions,
        lapses: outcome.lapses,
        stepIndex: outcome.stepIndex,
      };
    }

    expect(current.easeFactor).toBeCloseTo(1.3, 4);
  });
});

describe("libellés", () => {
  it("les quatre boutons d'une carte neuve annoncent 1 min, 6 min, 10 min, 4 j", () => {
    const labels = previewLabels(newCardSnapshot(), { now, config });

    expect(labels[ReviewRating.again]).toBe("1 min");
    expect(labels[ReviewRating.hard]).toBe("6 min");
    expect(labels[ReviewRating.good]).toBe("10 min");
    expect(labels[ReviewRating.easy]).toBe("4 j");
  });

  it("met un délai en forme", () => {
    expect(formatDelay(30)).toBe("< 1 min");
    expect(formatDelay(330)).toBe("6 min");
    expect(formatDelay(600)).toBe("10 min");
    expect(formatDelay(7_200)).toBe("2 h");
    expect(formatDelay(4 * 86_400)).toBe("4 j");
    expect(formatDelay(90 * 86_400)).toBe("3 mois");
    expect(formatDelay(730 * 86_400)).toBe("2 ans");
  });
});

describe("la dispersion", () => {
  it("ne bouge pas un intervalle court", () => {
    const outcome = schedule(snapshot({ state: "learning", stepIndex: 1 }), ReviewRating.good, {
      now,
      random: () => 0,
    });

    expect(outcome.intervalDays).toBe(1);
    expect(delaySeconds(outcome, now)).toBeCloseTo(86_400, 0);
  });

  it("reste dans la fourchette entière d'Anki, et stocke cet entier", () => {
    const reviewing = snapshot({ state: "review", intervalDays: 10, easeFactor: 2.5 });

    const low = schedule(reviewing, ReviewRating.good, { now, random: () => 0 });
    const high = schedule(reviewing, ReviewRating.good, { now, random: () => 1 });

    // 25 j → fuzz = max(2, trunc(25 × 0,15)) = 3 → [22, 28]
    expect(low.intervalDays).toBe(22);
    expect(high.intervalDays).toBe(28);
    expect(delaySeconds(low, now) / 86_400).toBe(22);
    expect(delaySeconds(high, now) / 86_400).toBe(28);
  });
});
