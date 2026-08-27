/**
 * Le planificateur d'examen.
 *
 * Il déplace les échéances de tout un jeu de cartes : c'est le code du produit qui peut faire
 * le plus de dégâts en silence. Les propriétés vérifiées ici sont celles qui, si elles
 * cassent, donnent un plan que l'étudiant ne peut pas tenir - deux passages le même jour, un
 * dernier passage après l'examen, ou une charge empilée sur la veille.
 */

import { describe, expect, it } from "vitest";

import {
  BASE_PASSES,
  CLOSING_DAYS,
  activeDeadlines,
  activeExamMarks,
  addDays,
  averageDailyLoad,
  busiestDay,
  dayDifference,
  EXAM_INTENSITY_EMOJIS,
  examCountdownLabel,
  examUrgency,
  ladder,
  orderedCards,
  passesFor,
  planExam,
  startOfDay,
  type ExamCard,
} from "../src/srs/exam";
import { DETERMINISTIC_CONFIG, clampedToDeadline, schedule } from "../src/srs/sm2";
import { ReviewRating } from "../src/srs/types";

const now = new Date(2026, 8, 1, 14, 30);

function card(id: string, overrides: Partial<ExamCard> = {}): ExamCard {
  return {
    id,
    state: "review",
    intervalDays: 5,
    dueDate: addDays(now, 3),
    ...overrides,
  };
}

describe("passages", () => {
  it("part de l'intensité", () => {
    expect(passesFor(card("a"), "light")).toBe(BASE_PASSES.light);
    expect(passesFor(card("a"), "standard")).toBe(BASE_PASSES.standard);
    expect(passesFor(card("a"), "intense")).toBe(BASE_PASSES.intense);
  });

  it("ajoute un passage à une carte jamais vue", () => {
    expect(passesFor(card("a", { state: "new", intervalDays: 0 }), "standard")).toBe(4);
  });

  it("en retire un à une carte acquise depuis trois semaines", () => {
    expect(passesFor(card("a", { intervalDays: 21 }), "standard")).toBe(2);
    expect(passesFor(card("a", { intervalDays: 20 }), "standard")).toBe(3);
  });

  it("n'en descend jamais sous un", () => {
    expect(passesFor(card("a", { intervalDays: 400 }), "light")).toBe(1);
  });
});

describe("l'échelle des jours", () => {
  it("ne place jamais deux passages le même jour", () => {
    for (let window = 1; window <= 40; window += 1) {
      for (let passes = 1; passes <= 5; passes += 1) {
        for (let phase = 0; phase < 12; phase += 1) {
          const offsets = ladder(passes, window, phase);
          expect(new Set(offsets).size).toBe(offsets.length);
        }
      }
    }
  });

  it("reste dans la fenêtre, et croît", () => {
    for (let window = 1; window <= 40; window += 1) {
      for (let passes = 1; passes <= 5; passes += 1) {
        for (let phase = 0; phase < 12; phase += 1) {
          const offsets = ladder(passes, window, phase);
          expect(offsets.length).toBeGreaterThan(0);
          for (const offset of offsets) {
            expect(offset).toBeGreaterThanOrEqual(0);
            expect(offset).toBeLessThan(window);
          }
          for (let index = 1; index < offsets.length; index += 1) {
            expect(offsets[index]!).toBeGreaterThan(offsets[index - 1]!);
          }
        }
      }
    }
  });

  it("étale les derniers passages sur les trois derniers jours", () => {
    const window = 20;
    const lasts = new Set<number>();
    for (let phase = 0; phase < CLOSING_DAYS; phase += 1) {
      const offsets = ladder(3, window, phase);
      lasts.add(offsets[offsets.length - 1]!);
    }
    expect(lasts).toEqual(new Set([19, 18, 17]));
  });

  it("une fenêtre d'un jour donne un seul passage, aujourd'hui", () => {
    expect(ladder(4, 1, 0)).toEqual([0]);
    expect(ladder(1, 1, 7)).toEqual([0]);
  });
});

describe("le plan", () => {
  it("révise jusqu'à la veille, jamais le jour de l'examen", () => {
    const plan = planExam([card("a"), card("b")], addDays(now, 10), { now });

    expect(plan.windowDays).toBe(10);
    expect(dayDifference(plan.firstDay, plan.lastReviewDay)).toBe(9);
    expect(plan.lastReviewDay.getTime()).toBeLessThan(plan.examDay.getTime());
  });

  it("un examen aujourd'hui ne laisse que la journée en cours", () => {
    const plan = planExam([card("a")], now, { now });

    expect(plan.windowDays).toBe(1);
    expect(plan.projection.daysRemaining).toBe(0);
    expect(plan.days.get("a")).toEqual([0]);
  });

  it("compte la charge jour par jour, et la somme des passages", () => {
    const cards = Array.from({ length: 12 }, (_, index) => card(`c${index}`));
    const plan = planExam(cards, addDays(now, 14), { now, intensity: "standard" });

    const summed = plan.projection.load.reduce((total, count) => total + count, 0);
    expect(summed).toBe(plan.projection.totalReviews);
    expect(plan.projection.load).toHaveLength(14);
    expect(plan.projection.cardCount).toBe(12);
    expect(averageDailyLoad(plan.projection)).toBeGreaterThan(0);
    expect(busiestDay(plan.projection)).not.toBeNull();
  });

  it("place les cartes en retard, puis les neuves, puis les moins solides", () => {
    const late = card("late", { dueDate: addDays(now, -2) });
    const fresh = card("new", { state: "new", intervalDays: 0, dueDate: addDays(now, 5) });
    const weak = card("weak", { intervalDays: 2, dueDate: addDays(now, 5) });
    const solid = card("solid", { intervalDays: 30, dueDate: addDays(now, 5) });

    const order = orderedCards([solid, weak, fresh, late], now).map((item) => item.id);

    expect(order).toEqual(["late", "new", "weak", "solid"]);
  });
});

describe("les échéances actives", () => {
  const cards = [
    { id: "a", courseId: "maths", isSuspended: false },
    { id: "b", courseId: "maths", isSuspended: true },
    { id: "c", courseId: "svt", isSuspended: false },
  ];

  it("ignore un examen non planifié", () => {
    const deadlines = activeDeadlines(
      [{ date: addDays(now, 5), isPlanned: false, courseIds: ["maths"] }],
      cards,
      now,
    );
    expect(deadlines.size).toBe(0);
  });

  it("ignore un examen passé", () => {
    const deadlines = activeDeadlines(
      [{ date: addDays(now, -1), isPlanned: true, courseIds: ["maths"] }],
      cards,
      now,
    );
    expect(deadlines.size).toBe(0);
  });

  it("laisse les cartes mises de côté en dehors", () => {
    const deadlines = activeDeadlines(
      [{ date: addDays(now, 5), isPlanned: true, courseIds: ["maths"] }],
      cards,
      now,
    );
    expect([...deadlines.keys()]).toEqual(["a"]);
  });

  it("quand deux examens portent la même carte, le plus proche commande", () => {
    const deadlines = activeDeadlines(
      [
        { date: addDays(now, 20), isPlanned: true, courseIds: ["maths"] },
        { date: addDays(now, 6), isPlanned: true, courseIds: ["maths"] },
      ],
      cards,
      now,
    );
    expect(deadlines.get("a")).toEqual(startOfDay(addDays(now, 6)));
  });

  it("nomme l'examen qui commande la carte", () => {
    const marks = activeExamMarks(
      [
        { date: addDays(now, 20), isPlanned: true, courseIds: ["maths"], name: "Final" },
        { date: addDays(now, 6), isPlanned: true, courseIds: ["maths"], name: "Partiel" },
      ],
      cards,
      now,
    );

    expect(marks.get("a")).toEqual({
      name: "Partiel",
      date: startOfDay(addDays(now, 6)),
      daysRemaining: 6,
    });
    expect(marks.has("b")).toBe(false);
    expect(marks.has("c")).toBe(false);
  });
});

describe("le plafond d'intervalle", () => {
  const reviewing = {
    state: "review" as const,
    intervalDays: 10,
    easeFactor: 2.5,
    repetitions: 3,
    lapses: 0,
    stepIndex: 0,
  };

  const config = DETERMINISTIC_CONFIG;

  it("rabat une échéance qui dépasserait le jour J", () => {
    const deadline = addDays(now, 6);
    const outcome = clampedToDeadline(
      schedule(reviewing, ReviewRating.good, { now, config }),
      deadline,
      now,
    );

    expect(outcome.dueDate).toEqual(deadline);
    expect(outcome.intervalDays).toBeCloseTo(6, 2);
  });

  it("ne touche pas un palier d'apprentissage, qui se compte en minutes", () => {
    const learning = { ...reviewing, state: "learning" as const, stepIndex: 0 };
    const outcome = schedule(learning, ReviewRating.good, { now, config });
    const clamped = clampedToDeadline(outcome, addDays(now, 6), now);

    expect(clamped).toEqual(outcome);
  });

  it("ne rabat plus rien à moins de vingt-quatre heures de l'examen", () => {
    const outcome = schedule(reviewing, ReviewRating.good, { now, config });
    const clamped = clampedToDeadline(outcome, new Date(now.getTime() + 3_600_000), now);

    expect(clamped).toEqual(outcome);
  });

  it("laisse tranquille une échéance déjà en deçà", () => {
    const outcome = schedule(reviewing, ReviewRating.good, { now, config });
    const clamped = clampedToDeadline(outcome, addDays(now, 90), now);

    expect(clamped).toEqual(outcome);
  });
});

describe("l'urgence d'un examen", () => {
  it("annonce aujourd'hui, demain, J-N et passé comme l'iPhone", () => {
    expect(examCountdownLabel(0)).toBe("aujourd'hui");
    expect(examCountdownLabel(1)).toBe("demain");
    expect(examCountdownLabel(5)).toBe("J-5");
    expect(examCountdownLabel(-2)).toBe("passé");
  });

  it("porte un emoji par palier, pour le curseur du calendrier", () => {
    expect(EXAM_INTENSITY_EMOJIS.light).toBe("😌");
    expect(EXAM_INTENSITY_EMOJIS.intense).toBe("🔥");
  });

  it("classe aujourd'hui et demain en critique, la semaine en ocre", () => {
    expect(examUrgency(0)).toBe("critical");
    expect(examUrgency(1)).toBe("critical");
    expect(examUrgency(7)).toBe("soon");
    expect(examUrgency(14)).toBe("upcoming");
    expect(examUrgency(40)).toBe("later");
    expect(examUrgency(-1)).toBe("past");
  });
});
