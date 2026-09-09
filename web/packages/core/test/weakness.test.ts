import { describe, expect, it } from "vitest";

import {
  MIN_REVIEWS_FOR_WEAKNESS,
  cardReadiness,
  currentStreak,
  extraPassesFor,
  isStubborn,
  isWeak,
  longestStreak,
  masteryByCourse,
  masteryForCourses,
  masteryOf,
  studyStats,
  weakCards,
  weakFirst,
  weakness,
  type CardDifficulty,
  type MasteryCard,
  type WeakCandidate,
} from "../src/index";

function difficulty(over: Partial<CardDifficulty> & { cardId: string }): CardDifficulty {
  return {
    reviews: 0,
    againCount: 0,
    hardCount: 0,
    lastRating: null,
    lastReviewedAt: null,
    ...over,
  };
}

function candidate(id: string, over: Partial<WeakCandidate> = {}): WeakCandidate {
  return {
    id,
    courseId: "bio",
    front: `Question ${id}`,
    kind: "basic",
    state: "review",
    intervalDays: 30,
    lapses: 0,
    isSuspended: false,
    ...over,
  };
}

function masteryCard(id: string, over: Partial<MasteryCard> = {}): MasteryCard {
  return {
    id,
    courseId: "bio",
    state: "new",
    intervalDays: 0,
    isSuspended: false,
    ...over,
  };
}

describe("fragilité", () => {
  it("ne juge pas sur deux réponses", () => {
    expect(isWeak(difficulty({ cardId: "a", reviews: 2, againCount: 2 }))).toBe(false);
    expect(MIN_REVIEWS_FOR_WEAKNESS).toBe(3);
  });

  it("classe une carte souvent ratée devant une carte rarement ratée", () => {
    const often = difficulty({ cardId: "a", reviews: 6, againCount: 4 });
    const rarely = difficulty({ cardId: "b", reviews: 20, againCount: 2 });
    expect(weakness(often)).toBeGreaterThan(weakness(rarely));
    expect(isWeak(often)).toBe(true);
    expect(isWeak(rarely)).toBe(false);
  });

  it("ne laisse pas un seul raté sur un seul passage passer devant huit ratés sur vingt", () => {
    const lucky = difficulty({ cardId: "a", reviews: 1, againCount: 1 });
    const real = difficulty({ cardId: "b", reviews: 20, againCount: 8 });
    expect(weakness(real)).toBeGreaterThan(weakness(lucky));
  });

  it("compte un « difficile » pour un demi-raté", () => {
    const hard = difficulty({ cardId: "a", reviews: 8, hardCount: 4 });
    const clean = difficulty({ cardId: "b", reviews: 8 });
    expect(weakness(hard)).toBeGreaterThan(weakness(clean));
  });

  it("signale une carte qui résiste à la répétition", () => {
    expect(isStubborn(6, undefined)).toBe(true);
    expect(isStubborn(0, difficulty({ cardId: "a", reviews: 8, againCount: 5 }))).toBe(true);
    expect(isStubborn(0, difficulty({ cardId: "a", reviews: 8, againCount: 1 }))).toBe(false);
  });

  it("accorde au plus deux passages de plus à une carte fragile", () => {
    expect(extraPassesFor(undefined)).toBe(0);
    expect(extraPassesFor(difficulty({ cardId: "a", reviews: 12 }))).toBe(0);
    expect(extraPassesFor(difficulty({ cardId: "a", reviews: 6, againCount: 5 }))).toBe(2);
    expect(extraPassesFor(difficulty({ cardId: "a", reviews: 6, againCount: 3 }))).toBe(1);
    // Deux ratés sur six, c'est deux tiers de réussite : ce n'est pas une carte fragile.
    expect(extraPassesFor(difficulty({ cardId: "a", reviews: 6, againCount: 2 }))).toBe(0);
  });
});

describe("points faibles", () => {
  const difficulties = new Map<string, CardDifficulty>([
    ["a", difficulty({ cardId: "a", reviews: 8, againCount: 6 })],
    ["b", difficulty({ cardId: "b", reviews: 8, againCount: 4 })],
    ["c", difficulty({ cardId: "c", reviews: 20, againCount: 1 })],
  ]);

  it("rend les cartes qui résistent, de la pire à la moins pire", () => {
    const weak = weakCards(
      [candidate("a"), candidate("b"), candidate("c")],
      difficulties,
    );
    expect(weak.map((card) => card.id)).toEqual(["a", "b"]);
    expect(weak[0]!.weakness).toBeGreaterThan(weak[1]!.weakness);
  });

  it("écarte les cartes suspendues et se restreint au programme", () => {
    expect(weakCards([candidate("a", { isSuspended: true })], difficulties)).toEqual([]);
    expect(
      weakCards([candidate("a", { courseId: "droit" })], difficulties, {
        courseIds: ["bio"],
      }),
    ).toEqual([]);
  });

  it("fait passer les points faibles devant, sans changer la file", () => {
    const order = weakFirst(["c", "b", "a"], difficulties);
    expect(order).toEqual(["a", "b", "c"]);
    // Rien n'est ajouté ni retiré : le tri ne décide pas de ce qui est dû.
    expect(order).toHaveLength(3);
  });

  it("garde l'ordre reçu entre deux cartes également saines", () => {
    expect(weakFirst(["x", "y", "z"], new Map())).toEqual(["x", "y", "z"]);
  });

  it("corrige la solidité d'une carte « acquise » qui se rate", () => {
    const solid = cardReadiness({ state: "review", intervalDays: 40 }, undefined);
    const shaky = cardReadiness(
      { state: "review", intervalDays: 40 },
      difficulty({ cardId: "a", reviews: 8, againCount: 6 }),
    );
    expect(solid).toBeGreaterThan(0.9);
    expect(shaky).toBeLessThan(0.6);
    expect(cardReadiness({ state: "new", intervalDays: 0 }, undefined)).toBe(0);
  });
});

describe("maîtrise", () => {
  it("part de zéro et monte vers cent", () => {
    const untouched = masteryOf([masteryCard("a"), masteryCard("b")], new Map());
    expect(untouched.percent).toBe(0);
    expect(untouched.untouched).toBe(2);

    const learned = masteryOf(
      [
        masteryCard("a", { state: "review", intervalDays: 40 }),
        masteryCard("b", { state: "review", intervalDays: 40 }),
      ],
      new Map(),
    );
    expect(learned.percent).toBeGreaterThanOrEqual(95);
    expect(learned.solid).toBe(2);
  });

  it("compte une carte à mi-chemin pour une moitié", () => {
    const half = masteryOf(
      [
        masteryCard("a", { state: "review", intervalDays: 40 }),
        masteryCard("b"),
      ],
      new Map(),
    );
    expect(half.percent).toBeGreaterThan(30);
    expect(half.percent).toBeLessThan(60);
  });

  it("range une carte acquise mais ratée parmi les fragiles", () => {
    const mastery = masteryOf(
      [masteryCard("a", { state: "review", intervalDays: 40 })],
      new Map([["a", difficulty({ cardId: "a", reviews: 10, againCount: 8 })]]),
    );
    expect(mastery.fragile).toBe(1);
    expect(mastery.solid).toBe(0);
    expect(mastery.percent).toBeLessThan(60);
  });

  it("ignore les cartes suspendues", () => {
    const mastery = masteryOf([masteryCard("a", { isSuspended: true })], new Map());
    expect(mastery.cardCount).toBe(0);
    expect(mastery.percent).toBe(0);
  });

  it("se calcule par cours et par programme", () => {
    const cards = [
      masteryCard("a", { courseId: "bio", state: "review", intervalDays: 40 }),
      masteryCard("b", { courseId: "droit" }),
    ];
    const byCourse = masteryByCourse(cards, new Map());
    expect(byCourse.get("bio")!.percent).toBeGreaterThan(90);
    expect(byCourse.get("droit")!.percent).toBe(0);
    expect(masteryForCourses(cards, new Map(), ["bio"]).cardCount).toBe(1);
  });
});

describe("statistiques", () => {
  const day = (offset: number) => {
    const date = new Date("2026-09-09T12:00:00");
    date.setDate(date.getDate() + offset);
    return date;
  };
  const now = new Date("2026-09-09T20:00:00");

  it("mesure la justesse, pas seulement le volume", () => {
    const stats = studyStats(
      [
        { day: day(-2), passes: 40, againCount: 10 },
        { day: day(-1), passes: 60, againCount: 15 },
      ],
      now,
    );
    expect(stats.totalPasses).toBe(100);
    expect(stats.accuracyPercent).toBe(75);
    expect(stats.averagePasses).toBe(50);
    expect(stats.best?.passes).toBe(60);
  });

  it("tient la série tant qu'on a révisé aujourd'hui ou hier", () => {
    expect(currentStreak([day(0), day(-1), day(-2)], now)).toBe(3);
    expect(currentStreak([day(-1), day(-2)], now)).toBe(2);
    expect(currentStreak([day(-2), day(-3)], now)).toBe(0);
    expect(currentStreak([], now)).toBe(0);
  });

  it("retient la meilleure série de la période", () => {
    expect(longestStreak([day(-10), day(-9), day(-8), day(-5), day(-4)])).toBe(3);
    expect(longestStreak([day(-3)])).toBe(1);
  });

  it("rend zéro sans historique", () => {
    const stats = studyStats([], now);
    expect(stats.totalPasses).toBe(0);
    expect(stats.accuracyPercent).toBe(0);
    expect(stats.best).toBeNull();
  });
});
