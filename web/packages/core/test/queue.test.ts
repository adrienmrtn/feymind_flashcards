/**
 * L'ordre d'une session.
 *
 * Les cartes d'examen passent **devant** les autres neuves, mais elles restent dans le
 * plafond du jour. Une session depuis un cours et la session globale partagent ce budget :
 * les faits `state_before === "new"` d'aujourd'hui en déduisent le reste.
 */

import { describe, expect, it } from "vitest";

import {
  DEFAULT_LIMITS,
  buildQueue,
  countNewIntroducedToday,
  dailyLimits,
  isDue,
  remainingNewCards,
  sessionNewLimit,
  sessionNewSliderMax,
  studyCounts,
} from "../src/srs/queue";
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

describe("le budget du jour", () => {
  it("compte les introductions d'aujourd'hui, pas celles de la veille", () => {
    const count = countNewIntroducedToday(
      [
        { stateBefore: "new", reviewedAt: now },
        { stateBefore: "new", reviewedAt: addDays(now, -1) },
        { stateBefore: "review", reviewedAt: now },
      ],
      now,
    );

    expect(count).toBe(1);
  });

  it("retire du rythme ce qui a déjà été introduit", () => {
    // 15 minutes → 8 neuves. Huit déjà vues depuis un cours : plus rien à servir.
    expect(remainingNewCards(8, 15)).toBe(0);
    expect(remainingNewCards(3, 15)).toBe(5);
  });

  it("laisse le curseur outrepasser le reste du jour", () => {
    expect(sessionNewLimit({ dailyMinutes: 15, introducedToday: 8 })).toBe(0);
    expect(sessionNewLimit({ dailyMinutes: 15, introducedToday: 8, override: 5 })).toBe(5);
  });

  it("sert le reste, pas un second plafond, quand on reconstruit la file", () => {
    const cards = Array.from({ length: 20 }, (_, index) =>
      card(`n${index}`, "new", { position: index }),
    );

    const leftover = buildQueue(cards, {
      now,
      limits: { newPerSession: remainingNewCards(8, 15), reviewsPerSession: Number.MAX_SAFE_INTEGER },
    });

    expect(leftover).toHaveLength(0);
  });

  it("borne le curseur au-dessus du rythme, sans monter dans les centaines", () => {
    expect(sessionNewSliderMax(8)).toBe(20);
    expect(sessionNewSliderMax(30)).toBe(60);
  });
});

describe("l'examen dans la file", () => {
  const examDay = startOfDay(addDays(now, 5));

  it("sert d'abord les cartes neuves sous échéance, sans casser le plafond", () => {
    const cards = Array.from({ length: 30 }, (_, index) =>
      card(`n${index}`, "new", { position: index }),
    );
    // Les vingt premières sont couvertes par un examen.
    const deadlines = new Map(cards.slice(0, 20).map((item) => [item.id, examDay]));

    const queue = buildQueue(cards, { now, limits: dailyLimits(15), deadlines });

    expect(queue).toHaveLength(8);
    expect(queue.every((item) => deadlines.has(item.id))).toBe(true);
    expect(queue.map((item) => item.id)).toEqual(
      cards.slice(0, 8).map((item) => item.id),
    );
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
