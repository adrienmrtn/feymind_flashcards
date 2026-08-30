/**
 * Finir une session = vider la file, y compris les cartes qui reviennent dans les
 * dix minutes. Et **sans attendre** : quand il ne reste qu'elles, elles sont servies
 * tout de suite.
 */

import { describe, expect, it } from "vitest";

import { DETERMINISTIC_CONFIG, newCardSnapshot, schedule } from "../src/srs/sm2";
import { ReviewRating } from "../src/srs/types";
import {
  LEARN_AHEAD_SECONDS,
  advanceSession,
  enqueueInitial,
  returnsInSession,
} from "../src/srs/session";

const now = new Date(2026, 7, 26, 15, 0, 0);

describe("returnsInSession", () => {
  it("garde une carte à dix minutes, le palier « Correct » d'une neuve", () => {
    const due = new Date(now.getTime() + 10 * 60 * 1000);
    expect(returnsInSession(due, now)).toBe(true);
  });

  it("laisse sortir une carte à quinze minutes, Hard d'une rechute", () => {
    const due = new Date(now.getTime() + 15 * 60 * 1000);
    expect(returnsInSession(due, now)).toBe(false);
  });

  it("garde une carte pile à dix minutes, et rien au-delà", () => {
    expect(returnsInSession(new Date(now.getTime() + 10 * 60 * 1000), now)).toBe(true);
    expect(returnsInSession(new Date(now.getTime() + 10 * 60 * 1000 + 1), now)).toBe(false);
  });

  it("garde une carte à une minute", () => {
    const due = new Date(now.getTime() + 60 * 1000);
    expect(returnsInSession(due, now)).toBe(true);
  });

  it("laisse sortir une carte au-delà de la fenêtre d'anticipation", () => {
    const due = new Date(now.getTime() + (LEARN_AHEAD_SECONDS + 1) * 1000);
    expect(returnsInSession(due, now)).toBe(false);
  });

  it("laisse sortir une carte diplômée à un jour", () => {
    const due = new Date(now.getTime() + 24 * 3_600 * 1000);
    expect(returnsInSession(due, now)).toBe(false);
  });

  it("garde une carte déjà due", () => {
    const due = new Date(now.getTime() - 1000);
    expect(returnsInSession(due, now)).toBe(true);
  });
});

describe("advanceSession", () => {
  it("sert tout de suite la carte qui attend, sans compte à rebours", () => {
    const pending = [{ card: "dix minutes", availableAt: new Date(now.getTime() + 10 * 60 * 1000) }];

    const served = advanceSession(pending, now);
    expect(served.current).toBe("dix minutes");
    expect(served.pending).toEqual([]);
    expect(served.done).toBe(false);
  });

  it("n'est finie que lorsque la file est vide", () => {
    expect(advanceSession([], now).done).toBe(true);
  });

  it("ajoute la carte à dix minutes à la fin du paquet, et ne termine pas avant", () => {
    const pack = enqueueInitial(["a", "b"], now);
    const first = advanceSession(pack, now);
    expect(first.current).toBe("a");

    const afterA = [
      ...first.pending,
      { card: "a", availableAt: new Date(now.getTime() + 10 * 60 * 1000) },
    ];
    const second = advanceSession(afterA, now);
    expect(second.current).toBe("b");
    expect(second.done).toBe(false);

    const third = advanceSession(second.pending, now);
    expect(third.current).toBe("a");
    expect(third.done).toBe(false);
    expect(advanceSession(third.pending, now).done).toBe(true);
  });

  it("sert d'abord la carte la plus ancienne, pas celle qui vient d'être ratée", () => {
    const overdue = { card: "en retard", availableAt: new Date(now.getTime() - 1000) };
    const justFailed = { card: "ratée à l'instant", availableAt: new Date(now.getTime() + 60 * 1000) };

    const pulled = advanceSession([justFailed, overdue], now);
    expect(pulled.current).toBe("en retard");
    expect(pulled.pending).toEqual([justFailed]);
  });

  it("garde l'ordre du paquet quand tout a été raté", () => {
    const failed = ["a", "b", "c"].map((card, index) => ({
      card,
      availableAt: new Date(now.getTime() + 60 * 1000 + index * 1000),
    }));

    const first = advanceSession(failed, now);
    expect(first.current).toBe("a");
    const second = advanceSession(first.pending, now);
    expect(second.current).toBe("b");
    const third = advanceSession(second.pending, now);
    expect(third.current).toBe("c");
    expect(advanceSession(third.pending, now).done).toBe(true);
  });
});

describe("les quatre paliers d'une carte neuve", () => {
  const delays = (rating: ReviewRating) => {
    const outcome = schedule(newCardSnapshot(), rating, { now, config: DETERMINISTIC_CONFIG });
    return { outcome, minutes: (outcome.dueDate.getTime() - now.getTime()) / 60_000 };
  };

  it("« À revoir » revient à une minute et reste en apprentissage", () => {
    const { outcome, minutes } = delays(ReviewRating.again);
    expect(minutes).toBe(1);
    expect(outcome.state).toBe("learning");
  });

  it("« Difficile » revient à 5,5 minutes, moyenne des deux paliers", () => {
    const { outcome, minutes } = delays(ReviewRating.hard);
    expect(minutes).toBe(5.5);
    expect(outcome.state).toBe("learning");
  });

  it("« Correct » avance à dix minutes, encore en apprentissage", () => {
    const { outcome, minutes } = delays(ReviewRating.good);
    expect(minutes).toBe(10);
    expect(outcome.state).toBe("learning");
    expect(outcome.stepIndex).toBe(1);
  });

  it("« Facile » sort à quatre jours", () => {
    const { outcome } = delays(ReviewRating.easy);
    expect(outcome.state).toBe("review");
    expect(outcome.intervalDays).toBe(4);
  });

  it("les quatre boutons annoncent quatre délais différents", () => {
    const minutes = [
      ReviewRating.again,
      ReviewRating.hard,
      ReviewRating.good,
      ReviewRating.easy,
    ].map((rating) => delays(rating).minutes);

    expect(minutes).toEqual([1, 5.5, 10, 4 * 1_440]);
    expect(new Set(minutes).size).toBe(4);
  });
});

describe("une carte ratée revient dans la session", () => {
  it("est reservie immédiatement quand elle est seule", () => {
    const outcome = schedule(newCardSnapshot(), ReviewRating.again, {
      now,
      config: DETERMINISTIC_CONFIG,
    });

    expect(returnsInSession(outcome.dueDate, now)).toBe(true);

    const afterPack = advanceSession([{ card: "ratée", availableAt: outcome.dueDate }], now);
    expect(afterPack.current).toBe("ratée");
    expect(afterPack.done).toBe(false);
  });
});

describe("enqueueInitial", () => {
  it("rend toutes les cartes du paquet immédiatement disponibles, dans l'ordre", () => {
    const pending = enqueueInitial(["a", "b", "c"], now);
    const first = advanceSession(pending, now);
    expect(first.current).toBe("a");

    const second = advanceSession(first.pending, now);
    expect(second.current).toBe("b");
  });
});
