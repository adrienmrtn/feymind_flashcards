import { describe, expect, it } from "vitest";

import {
  DEFAULT_THROUGHPUT,
  MIN_MOCK_QUESTIONS,
  MIN_PASSES_FOR_THROUGHPUT,
  addDays,
  adherenceFrom,
  adherenceLevel,
  cardsIn,
  drawMock,
  examReadiness,
  intensityFor,
  isMockBlock,
  isReviewBlock,
  minutesFor,
  mockMinutes,
  mockQuestionCount,
  mockScore,
  planMocks,
  planTerm,
  readinessGap,
  realisticCapacity,
  startOfDay,
  throughputFrom,
  uniformWeek,
  wantsMock,
  type Availability,
  type CardDifficulty,
  type DrawCandidate,
  type MockResult,
  type TermCard,
  type TermExam,
} from "../src/index";

const now = new Date("2026-09-09T09:00:00");
const today = startOfDay(now);

function card(id: string, courseId = "bio", over: Partial<TermCard> = {}): TermCard {
  return {
    id,
    courseId,
    kind: "basic",
    state: "new",
    intervalDays: 0,
    dueDate: today,
    isSuspended: false,
    ...over,
  };
}

function exam(id: string, days: number, over: Partial<TermExam> = {}): TermExam {
  return {
    id,
    name: id,
    examDate: addDays(today, days),
    intensity: "standard",
    courseIds: ["bio"],
    ...over,
  };
}

function open(minutes = 120): Availability {
  return { weekly: uniformWeek(minutes), exceptions: [] };
}

function result(over: Partial<MockResult> = {}): MockResult {
  return {
    id: "m1",
    examId: "bio",
    questionCount: 20,
    correctCount: 12,
    finishedAt: today,
    ...over,
  };
}

describe("l'examen blanc", () => {
  it("ne concerne que les épreuves où il a un sens", () => {
    expect(wantsMock("final")).toBe(true);
    expect(wantsMock("midterm")).toBe(true);
    expect(wantsMock("mock")).toBe(true);
    expect(wantsMock("quiz")).toBe(true);
    // On ne s'entraîne pas à un oral avec des cartes.
    expect(wantsMock("oral")).toBe(false);
    expect(wantsMock("exam")).toBe(false);
  });

  it("ne se pose pas sur un programme trop maigre pour être échantillonné", () => {
    expect(mockQuestionCount(5)).toBe(0);
    expect(mockQuestionCount(MIN_MOCK_QUESTIONS)).toBe(MIN_MOCK_QUESTIONS);
  });

  it("ne prend jamais plus du quart du programme", () => {
    expect(mockQuestionCount(40)).toBeLessThanOrEqual(10);
    expect(mockQuestionCount(400)).toBeLessThanOrEqual(20);
  });

  it("accorde un temps imparti proportionnel au nombre de questions", () => {
    expect(mockMinutes(20)).toBe(15);
    expect(mockMinutes(8)).toBeGreaterThanOrEqual(5);
  });

  it("pose deux blancs, à J-7 et J-2", () => {
    const mocks = planMocks({
      exams: [
        { id: "bio", name: "Bio", examDate: addDays(today, 20), kind: "final", cardCount: 80 },
      ],
      done: [],
      capacities: new Array(21).fill(120),
      now,
    });
    expect(mocks.map((mock) => mock.offset)).toEqual([13, 18]);
  });

  it("décale un blanc tombé sur un jour fermé, vers l'avant", () => {
    const capacities = new Array(21).fill(120);
    capacities[13] = 0;
    const mocks = planMocks({
      exams: [
        { id: "bio", name: "Bio", examDate: addDays(today, 20), kind: "final", cardCount: 80 },
      ],
      done: [],
      capacities,
      now,
    });
    expect(mocks[0]!.offset).toBe(12);
  });

  it("ne repose pas un blanc déjà passé", () => {
    const mocks = planMocks({
      exams: [
        { id: "bio", name: "Bio", examDate: addDays(today, 20), kind: "final", cardCount: 80 },
      ],
      done: [result({ examId: "bio" })],
      capacities: new Array(21).fill(120),
      now,
    });
    expect(mocks).toHaveLength(1);
    expect(mocks[0]!.offset).toBe(18);
  });

  it("saute le palier dont le jour est déjà passé", () => {
    const mocks = planMocks({
      exams: [
        { id: "bio", name: "Bio", examDate: addDays(today, 3), kind: "final", cardCount: 80 },
      ],
      done: [],
      capacities: new Array(4).fill(120),
      now,
    });
    // J-7 est derrière nous ; seul J-2 reste posable.
    expect(mocks).toHaveLength(1);
    expect(mocks[0]!.offset).toBe(1);
  });

  it("ne pose jamais deux blancs le même jour", () => {
    const mocks = planMocks({
      exams: [
        { id: "a", name: "A", examDate: addDays(today, 10), kind: "final", cardCount: 80 },
        { id: "b", name: "B", examDate: addDays(today, 10), kind: "final", cardCount: 80 },
      ],
      done: [],
      capacities: new Array(11).fill(120),
      now,
    });
    expect(new Set(mocks.map((mock) => mock.offset)).size).toBe(mocks.length);
  });
});

describe("le tirage", () => {
  const cards: DrawCandidate[] = Array.from({ length: 50 }, (_, index) => ({
    id: `c${index}`,
    courseId: index < 40 ? "bio" : "droit",
    kind: "basic",
    isSuspended: false,
  }));

  it("tire dans le programme et rien d'autre", () => {
    const drawn = drawMock(cards, ["bio"], 10, "graine");
    expect(drawn).toHaveLength(10);
    for (const id of drawn) {
      expect(Number(id.slice(1))).toBeLessThan(40);
    }
  });

  it("rend le même tirage pour la même graine", () => {
    expect(drawMock(cards, ["bio"], 10, "g")).toEqual(drawMock(cards, ["bio"], 10, "g"));
    expect(drawMock(cards, ["bio"], 10, "g")).not.toEqual(drawMock(cards, ["bio"], 10, "h"));
  });

  it("écarte les cartes suspendues et se limite au disponible", () => {
    const few: DrawCandidate[] = [
      { id: "a", courseId: "bio", kind: "basic", isSuspended: false },
      { id: "b", courseId: "bio", kind: "basic", isSuspended: true },
    ];
    expect(drawMock(few, ["bio"], 10, "g")).toEqual(["a"]);
    expect(drawMock(few, ["autre"], 10, "g")).toEqual([]);
  });
});

describe("ce que le score change", () => {
  it("projette tant qu'aucun blanc n'a été passé", () => {
    const readiness = examReadiness({
      masteryPercent: 60,
      projectedPercent: 88,
      mocks: [],
      examId: "bio",
      now,
    });
    expect(readiness.measured).toBe(false);
    expect(readiness.percent).toBe(88);
    expect(readiness.mockScore).toBeNull();
  });

  it("fait pencher la préparation vers un blanc récent qui déçoit", () => {
    const readiness = examReadiness({
      masteryPercent: 80,
      projectedPercent: 88,
      mocks: [result({ questionCount: 20, correctCount: 10, finishedAt: today })],
      examId: "bio",
      now,
    });
    expect(readiness.measured).toBe(true);
    expect(readiness.mockScore).toBe(50);
    // La mesure l'emporte largement sur la formule.
    expect(readiness.percent).toBeLessThan(70);
  });

  it("laisse un vieux blanc s'effacer devant la projection", () => {
    const vieux = examReadiness({
      masteryPercent: 80,
      projectedPercent: 88,
      mocks: [result({ correctCount: 10, finishedAt: addDays(today, -40) })],
      examId: "bio",
      now,
    });
    const recent = examReadiness({
      masteryPercent: 80,
      projectedPercent: 88,
      mocks: [result({ correctCount: 10, finishedAt: today })],
      examId: "bio",
      now,
    });
    expect(vieux.percent).toBeGreaterThan(recent.percent);
  });

  it("ne regarde que les blancs de cette épreuve", () => {
    const readiness = examReadiness({
      masteryPercent: 80,
      projectedPercent: 88,
      mocks: [result({ examId: "droit", correctCount: 2 })],
      examId: "bio",
      now,
    });
    expect(readiness.measured).toBe(false);
  });

  it("chiffre l'écart entre ce qu'on croit savoir et ce qu'on sait", () => {
    expect(mockScore(result({ questionCount: 20, correctCount: 12 }))).toBe(60);
    expect(readinessGap(85, result({ questionCount: 20, correctCount: 12 }))).toBe(25);
  });
});

describe("le blanc dans le plan", () => {
  const cards = Array.from({ length: 60 }, (_, index) => card(`c${index}`));

  it("pose un bloc de blanc distinct des blocs de révision", () => {
    const plan = planTerm({
      exams: [exam("bio", 14, { kind: "final" })],
      cards,
      availability: open(90),
      now,
    });

    const mockBlocks = plan.days.flatMap((day) => day.blocks.filter(isMockBlock));
    expect(mockBlocks.length).toBeGreaterThan(0);
    expect(mockBlocks[0]!.questionCount).toBeGreaterThan(0);
    expect(mockBlocks[0]!.examName).toBe("bio");
    expect(plan.mocks.length).toBe(mockBlocks.length);
  });

  it("retire le temps du blanc du budget de révision du jour", () => {
    const plan = planTerm({
      exams: [exam("bio", 14, { kind: "final" })],
      cards,
      availability: open(90),
      now,
    });

    for (const day of plan.days) {
      expect(day.minutes).toBeLessThanOrEqual(day.capacityMinutes);
    }
  });

  it("met le blanc en tête du jour", () => {
    const plan = planTerm({
      exams: [exam("bio", 14, { kind: "final" })],
      cards,
      availability: open(90),
      now,
    });
    const withMock = plan.days.find((day) => day.blocks.some(isMockBlock));
    expect(withMock).toBeDefined();
    expect(isMockBlock(withMock!.blocks[0]!)).toBe(true);
  });

  it("ne pose aucun blanc pour une épreuve qui n'en demande pas", () => {
    const plan = planTerm({
      exams: [exam("bio", 14, { kind: "oral" })],
      cards,
      availability: open(90),
      now,
    });
    expect(plan.mocks).toEqual([]);
    expect(plan.days.flatMap((day) => day.blocks.filter(isMockBlock))).toEqual([]);
  });

  it("garde le comportement d'avant sans type d'épreuve", () => {
    const plan = planTerm({
      exams: [exam("bio", 14)],
      cards,
      availability: open(90),
      now,
    });
    expect(plan.mocks).toEqual([]);
    expect(plan.days.flatMap((day) => day.blocks.filter(isReviewBlock)).length).toBeGreaterThan(0);
  });
});

describe("ce qui résiste revient plus souvent", () => {
  const cards = Array.from({ length: 20 }, (_, index) => card(`c${index}`));

  function difficulty(cardId: string, again: number): CardDifficulty {
    return {
      cardId,
      reviews: 6,
      againCount: again,
      hardCount: 0,
      lastRating: 1,
      lastReviewedAt: today,
    };
  }

  it("accorde des passages de plus aux cartes fragiles", () => {
    const plain = planTerm({
      exams: [exam("bio", 20)],
      cards,
      availability: open(120),
      now,
    });
    const withWeak = planTerm({
      exams: [exam("bio", 20)],
      cards,
      availability: open(120),
      now,
      difficulties: new Map([
        ["c0", difficulty("c0", 5)],
        ["c1", difficulty("c1", 5)],
      ]),
    });

    expect(withWeak.totalPasses).toBeGreaterThan(plain.totalPasses);

    const passesOf = (plan: typeof plain, id: string) =>
      plan.days.reduce(
        (sum, day) =>
          sum +
          day.blocks
            .filter(isReviewBlock)
            .reduce((inner, block) => inner + block.cardIds.filter((c) => c === id).length, 0),
        0,
      );

    expect(passesOf(withWeak, "c0")).toBeGreaterThan(passesOf(plain, "c0"));
    // Une carte saine n'y gagne rien : le rattrapage vise ce qui résiste.
    expect(passesOf(withWeak, "c9")).toBe(passesOf(plain, "c9"));
  });

  it("ne voit toujours pas une carte deux fois le même jour", () => {
    const plan = planTerm({
      exams: [exam("bio", 20)],
      cards,
      availability: open(120),
      now,
      difficulties: new Map(cards.map((c) => [c.id, difficulty(c.id, 5)])),
    });

    for (const day of plan.days) {
      const ids = day.blocks.filter(isReviewBlock).flatMap((block) => block.cardIds);
      expect(new Set(ids).size).toBe(ids.length);
    }
  });
});

describe("le point de départ", () => {
  it("décale l'intensité d'un cran, sans sortir de l'échelle", () => {
    expect(intensityFor("standard", "cold")).toBe("intense");
    expect(intensityFor("standard", "seen")).toBe("standard");
    expect(intensityFor("standard", "solid")).toBe("light");
    // Les bouts de l'échelle tiennent.
    expect(intensityFor("intense", "cold")).toBe("intense");
    expect(intensityFor("light", "solid")).toBe("light");
    expect(intensityFor("standard", undefined)).toBe("standard");
  });

  it("fait travailler plus quelqu'un qui découvre le programme", () => {
    const cards = Array.from({ length: 30 }, (_, index) => card(`c${index}`));
    const froid = planTerm({
      exams: [exam("bio", 20, { startingPoint: "cold" })],
      cards,
      availability: open(120),
      now,
    });
    const revision = planTerm({
      exams: [exam("bio", 20, { startingPoint: "solid" })],
      cards,
      availability: open(120),
      now,
    });
    expect(froid.totalPasses).toBeGreaterThan(revision.totalPasses);
  });

  it("garde le plan d'avant sans réponse", () => {
    const cards = Array.from({ length: 30 }, (_, index) => card(`c${index}`));
    const sansReponse = planTerm({
      exams: [exam("bio", 20)],
      cards,
      availability: open(120),
      now,
    });
    const dejaVu = planTerm({
      exams: [exam("bio", 20, { startingPoint: "seen" })],
      cards,
      availability: open(120),
      now,
    });
    expect(sansReponse.totalPasses).toBe(dejaVu.totalPasses);
  });
});

describe("le débit mesuré", () => {
  it("garde la constante tant qu'on n'a pas assez de passages", () => {
    expect(throughputFrom(null)).toEqual(DEFAULT_THROUGHPUT);
    expect(throughputFrom({ cards: 10, cardsPerMinute: 2 })).toEqual(DEFAULT_THROUGHPUT);
    expect(throughputFrom({ cards: 200, cardsPerMinute: null })).toEqual(DEFAULT_THROUGHPUT);
  });

  it("retient le débit de l'étudiant dès qu'il est mesuré", () => {
    const slow = throughputFrom({ cards: MIN_PASSES_FOR_THROUGHPUT, cardsPerMinute: 2.5 });
    expect(slow.measured).toBe(true);
    expect(slow.cardsPerMinute).toBe(2.5);
    expect(slow.driftPercent).toBe(-37);
  });

  it("borne les valeurs aberrantes", () => {
    expect(throughputFrom({ cards: 200, cardsPerMinute: 0.1 }).cardsPerMinute).toBe(1);
    expect(throughputFrom({ cards: 200, cardsPerMinute: 90 }).cardsPerMinute).toBe(12);
  });

  it("change ce qui tient dans une soirée", () => {
    const slow = throughputFrom({ cards: 100, cardsPerMinute: 2 });
    expect(cardsIn(60, DEFAULT_THROUGHPUT)).toBe(240);
    expect(cardsIn(60, slow)).toBe(120);
    expect(minutesFor(120, slow)).toBe(60);
  });

  it("fait payer au plan le débit réel", () => {
    const cards = Array.from({ length: 200 }, (_, index) => card(`c${index}`));
    const fast = planTerm({ exams: [exam("bio", 8)], cards, availability: open(25), now });
    const slow = planTerm({
      exams: [exam("bio", 8)],
      cards,
      availability: open(25),
      now,
      throughput: throughputFrom({ cards: 100, cardsPerMinute: 2 }),
    });
    expect(slow.totalPasses).toBeLessThan(fast.totalPasses);
    expect(slow.overflow.length).toBeGreaterThan(fast.overflow.length);
    expect(slow.throughput.measured).toBe(true);
  });
});

describe("l'observance", () => {
  const capacity = () => 60;

  function daysDone(perDay: number, count: number) {
    return Array.from({ length: count }, (_, index) => {
      const day = new Date(today.getTime());
      day.setDate(day.getDate() - (index + 1));
      return { day, passes: perDay, againCount: 0 };
    });
  }

  it("ne conclut rien quand trop peu de jours sont ouverts", () => {
    // Deux jours ouverts sur la fenêtre : pas de quoi juger une observance.
    let opened = 0;
    const rare = () => (opened++ < 2 ? 60 : 0);
    const adherence = adherenceFrom(daysDone(240, 21), rare, DEFAULT_THROUGHPUT, now);
    expect(adherence.measured).toBe(false);
    expect(adherence.ratio).toBe(1);
  });

  it("mesure la part du temps déclaré réellement utilisée", () => {
    // 240 cartes rentrent dans 60 min ; en faire 120 est la moitié.
    const adherence = adherenceFrom(daysDone(120, 21), capacity, DEFAULT_THROUGHPUT, now);
    expect(adherence.measured).toBe(true);
    expect(adherence.ratio).toBeCloseTo(0.5, 1);
    expect(adherence.missedDays).toBe(0);
  });

  it("ne compte pas les jours fermés comme des jours manqués", () => {
    const closed = () => 0;
    const adherence = adherenceFrom([], closed, DEFAULT_THROUGHPUT, now);
    expect(adherence.observedDays).toBe(0);
    expect(adherence.measured).toBe(false);
  });

  it("ne compte pas le jour en cours", () => {
    const adherence = adherenceFrom(
      [{ day: today, passes: 0, againCount: 0 }, ...daysDone(240, 21)],
      capacity,
      DEFAULT_THROUGHPUT,
      now,
    );
    expect(adherence.ratio).toBe(1);
  });

  it("rabat la capacité sans jamais l'effondrer ni la gonfler", () => {
    const half = adherenceFrom(daysDone(120, 21), capacity, DEFAULT_THROUGHPUT, now);
    expect(realisticCapacity(60, half)).toBe(30);

    const none = adherenceFrom(daysDone(0, 21), capacity, DEFAULT_THROUGHPUT, now);
    // Une mauvaise passe resserre le plan, elle ne le supprime pas.
    expect(realisticCapacity(60, none)).toBe(30);

    const over = adherenceFrom(daysDone(600, 21), capacity, DEFAULT_THROUGHPUT, now);
    expect(realisticCapacity(60, over)).toBe(60);
  });

  it("nomme le niveau sans juger", () => {
    expect(adherenceLevel(adherenceFrom(daysDone(240, 21), capacity, DEFAULT_THROUGHPUT, now)))
      .toBe("steady");
    expect(adherenceLevel(adherenceFrom(daysDone(150, 21), capacity, DEFAULT_THROUGHPUT, now)))
      .toBe("slipping");
    expect(adherenceLevel(adherenceFrom(daysDone(30, 21), capacity, DEFAULT_THROUGHPUT, now)))
      .toBe("behind");
  });

  it("fait apparaître le déficit plus tôt quand l'étudiant décroche", () => {
    const cards = Array.from({ length: 300 }, (_, index) => card(`c${index}`));
    const trusting = planTerm({ exams: [exam("bio", 8)], cards, availability: open(40), now });
    const realistic = planTerm({
      exams: [exam("bio", 8)],
      cards,
      availability: open(40),
      now,
      adherence: adherenceFrom(daysDone(120, 21), capacity, DEFAULT_THROUGHPUT, now),
    });
    expect(realistic.overflow.length).toBeGreaterThan(trusting.overflow.length);
  });
});
