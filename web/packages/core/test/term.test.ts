import { describe, expect, it } from "vitest";

import {
  addDays,
  capacityFor,
  capacityWindow,
  feasibility,
  isReviewBlock,
  levers,
  loadBars,
  matchesFormat,
  minutesForCards,
  planExam,
  planTerm,
  startOfDay,
  todayCardCount,
  uniformWeek,
  usableDaysUntil,
  weeklyFromRow,
  weeklyTotal,
  type Availability,
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

/** Une semaine ouverte partout, en minutes. */
function open(minutes = 60): Availability {
  return { weekly: uniformWeek(minutes), exceptions: [] };
}

describe("disponibilités", () => {
  it("rend le rythme quotidien quand rien n'est réglé", () => {
    expect(weeklyFromRow(null, 25)).toEqual([25, 25, 25, 25, 25, 25, 25]);
    expect(weeklyFromRow([10, 20], 30)).toEqual([30, 30, 30, 30, 30, 30, 30]);
    expect(weeklyTotal(uniformWeek(15))).toBe(105);
  });

  it("borne les valeurs venues de la base", () => {
    expect(weeklyFromRow([-5, 0, 10, 20, 30, 900, 45])).toEqual([0, 0, 10, 20, 30, 600, 45]);
  });

  it("laisse l'exception écraser la semaine type", () => {
    const availability: Availability = {
      weekly: uniformWeek(45),
      exceptions: [{ day: addDays(today, 2), minutes: 0 }],
    };
    expect(capacityFor(availability, today)).toBe(45);
    expect(capacityFor(availability, addDays(today, 2))).toBe(0);
    expect(capacityFor(availability, addDays(today, 3))).toBe(45);
  });

  it("compte les jours réellement utilisables, pas les jours du calendrier", () => {
    const availability: Availability = {
      weekly: [60, 60, 0, 60, 60, 0, 0],
      exceptions: [],
    };
    const window = capacityWindow(availability, today, 7);
    expect(window.filter((minutes) => minutes > 0)).toHaveLength(4);
    expect(usableDaysUntil(availability, today, addDays(today, 7))).toBe(4);
  });
});

describe("planExam sous contrainte de disponibilité", () => {
  it("ne pose aucun passage sur un jour fermé", () => {
    const cards = Array.from({ length: 20 }, (_, index) => card(`c${index}`, "bio"));
    // Un jour sur deux fermé, sur une fenêtre de dix jours.
    const capacities = Array.from({ length: 10 }, (_, offset) => (offset % 2 === 0 ? 60 : 0));

    const plan = planExam(cards, addDays(today, 10), { now, capacities });

    for (const offsets of plan.days.values()) {
      for (const offset of offsets) expect(capacities[offset]).toBeGreaterThan(0);
    }
  });

  it("garde l'échelle d'avant quand aucune capacité n'est fournie", () => {
    const cards = Array.from({ length: 12 }, (_, index) => card(`c${index}`, "bio"));
    const withoutCapacities = planExam(cards, addDays(today, 12), { now });
    const allOpen = planExam(cards, addDays(today, 12), {
      now,
      capacities: new Array(12).fill(60),
    });
    expect([...allOpen.days.entries()]).toEqual([...withoutCapacities.days.entries()]);
  });

  it("rend la fenêtre entière si tout est déclaré fermé, plutôt qu'un plan vide", () => {
    const cards = [card("a", "bio")];
    const plan = planExam(cards, addDays(today, 5), { now, capacities: new Array(5).fill(0) });
    expect(plan.projection.totalReviews).toBeGreaterThan(0);
  });
});

describe("planTerm", () => {
  it("ne dépasse jamais la capacité d'un jour", () => {
    const cards = Array.from({ length: 120 }, (_, index) => card(`c${index}`, "bio"));
    const plan = planTerm({
      exams: [exam("bio", 8, ["bio"])],
      cards,
      availability: open(30),
      now,
    });

    for (const day of plan.days) {
      if (day.capacityMinutes === 0) expect(day.cardCount).toBe(0);
      else expect(day.minutes).toBeLessThanOrEqual(day.capacityMinutes);
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
      availability: open(60),
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
      availability: open(120),
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
      availability: open(60),
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
      availability: open(60),
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
      availability: open(60),
      now,
    });
    const blocks = plan.days.flatMap((day) => day.blocks);
    expect(blocks[0]?.examName).toBe("Partiel de biologie");
    expect(blocks[0]?.courseId).toBe("bio");
  });
});

describe("verdict", () => {
  it("annonce que ça tient quand la charge rentre", () => {
    const plan = planTerm({
      exams: [exam("bio", 20, ["bio"])],
      cards: Array.from({ length: 20 }, (_, index) => card(`c${index}`, "bio")),
      availability: open(60),
      now,
    });
    const verdict = feasibility(plan);
    expect(verdict.level).toBe("clear");
    expect(verdict.deficitMinutes).toBe(0);
    expect(levers(plan, verdict)).toEqual([]);
  });

  it("chiffre le déficit quand la charge déborde", () => {
    const plan = planTerm({
      exams: [exam("bio", 3, ["bio"])],
      cards: Array.from({ length: 400 }, (_, index) => card(`c${index}`, "bio")),
      availability: open(10),
      now,
    });
    const verdict = feasibility(plan);

    expect(verdict.level).toBe("short");
    expect(verdict.overflowPasses).toBeGreaterThan(0);
    expect(verdict.deficitMinutes).toBe(minutesForCards(verdict.overflowPasses));
    expect(verdict.examIds).toContain("bio");

    const proposals = levers(plan, verdict);
    expect(proposals.length).toBeGreaterThan(0);
    expect(proposals.map((lever) => lever.kind)).toContain("capacity");
    // Rendus du plus rentable au moins rentable.
    for (let index = 1; index < proposals.length; index += 1) {
      expect(proposals[index - 1]!.recoveredMinutes).toBeGreaterThanOrEqual(
        proposals[index]!.recoveredMinutes,
      );
    }
  });

  it("marque les jours fermés dans la frise", () => {
    const availability: Availability = {
      weekly: uniformWeek(60),
      exceptions: [{ day: addDays(today, 2), minutes: 0 }],
    };
    const plan = planTerm({
      exams: [exam("bio", 6, ["bio"])],
      cards: Array.from({ length: 10 }, (_, index) => card(`c${index}`, "bio")),
      availability,
      now,
    });
    const bars = loadBars(plan);
    expect(bars[2]?.isClosed).toBe(true);
    expect(bars[2]?.minutes).toBe(0);
    expect(bars[0]?.isClosed).toBe(false);
    expect(bars.every((bar) => bar.fill >= 0 && bar.fill <= 1)).toBe(true);
  });

  it("pose du travail dès aujourd'hui", () => {
    const plan = planTerm({
      exams: [exam("bio", 7, ["bio"])],
      cards: Array.from({ length: 40 }, (_, index) => card(`c${index}`, "bio")),
      availability: open(60),
      now,
    });
    expect(todayCardCount(plan)).toBeGreaterThan(0);
  });
});
