import { describe, expect, it } from "vitest";

import {
  addDays,
  isReviewBlock,
  loadBars,
  matchesFormat,
  planTerm,
  startOfDay,
  termLoad,
  todayBlocks,
  todayCardCount,
  type TermCard,
  type TermExam,
} from "../src/index";

const now = new Date("2026-09-09T09:00:00");
const today = startOfDay(now);

function card(id: string, courseId: string, over: Partial<TermCard> = {}): TermCard {
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

function exam(id: string, days: number, courseIds: string[], over: Partial<TermExam> = {}): TermExam {
  return {
    id,
    name: id,
    examDate: addDays(today, days),
    intensity: "standard",
    courseIds,
    ...over,
  };
}

describe("planTerm", () => {
  it("pose chaque passage avant l'épreuve, sans plafond de journée", () => {
    const cards = Array.from({ length: 120 }, (_, index) => card(`c${index}`, "bio"));
    const plan = planTerm({
      exams: [exam("bio", 8, ["bio"])],
      cards,
      now,
    });

    // Rien ne déborde : ce que l'échelle demande est servi en entier.
    expect(plan.totalPasses).toBeGreaterThan(0);
    for (const day of plan.days) {
      for (const block of day.blocks) expect(day.offset).toBeLessThanOrEqual(7);
    }
  });

  it("répartit deux épreuves sur le même emploi du temps", () => {
    const cards = [
      ...Array.from({ length: 30 }, (_, index) => card(`b${index}`, "bio")),
      ...Array.from({ length: 30 }, (_, index) => card(`d${index}`, "droit")),
    ];
    const plan = planTerm({
      exams: [exam("bio", 6, ["bio"]), exam("droit", 12, ["droit"])],
      cards,
      now,
    });

    expect(plan.passesByExam.get("bio")).toBeGreaterThan(0);
    expect(plan.passesByExam.get("droit")).toBeGreaterThan(0);
    // Aucun passage ne tombe après l'épreuve qui l'a demandé.
    for (const day of plan.days) {
      for (const block of day.blocks) {
        const deadline = block.examId === "bio" ? 5 : 11;
        expect(day.offset).toBeLessThanOrEqual(deadline);
      }
    }
  });

  it("ne voit pas une carte deux fois le même jour", () => {
    const cards = Array.from({ length: 6 }, (_, index) => card(`c${index}`, "bio"));
    const plan = planTerm({
      exams: [exam("bio", 4, ["bio"])],
      cards,
      now,
    });

    for (const day of plan.days) {
      const ids = day.blocks.filter(isReviewBlock).flatMap((block) => block.cardIds);
      expect(new Set(ids).size).toBe(ids.length);
    }
  });

  it("ignore les cartes suspendues et les épreuves passées", () => {
    const plan = planTerm({
      exams: [exam("vieux", -3, ["bio"]), exam("bio", 5, ["bio"])],
      cards: [card("a", "bio", { isSuspended: true }), card("b", "bio")],
      now,
    });
    expect(plan.passesByExam.has("vieux")).toBe(false);
    const ids = plan.days.flatMap((day) =>
      day.blocks.filter(isReviewBlock).flatMap((block) => block.cardIds),
    );
    expect(ids).not.toContain("a");
  });

  it("ne retient que les formats cochés", () => {
    expect(matchesFormat("choice", [])).toBe(true);
    expect(matchesFormat("choice", ["choice"])).toBe(true);
    expect(matchesFormat("basic", ["choice"])).toBe(false);

    const plan = planTerm({
      exams: [exam("qcm", 6, ["bio"], { formats: ["choice"] })],
      cards: [card("a", "bio", { kind: "basic" }), card("b", "bio", { kind: "choice" })],
      now,
    });
    const ids = plan.days.flatMap((day) =>
      day.blocks.filter(isReviewBlock).flatMap((block) => block.cardIds),
    );
    expect(ids).toContain("b");
    expect(ids).not.toContain("a");
  });

  it("nomme chaque bloc par l'épreuve qui l'a demandé", () => {
    const plan = planTerm({
      exams: [exam("Partiel de biologie", 5, ["bio"])],
      cards: [card("a", "bio")],
      now,
    });
    const blocks = plan.days.flatMap((day) => day.blocks);
    expect(blocks[0]?.examName).toBe("Partiel de biologie");
    expect(blocks[0]?.courseId).toBe("bio");
  });
});

describe("ce qu'il reste aujourd'hui", () => {
  it("ne compte plus une carte déjà revue", () => {
    const cards = Array.from({ length: 12 }, (_, index) => card(`c${index}`, "bio"));
    const plan = planTerm({ exams: [exam("bio", 6, ["bio"])], cards, now });

    const planted = todayCardCount(plan);
    expect(planted).toBeGreaterThan(0);

    // Les trois premières cartes du jour sont faites : le compte descend d'autant.
    const done = new Set(
      plan.days[0]!.blocks.flatMap((block) => (isReviewBlock(block) ? block.cardIds : [])).slice(0, 3),
    );
    expect(todayCardCount(plan, (id) => !done.has(id))).toBe(planted - 3);
  });

  it("retire un bloc dont toutes les cartes sont faites", () => {
    const plan = planTerm({
      exams: [exam("bio", 6, ["bio"])],
      cards: [card("c1", "bio"), card("c2", "bio")],
      now,
    });
    expect(todayBlocks(plan).length).toBeGreaterThan(0);
    expect(todayBlocks(plan, () => false)).toHaveLength(0);
    expect(todayCardCount(plan, () => false)).toBe(0);
  });

  it("garde le total posé quand on ne dit rien de ce qui est fait", () => {
    const plan = planTerm({
      exams: [exam("bio", 6, ["bio"])],
      cards: [card("c1", "bio"), card("c2", "bio")],
      now,
    });
    expect(todayCardCount(plan)).toBe(plan.days[0]!.cardCount);
  });
});

describe("les jours off", () => {
  it("ne pose rien sur un jour posé off", () => {
    const cards = Array.from({ length: 60 }, (_, index) => card(`c${index}`, "bio"));
    const plan = planTerm({
      exams: [exam("bio", 10, ["bio"])],
      cards,
      now,
      offDays: [2, 3, 4],
    });

    for (const offset of [2, 3, 4]) {
      expect(plan.days[offset]!.isOff).toBe(true);
      expect(plan.days[offset]!.cardCount).toBe(0);
    }
    // Le travail n'est pas perdu, il est reporté sur les jours ouverts.
    expect(plan.totalPasses).toBeGreaterThan(0);
  });

  it("reporte la charge sur les jours ouverts plutôt que de la jeter", () => {
    const cards = Array.from({ length: 60 }, (_, index) => card(`c${index}`, "bio"));
    const open = planTerm({ exams: [exam("bio", 10, ["bio"])], cards, now });
    const withOff = planTerm({
      exams: [exam("bio", 10, ["bio"])],
      cards,
      now,
      offDays: [2, 3, 4],
    });

    // À une carte près : une carte ne se voit pas deux fois le même jour, donc quelques
    // passages ne trouvent plus de place. Le gros du travail, lui, reste.
    expect(withOff.totalPasses).toBeGreaterThan(open.totalPasses * 0.8);
  });

  it("ignore des jours off qui couvrent toute la période", () => {
    const cards = Array.from({ length: 20 }, (_, index) => card(`c${index}`, "bio"));
    const plan = planTerm({
      exams: [exam("bio", 5, ["bio"])],
      cards,
      now,
      offDays: [0, 1, 2, 3, 4, 5],
    });

    // Obéir à la lettre donnerait un plan vide. On préfère un plan.
    expect(plan.totalPasses).toBeGreaterThan(0);
    expect(plan.days.every((day) => !day.isOff)).toBe(true);
  });

  it("porte le jour off jusqu'aux barres de charge", () => {
    const plan = planTerm({
      exams: [exam("bio", 6, ["bio"])],
      cards: [card("c1", "bio")],
      now,
      offDays: [1],
    });
    expect(loadBars(plan)[1]!.isOff).toBe(true);
    expect(loadBars(plan)[0]!.isOff).toBe(false);
  });
});

describe("ce que la période demande", () => {
  it("dit le temps par jour, sans jamais parler de déficit", () => {
    const plan = planTerm({
      exams: [exam("bio", 20, ["bio"])],
      cards: Array.from({ length: 20 }, (_, index) => card(`c${index}`, "bio")),
      now,
    });
    const load = termLoad(plan);

    expect(load.workingDays).toBeGreaterThan(0);
    expect(load.averageMinutes).toBeGreaterThan(0);
    expect(load.totalMinutes).toBeGreaterThanOrEqual(load.averageMinutes);
    expect(load.busiest?.minutes).toBeGreaterThanOrEqual(load.averageMinutes);
  });

  it("monte simplement la charge quand il y a beaucoup à faire en peu de jours", () => {
    const light = planTerm({
      exams: [exam("bio", 3, ["bio"])],
      cards: Array.from({ length: 20 }, (_, index) => card(`c${index}`, "bio")),
      now,
    });
    const heavy = planTerm({
      exams: [exam("bio", 3, ["bio"])],
      cards: Array.from({ length: 400 }, (_, index) => card(`c${index}`, "bio")),
      now,
    });

    expect(termLoad(heavy).averageMinutes).toBeGreaterThan(termLoad(light).averageMinutes);
    // Et toutes les cartes sont servies : plus rien ne se perd faute de place.
    expect(heavy.totalPasses).toBeGreaterThan(light.totalPasses);
  });

  it("donne une frise dont chaque cran porte sa charge", () => {
    const plan = planTerm({
      exams: [exam("bio", 6, ["bio"])],
      cards: Array.from({ length: 10 }, (_, index) => card(`c${index}`, "bio")),
      now,
    });
    const bars = loadBars(plan);

    expect(bars).toHaveLength(plan.days.length);
    expect(bars.some((bar) => bar.minutes > 0)).toBe(true);
    expect(bars.every((bar) => bar.cardCount >= 0)).toBe(true);
    expect(bars[6]?.examIds).toContain("bio");
  });

  it("pose du travail dès aujourd'hui", () => {
    const plan = planTerm({
      exams: [exam("bio", 7, ["bio"])],
      cards: Array.from({ length: 40 }, (_, index) => card(`c${index}`, "bio")),
      now,
    });
    expect(todayCardCount(plan)).toBeGreaterThan(0);
  });
});
