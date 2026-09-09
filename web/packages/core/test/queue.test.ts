/**
 * L'ordre d'une session.
 *
 * Il n'y a plus de plafond : ce qui est dû est servi en entier, et l'ordre est tout ce qui
 * reste pour que la file soit utile. Les cartes d'un examen déclaré passent devant les autres
 * neuves, et une révision dont l'échéance d'examen est la plus proche passe devant.
 */

import { describe, expect, it } from "vitest";

import { buildQueue, isDue, studyCounts } from "../src/srs/queue";
import type { QueueCard } from "../src/srs/queue";
import { addDays, startOfDay } from "../src/srs/exam";
import type { CardState } from "../src/srs/types";

const now = new Date(2026, 8, 1, 14, 30);

function card(id: string, state: CardState, overrides: Partial<QueueCard> = {}): QueueCard {
  return {
    id,
    state,
    dueDate: addDays(now, -1),
    position: 0,
    createdAt: new Date(2026, 0, 1),
    isSuspended: false,
    ...overrides,
  };
}

describe("échéance", () => {
  it("une carte mise de côté n'est jamais due", () => {
    expect(isDue(card("a", "review", { isSuspended: true }), now)).toBe(false);
  });

  it("une carte à venir n'est pas due", () => {
    expect(isDue(card("a", "review", { dueDate: addDays(now, 1) }), now)).toBe(false);
  });

  it("une carte due à la seconde près est due", () => {
    expect(isDue(card("a", "review", { dueDate: now }), now)).toBe(true);
  });
});

describe("l'ordre", () => {
  it("sert l'apprentissage, puis les révisions, puis les cartes neuves", () => {
    const queue = buildQueue(
      [
        card("neuve", "new"),
        card("revision", "review"),
        card("apprentissage", "learning"),
        card("reapprentissage", "relearning", { dueDate: addDays(now, -2) }),
      ],
      { now },
    );

    expect(queue.map((item) => item.id)).toEqual([
      "reapprentissage",
      "apprentissage",
      "revision",
      "neuve",
    ]);
  });

  it("classe les cartes neuves par position puis par date de création", () => {
    const queue = buildQueue(
      [
        card("troisieme", "new", { position: 2 }),
        card("premiere", "new", { position: 0 }),
        card("deuxieme", "new", { position: 1 }),
      ],
      { now },
    );

    expect(queue.map((item) => item.id)).toEqual(["premiere", "deuxieme", "troisieme"]);
  });

  it("laisse dehors les cartes qui ne sont pas dues", () => {
    const queue = buildQueue(
      [card("due", "review"), card("plus tard", "review", { dueDate: addDays(now, 3) })],
      { now },
    );

    expect(queue.map((item) => item.id)).toEqual(["due"]);
  });
});

describe("ce qui est dû est servi", () => {
  it("ne retient plus aucune carte neuve", () => {
    const cards = Array.from({ length: 30 }, (_, index) =>
      card(`n${index}`, "new", { position: index }),
    );

    expect(buildQueue(cards, { now })).toHaveLength(30);
  });

  it("ne rationne pas non plus les révisions", () => {
    const cards = Array.from({ length: 300 }, (_, index) => card(`r${index}`, "review"));

    expect(buildQueue(cards, { now })).toHaveLength(300);
  });
});

describe("l'examen dans la file", () => {
  const examDay = startOfDay(addDays(now, 5));

  it("sert d'abord les cartes neuves sous échéance, puis les autres", () => {
    const cards = Array.from({ length: 30 }, (_, index) =>
      card(`n${index}`, "new", { position: index }),
    );
    // Les vingt dernières sont couvertes par un examen : elles doivent remonter.
    const deadlines = new Map(cards.slice(10).map((item) => [item.id, examDay]));

    const queue = buildQueue(cards, { now, deadlines });

    expect(queue).toHaveLength(30);
    expect(queue.slice(0, 20).every((item) => deadlines.has(item.id))).toBe(true);
    expect(queue.map((item) => item.id)).toEqual([
      ...cards.slice(10).map((item) => item.id),
      ...cards.slice(0, 10).map((item) => item.id),
    ]);
  });

  it("fait passer l'échéance la plus proche devant, en révision", () => {
    const soon = card("bientot", "review");
    const later = card("plus-tard", "review");
    const none = card("sans", "review");

    const deadlines = new Map([
      [soon.id, startOfDay(addDays(now, 2))],
      [later.id, startOfDay(addDays(now, 9))],
    ]);

    const queue = buildQueue([none, later, soon], { now, deadlines });

    expect(queue.map((item) => item.id)).toEqual(["bientot", "plus-tard", "sans"]);
  });
});

describe("la répartition", () => {
  it("compte ce que la session va servir", () => {
    const counts = studyCounts(
      [
        card("a", "new"),
        card("b", "new"),
        card("c", "review"),
        card("d", "learning"),
        card("e", "relearning"),
        card("f", "review", { dueDate: addDays(now, 4) }),
      ],
      { now },
    );

    expect(counts).toEqual({ newCards: 2, learning: 2, review: 1, total: 5 });
  });
});
