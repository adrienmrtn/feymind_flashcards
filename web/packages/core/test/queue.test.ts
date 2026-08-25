/**
 * L'ordre d'une session.
 *
 * Le cas qui compte est l'exception d'examen : une carte neuve sous échéance passe **outre** le
 * plafond du rythme quotidien. Sans elle, le plan annoncé à la confirmation serait un
 * mensonge — il promet quarante cartes aujourd'hui, et le rythme n'en laisserait passer que
 * huit.
 */

import { describe, expect, it } from "vitest";

import { DEFAULT_LIMITS, buildQueue, dailyLimits, isDue, studyCounts } from "../src/srs/queue";
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

describe("les plafonds", () => {
  it("borne les cartes neuves au rythme quotidien", () => {
    const cards = Array.from({ length: 30 }, (_, index) =>
      card(`n${index}`, "new", { position: index }),
    );

    // 15 minutes par jour valent huit cartes neuves.
    const queue = buildQueue(cards, { now, limits: dailyLimits(15) });

    expect(queue).toHaveLength(8);
  });

  it("ne rationne pas les révisions dues en mode quotidien", () => {
    const cards = Array.from({ length: 300 }, (_, index) => card(`r${index}`, "review"));

    const queue = buildQueue(cards, { now, limits: dailyLimits(15) });

    expect(queue).toHaveLength(300);
  });

  it("borne les révisions au défaut hors mode quotidien", () => {
    const cards = Array.from({ length: 300 }, (_, index) => card(`r${index}`, "review"));

    const queue = buildQueue(cards, { now, limits: DEFAULT_LIMITS });

    expect(queue).toHaveLength(DEFAULT_LIMITS.reviewsPerSession);
  });
});

describe("l'exception d'examen", () => {
  const examDay = startOfDay(addDays(now, 5));

  it("fait passer les cartes neuves sous échéance outre le plafond", () => {
    const cards = Array.from({ length: 30 }, (_, index) =>
      card(`n${index}`, "new", { position: index }),
    );
    // Les vingt premières sont couvertes par un examen.
    const deadlines = new Map(cards.slice(0, 20).map((item) => [item.id, examDay]));

    const queue = buildQueue(cards, { now, limits: dailyLimits(15), deadlines });

    // Les vingt de l'examen, plus les huit du rythme quotidien parmi les dix restantes.
    expect(queue).toHaveLength(28);
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
