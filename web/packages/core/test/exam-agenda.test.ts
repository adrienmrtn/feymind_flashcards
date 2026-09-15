import { describe, expect, it } from "vitest";

import { addDays, startOfDay } from "../src/srs/exam";
import {
  agendaOn,
  type AgendaDone,
  type AgendaEvent,
  type AgendaOverride,
  examAgenda,
} from "../src/srs/exam-agenda";
import { MOCK_OFFSETS } from "../src/srs/mock";

const TODAY = startOfDay(new Date(2026, 8, 1));

function agenda(
  daysRemaining: number,
  extra: { done?: AgendaDone[]; overrides?: AgendaOverride[]; cardCount?: number } = {},
): AgendaEvent[] {
  return examAgenda({
    exams: [{
      id: "e1",
      name: "Partiel de biologie",
      examDate: addDays(TODAY, daysRemaining),
      cardCount: extra.cardCount ?? 200,
    }],
    done: extra.done,
    overrides: extra.overrides,
    now: TODAY,
  });
}

const kinds = (events: AgendaEvent[], kind: string) => events.filter((e) => e.kind === kind);
const day = (offset: number) => addDays(TODAY, offset);

describe("l'agenda d'un examen", () => {
  it("pose les deux blancs à leurs rendez-vous", () => {
    const mocks = kinds(agenda(30), "mock");
    expect(mocks.length).toBe(MOCK_OFFSETS.length);
    expect(mocks.map((mock) => 30 - mock.offset).sort((a, b) => a - b))
      .toEqual([...MOCK_OFFSETS].sort((a, b) => a - b));
  });

  it("pose les parcours et les tient à l'écart des blancs", () => {
    // Enchaîner un blanc et un parcours ne mesure plus rien : le second score dit la fatigue.
    const events = agenda(30);
    const mockDays = new Set(kinds(events, "mock").map((event) => event.date.getTime()));

    for (const parcours of kinds(events, "parcours")) {
      expect(mockDays.has(parcours.date.getTime())).toBe(false);
    }

    // Et deux parcours ne partagent pas un jour non plus.
    const parcoursDays = kinds(events, "parcours").map((event) => event.date.getTime());
    expect(new Set(parcoursDays).size).toBe(parcoursDays.length);
  });

  it("écarte le parcours vers l'arrière, jamais vers la veille de l'épreuve", () => {
    // Vers l'avant, il finirait le jour J : il ne resterait plus le temps de corriger ce que
    // le test révèle. Le blanc de J-2 pousse donc le parcours de J-2 vers J-3.
    const events = agenda(30);
    const closest = kinds(events, "parcours").reduce((best, event) =>
      event.offset > best.offset ? best : event
    );
    expect(closest.offset).toBeLessThanOrEqual(30 - 3);
  });

  it("déplace un rendez-vous là où l'étudiant l'a mis, et le dit", () => {
    const events = agenda(30, {
      overrides: [{ examId: "e1", kind: "parcours", slot: 0, date: day(11) }],
    });

    const moved = kinds(events, "parcours").find((event) => event.slot === 0)!;
    expect(moved.date.getTime()).toBe(day(11).getTime());
    expect(moved.moved).toBe(true);

    // Les autres ne bougent pas : une surcharge ne désigne qu'un rendez-vous.
    expect(kinds(events, "parcours").filter((event) => event.moved).length).toBe(1);
  });

  it("identifie un rendez-vous par son rang, pas par sa date", () => {
    // Le rang se compte depuis l'épreuve, donc il ne bouge pas quand les jours passent : c'est
    // ce qui permet à une surcharge de survivre à la nuit.
    const override: AgendaOverride = { examId: "e1", kind: "mock", slot: 0, date: day(20) };
    const before = kinds(agenda(30, { overrides: [override] }), "mock").find((e) => e.slot === 0)!;

    const later = examAgenda({
      exams: [{ id: "e1", name: "x", examDate: addDays(TODAY, 30), cardCount: 200 }],
      overrides: [override],
      now: addDays(TODAY, 3),
    });
    const after = kinds(later, "mock").find((event) => event.slot === 0)!;

    expect(after.date.getTime()).toBe(before.date.getTime());
    expect(after.offset).toBe(before.offset - 3);
  });

  it("marque fait un rendez-vous honoré par une session", () => {
    const events = agenda(30, {
      done: [{ examId: "e1", kind: "mock", finishedAt: day(30 - MOCK_OFFSETS[0]!) }],
    });
    const honoured = kinds(events, "mock").find((event) => event.slot === 0)!;
    expect(honoured.status).toBe("done");
    expect(kinds(events, "mock").find((event) => event.slot === 1)!.status).toBe("upcoming");
  });

  it("n'attribue pas une session lancée loin de tout rendez-vous", () => {
    // Un blanc passé par curiosité ne doit pas effacer celui de J-7, qui reste la seule mesure
    // sérieuse du produit.
    const events = agenda(60, { done: [{ examId: "e1", kind: "mock", finishedAt: day(1) }] });
    expect(kinds(events, "mock").every((event) => event.status !== "done")).toBe(true);
  });

  it("ne laisse pas une session de parcours en effacer trois", () => {
    // Les parcours sont posés tous les deux ou trois jours : la tolérance large du blanc les
    // ferait se voler leurs sessions.
    const events = agenda(30, {
      done: [{ examId: "e1", kind: "parcours", finishedAt: day(30 - 13) }],
    });
    expect(kinds(events, "parcours").filter((event) => event.status === "done").length)
      .toBeLessThanOrEqual(1);
  });

  it("garde affiché un rendez-vous manqué, à sa date", () => {
    // Il ne se rattrape pas et ne se repose pas ailleurs : l'étudiant qui a sauté le test de
    // mardi doit le voir, sinon la seule trace est son impression.
    const events = examAgenda({
      exams: [{ id: "e1", name: "x", examDate: addDays(TODAY, 4), cardCount: 200 }],
      now: addDays(TODAY, 20),
    });

    const past = events.filter((event) => event.offset < 0);
    expect(past.length).toBeGreaterThan(0);
    expect(past.every((event) => event.status === "missed")).toBe(true);
  });

  it("ne pose aucun blanc sur un oral, mais garde les parcours", () => {
    // On ne s'entraîne pas à un oral avec un QCM ; cinq questions orales, en revanche, le
    // servent aussi bien qu'un écrit.
    const events = examAgenda({
      exams: [{ id: "e1", name: "Colle", examDate: addDays(TODAY, 20), kind: "oral", cardCount: 200 }],
      now: TODAY,
    });
    expect(kinds(events, "mock").length).toBe(0);
    expect(kinds(events, "parcours").length).toBeGreaterThan(0);
  });

  it("rend les rendez-vous d'un jour, pour « Au programme »", () => {
    const events = agenda(30);
    const target = kinds(events, "parcours")[0]!;
    const same = agendaOn(events, target.date);
    expect(same.length).toBeGreaterThan(0);
    expect(same.every((event) => event.date.getTime() === target.date.getTime())).toBe(true);
    expect(agendaOn(events, day(-5))).toEqual([]);
  });

  it("rend l'agenda trié par date, examens confondus", () => {
    const events = examAgenda({
      exams: [
        { id: "a", name: "Colle", examDate: addDays(TODAY, 8), cardCount: 120 },
        { id: "b", name: "Partiel", examDate: addDays(TODAY, 25), cardCount: 300 },
      ],
      now: TODAY,
    });

    for (const [index, event] of events.slice(1).entries()) {
      expect(event.date.getTime()).toBeGreaterThanOrEqual(events[index]!.date.getTime());
    }
    expect(new Set(events.map((event) => event.examId))).toEqual(new Set(["a", "b"]));
  });
});
