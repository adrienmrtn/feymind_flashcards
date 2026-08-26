/**
 * Finir une session = finir les cartes dues aujourd'hui, y compris celles qui
 * reviennent dans dix minutes. Ce n'est pas « parcourir le paquet une fois ».
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
  it("garde une carte à dix minutes, comme le palier « Correct » d'une neuve", () => {
    const due = new Date(now.getTime() + 10 * 60 * 1000);
    expect(returnsInSession(due, now)).toBe(true);
  });

  it("garde une carte à une minute", () => {
    const due = new Date(now.getTime() + 60 * 1000);
    expect(returnsInSession(due, now)).toBe(true);
  });

  it("laisse sortir une carte au-delà de la fenêtre d'anticipation", () => {
    const due = new Date(now.getTime() + (LEARN_AHEAD_SECONDS + 1) * 1000);
    expect(returnsInSession(due, now)).toBe(false);
  });

  it("garde une carte déjà due", () => {
    const due = new Date(now.getTime() - 1000);
    expect(returnsInSession(due, now)).toBe(true);
  });
});

describe("advanceSession", () => {
  it("n'est pas finie tant qu'une carte d'apprentissage attend", () => {
    const pending = [{ card: "dix minutes", availableAt: new Date(now.getTime() + 10 * 60 * 1000) }];

    const waiting = advanceSession(pending, now);
    expect(waiting.done).toBe(false);
    expect(waiting.current).toBeNull();
    expect(waiting.nextAvailableAt?.getTime()).toBe(pending[0]!.availableAt.getTime());

    const tooSoon = advanceSession(pending, new Date(now.getTime() + 9 * 60 * 1000 + 59 * 1000));
    expect(tooSoon.current).toBeNull();
    expect(tooSoon.done).toBe(false);

    const ready = advanceSession(pending, new Date(now.getTime() + 10 * 60 * 1000));
    expect(ready.current).toBe("dix minutes");
    expect(ready.pending).toEqual([]);
    expect(ready.done).toBe(false);
  });

  it("n'est finie que lorsque la file est vide", () => {
    expect(advanceSession([], now).done).toBe(true);
  });

  it("sert d'abord une carte déjà due, même si une autre revient plus tôt dans l'absolu", () => {
    const laterReady = { card: "plus tard", availableAt: new Date(now.getTime() - 1000) };
    const waiting = { card: "dans 10 min", availableAt: new Date(now.getTime() + 10 * 60 * 1000) };

    const pulled = advanceSession([waiting, laterReady], now);
    expect(pulled.current).toBe("plus tard");
    expect(pulled.pending).toEqual([waiting]);
  });
});

describe("le palier Correct d'une carte neuve", () => {
  it("revient à dix minutes et reste dans la session", () => {
    const outcome = schedule(newCardSnapshot(), ReviewRating.good, {
      now,
      config: DETERMINISTIC_CONFIG,
    });

    expect(outcome.state).toBe("learning");
    expect(outcome.dueDate.getTime() - now.getTime()).toBe(10 * 60 * 1000);
    expect(returnsInSession(outcome.dueDate, now)).toBe(true);

    const pending = [{ card: "neuve", availableAt: outcome.dueDate }];
    const afterPack = advanceSession(pending, now);
    expect(afterPack.done).toBe(false);
    expect(afterPack.current).toBeNull();
  });
});

describe("enqueueInitial", () => {
  it("rend toutes les cartes du paquet immédiatement disponibles", () => {
    const pending = enqueueInitial(["a", "b", "c"], now);
    const first = advanceSession(pending, now);
    expect(first.current).toBe("a");

    const second = advanceSession(first.pending, now);
    expect(second.current).toBe("b");
  });
});
