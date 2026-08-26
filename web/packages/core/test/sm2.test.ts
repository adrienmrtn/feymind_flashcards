/**
 * Les tests de `MicaboTests/SM2SchedulerTests.swift`, portés un pour un.
 *
 * **Les nombres sont ceux du Swift, pas des nombres recalculés ici.** C'est tout l'intérêt du
 * fichier : si le port dérive d'un dixième, l'un de ces treize cas tombe. Un port sans ses
 * tests n'est pas un port, c'est du code qu'on croit identique.
 */

import { describe, expect, it } from "vitest";

import {
  DETERMINISTIC_CONFIG,
  delaySeconds,
  formatDelay,
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

describe("apprentissage", () => {
  it("une carte neuve notée Correct sort en révision à un jour", () => {
    const outcome = schedule(newCardSnapshot(), ReviewRating.good, { now, config });

    expect(outcome.state).toBe("review");
    expect(outcome.intervalDays).toBe(1);
    expect(outcome.repetitions).toBe(1);
  });

  it("une carte neuve notée À revoir reste sur le premier palier", () => {
    const outcome = schedule(newCardSnapshot(), ReviewRating.again, { now, config });

    expect(outcome.state).toBe("learning");
    expect(outcome.stepIndex).toBe(0);
    expect(delaySeconds(outcome, now)).toBeCloseTo(60, 0);
  });

  it("Difficile envoie au dernier palier, pas au premier", () => {
    const outcome = schedule(newCardSnapshot(), ReviewRating.hard, { now, config });

    expect(outcome.state).toBe("learning");
    expect(outcome.stepIndex).toBe(1);
    expect(delaySeconds(outcome, now)).toBeCloseTo(10 * 60, 0);
  });

  it("Correct depuis le palier de dix minutes sort aussi à un jour", () => {
    const outcome = schedule(snapshot({ state: "learning", stepIndex: 1 }), ReviewRating.good, {
      now,
      config,
    });

    expect(outcome.state).toBe("review");
    expect(outcome.intervalDays).toBe(1);
    expect(outcome.repetitions).toBe(1);
  });

  it("Facile sur une carte neuve saute à quatre jours", () => {
    const outcome = schedule(newCardSnapshot(), ReviewRating.easy, { now, config });

    expect(outcome.state).toBe("review");
    expect(outcome.intervalDays).toBe(4);
  });
});

describe("révision", () => {
  const reviewing = snapshot({
    state: "review",
    intervalDays: 10,
    easeFactor: 2.5,
    repetitions: 3,
  });

  it("Correct multiplie par la facilité", () => {
    const outcome = schedule(reviewing, ReviewRating.good, { now, config });

    expect(outcome.intervalDays).toBeCloseTo(25, 2);
    expect(outcome.easeFactor).toBeCloseTo(2.5, 3);
  });

  it("Difficile baisse la facilité et applique son multiplicateur", () => {
    const outcome = schedule(reviewing, ReviewRating.hard, { now, config });

    expect(outcome.easeFactor).toBeCloseTo(2.35, 3);
    expect(outcome.intervalDays).toBeCloseTo(12, 2);
  });

  it("Facile applique son bonus et remonte la facilité", () => {
    const outcome = schedule(reviewing, ReviewRating.easy, { now, config });

    expect(outcome.easeFactor).toBeCloseTo(2.65, 3);
    expect(outcome.intervalDays).toBeCloseTo(34.45, 2);
  });

  it("l'intervalle grandit toujours d'au moins un jour", () => {
    const outcome = schedule(
      snapshot({ state: "review", intervalDays: 30, easeFactor: 1.3, repetitions: 8 }),
      ReviewRating.hard,
      { now, config },
    );

    expect(outcome.intervalDays).toBeGreaterThanOrEqual(31);
  });
});

describe("rechute", () => {
  it("À revoir en révision fait entrer en réapprentissage et coûte de la facilité", () => {
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
    // Une carte oubliée repart du premier palier, comme une neuve.
    expect(delaySeconds(outcome, now)).toBeCloseTo(60, 0);
    expect(outcome.intervalDays).toBeCloseTo(1, 3);
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
    expect(outcome.intervalDays).toBeCloseTo(1, 3);
    expect(outcome.repetitions).toBe(7);
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
  it("les quatre boutons d'une carte neuve annoncent 1 min, 10 min, 1 j, 4 j", () => {
    const labels = previewLabels(newCardSnapshot(), { now, config });

    expect(labels[ReviewRating.again]).toBe("1 min");
    expect(labels[ReviewRating.hard]).toBe("10 min");
    expect(labels[ReviewRating.good]).toBe("1 j");
    expect(labels[ReviewRating.easy]).toBe("4 j");
  });

  it("met un délai en forme", () => {
    expect(formatDelay(30)).toBe("< 1 min");
    expect(formatDelay(600)).toBe("10 min");
    expect(formatDelay(7_200)).toBe("2 h");
    expect(formatDelay(4 * 86_400)).toBe("4 j");
    expect(formatDelay(90 * 86_400)).toBe("3 mois");
    expect(formatDelay(730 * 86_400)).toBe("2 ans");
  });
});

describe("la dispersion", () => {
  it("ne bouge pas un intervalle court", () => {
    // Sous 2,5 jours, Anki ne disperse pas : deux cartes qui sortent d'apprentissage le même
    // jour doivent revenir le lendemain, pas s'éparpiller sur la semaine.
    const outcome = schedule(snapshot({ state: "learning", stepIndex: 1 }), ReviewRating.good, {
      now,
      random: () => 0,
    });

    expect(outcome.intervalDays).toBe(1);
    expect(delaySeconds(outcome, now)).toBeCloseTo(86_400, 0);
  });

  it("reste dans sa fourchette, et jamais sous un jour", () => {
    const reviewing = snapshot({ state: "review", intervalDays: 10, easeFactor: 2.5 });

    // 25 jours, dispersion de 10 % soit 2,5 jours : le tirage extrême borne l'écart.
    const low = schedule(reviewing, ReviewRating.good, { now, random: () => 0 });
    const high = schedule(reviewing, ReviewRating.good, { now, random: () => 1 });

    expect(delaySeconds(low, now) / 86_400).toBeCloseTo(22.5, 2);
    expect(delaySeconds(high, now) / 86_400).toBeCloseTo(27.5, 2);
    // L'intervalle enregistré, lui, n'est pas dispersé : seule l'échéance l'est.
    expect(low.intervalDays).toBeCloseTo(25, 2);
    expect(high.intervalDays).toBeCloseTo(25, 2);
  });
});
