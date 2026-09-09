import { describe, expect, it } from "vitest";

import {
  DEFAULT_THROUGHPUT,
  MIN_MOCK_QUESTIONS,
  MIN_PASSES_FOR_THROUGHPUT,
  addDays,
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
  mockSlotFor,
  planMocks,
  planTerm,
  readinessGap,
  startOfDay,
  throughputFrom,
  wantsMock,
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
  it("concerne toutes les épreuves écrites, y compris le type par défaut", () => {
    // `exam` est la valeur par défaut de la colonne : l'exclure revenait à ne livrer le blanc
    // à personne. Vingt épreuves sur vingt-deux en base sont de ce type.
    expect(wantsMock("exam")).toBe(true);
    expect(wantsMock("final")).toBe(true);
    expect(wantsMock("midterm")).toBe(true);
    expect(wantsMock("mock")).toBe(true);
    expect(wantsMock("quiz")).toBe(true);
    // On ne s'entraîne pas à un oral avec des cartes.
    expect(wantsMock("oral")).toBe(false);
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
      horizonDays: 21,
      now,
    });
    expect(mocks.map((mock) => mock.offset)).toEqual([13, 18]);
  });

  it("ne repose pas le blanc de J-7 quand il a été passé à J-7", () => {
    const mocks = planMocks({
      exams: [
        { id: "bio", name: "Bio", examDate: addDays(today, 20), kind: "final", cardCount: 80 },
      ],
      // Passé il y a un instant, mais l'épreuve est dans vingt jours : ce blanc-là n'honore
      // aucun rendez-vous. On le repasse donc à J-7, puis à J-2.
      done: [result({ examId: "bio", finishedAt: today })],
      horizonDays: 21,
      now,
    });
    expect(mocks.map((mock) => mock.offset)).toEqual([13, 18]);

    // Le même blanc, passé le jour où le plan le posait : celui-là remplit le rendez-vous.
    const after = planMocks({
      exams: [
        { id: "bio", name: "Bio", examDate: addDays(today, 20), kind: "final", cardCount: 80 },
      ],
      done: [result({ examId: "bio", finishedAt: addDays(today, 13) })],
      horizonDays: 21,
      now,
    });
    expect(after.map((mock) => mock.offset)).toEqual([18]);
  });

  it("un entraînement lancé loin de l'épreuve n'efface aucun blanc du plan", () => {
    // Le geste réel : quelqu'un essaie la fonctionnalité trois semaines avant, pour voir. Il
    // n'a pas le droit d'y perdre les deux blancs qui mesurent sa préparation.
    expect(mockSlotFor(25)).toBeNull();
    expect(mockSlotFor(7)).toBe(0);
    expect(mockSlotFor(9)).toBe(0);
    expect(mockSlotFor(2)).toBe(1);
    expect(mockSlotFor(0)).toBe(1);
    expect(mockSlotFor(11)).toBeNull();
  });

  it("saute le palier dont le jour est déjà passé", () => {
    const mocks = planMocks({
      exams: [
        { id: "bio", name: "Bio", examDate: addDays(today, 3), kind: "final", cardCount: 80 },
      ],
      done: [],
      horizonDays: 4,
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
      horizonDays: 11,
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

  it("réserve la moitié du tirage à ce qui résiste", () => {
    const difficulties = new Map<string, CardDifficulty>(
      // Cinq cartes franchement ratées, le reste sain.
      ["c0", "c1", "c2", "c3", "c4"].map((id) => [
        id,
        {
          cardId: id,
          reviews: 8,
          againCount: 6,
          hardCount: 0,
          lastRating: 1,
          lastReviewedAt: today,
        },
      ]),
    );

    const drawn = drawMock(cards, ["bio"], 10, "graine", difficulties);
    const weakDrawn = drawn.filter((id) => difficulties.has(id));

    expect(drawn).toHaveLength(10);
    expect(weakDrawn).toHaveLength(5);
    // Et le reste échantillonne le programme : le score reste une mesure d'ensemble.
    expect(drawn.length - weakDrawn.length).toBe(5);
  });

  it("ne sert pas les fragiles en premier, ce qui annoncerait la couleur", () => {
    const difficulties = new Map<string, CardDifficulty>(
      ["c0", "c1", "c2", "c3", "c4"].map((id) => [
        id,
        {
          cardId: id,
          reviews: 8,
          againCount: 6,
          hardCount: 0,
          lastRating: 1,
          lastReviewedAt: today,
        },
      ]),
    );
    const drawn = drawMock(cards, ["bio"], 10, "graine", difficulties);
    const positions = drawn
      .map((id, index) => (difficulties.has(id) ? index : -1))
      .filter((index) => index >= 0);
    // Si les fragiles étaient servies en tête, elles occuperaient les cinq premières places.
    expect(positions).not.toEqual([0, 1, 2, 3, 4]);
  });

  it("reste un tirage uniforme quand rien ne résiste", () => {
    const sansJournal = drawMock(cards, ["bio"], 10, "graine");
    const avecJournalVide = drawMock(cards, ["bio"], 10, "graine", new Map());
    expect(sansJournal).toEqual(avecJournalVide);
    expect(sansJournal).toHaveLength(10);
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
      now,
    });

    const mockBlocks = plan.days.flatMap((day) => day.blocks.filter(isMockBlock));
    expect(mockBlocks.length).toBeGreaterThan(0);
    expect(mockBlocks[0]!.questionCount).toBeGreaterThan(0);
    expect(mockBlocks[0]!.examName).toBe("bio");
    expect(plan.mocks.length).toBe(mockBlocks.length);
  });

  it("compte le temps du blanc dans la charge de son jour", () => {
    const plan = planTerm({
      exams: [exam("bio", 14, { kind: "final" })],
      cards,
      now,
    });

    const mockDay = plan.days.find((day) => day.blocks.some(isMockBlock));
    expect(mockDay).toBeDefined();
    const mockBlock = mockDay!.blocks.find(isMockBlock)!;
    expect(mockDay!.minutes).toBeGreaterThanOrEqual(mockBlock.minutes);
  });

  it("met le blanc en tête du jour", () => {
    const plan = planTerm({
      exams: [exam("bio", 14, { kind: "final" })],
      cards,
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
      now,
    });
    expect(plan.mocks).toEqual([]);
    expect(plan.days.flatMap((day) => day.blocks.filter(isMockBlock))).toEqual([]);
  });

  it("pose un blanc même sans type déclaré, puisque le défaut est une épreuve écrite", () => {
    const plan = planTerm({
      exams: [exam("bio", 14)],
      cards,
      now,
    });
    expect(plan.mocks.length).toBeGreaterThan(0);
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
      now,
    });
    const withWeak = planTerm({
      exams: [exam("bio", 20)],
      cards,
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
      now,
    });
    const revision = planTerm({
      exams: [exam("bio", 20, { startingPoint: "solid" })],
      cards,
      now,
    });
    expect(froid.totalPasses).toBeGreaterThan(revision.totalPasses);
  });

  it("garde le plan d'avant sans réponse", () => {
    const cards = Array.from({ length: 30 }, (_, index) => card(`c${index}`));
    const sansReponse = planTerm({
      exams: [exam("bio", 20)],
      cards,
      now,
    });
    const dejaVu = planTerm({
      exams: [exam("bio", 20, { startingPoint: "seen" })],
      cards,
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
    const fast = planTerm({ exams: [exam("bio", 8)], cards, now });
    const slow = planTerm({
      exams: [exam("bio", 8)],
      cards,
      now,
      throughput: throughputFrom({ cards: 100, cardsPerMinute: 2 }),
    });
    // Le débit ne retire plus de passages : il change ce que la même journée coûte.
    expect(slow.totalPasses).toBe(fast.totalPasses);
    expect(slow.days[0]!.minutes).toBeGreaterThan(fast.days[0]!.minutes);
    expect(slow.throughput.measured).toBe(true);
  });
});
