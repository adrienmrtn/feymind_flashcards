/**
 * Les étapes ouvertes d'une leçon : les écrans des notes et leur glissé (`NotesSwipeTests`),
 * les cartes d'une révision (`LessonPickingTests`), l'ordre des propositions, la porte de
 * Mika (`MikaTests`).
 */

import { describe, expect, it } from "vitest";

import {
  cardMastery,
  circleCards,
  dueCards,
  isCardOfQuestion,
  masteryCounts,
  missedCardDraft,
  studyQueue,
  tomorrowStart,
  type LessonCard,
} from "../src/lesson/cards";
import { dayStamp, mikaGate, mikaTurns } from "../src/lesson/mika";
import { noteScreens, notesPages, screenWeight, swipeDirection } from "../src/lesson/notes-pages";
import { choiceOrder, matchRightOrder, orderPool, randomSeed } from "../src/lesson/question-order";
import type { NoteBlock, QuizQuestion, ThemeNotes } from "../src/lesson/types";

const words = (count: number) => Array.from({ length: count }, (_, index) => `mot${index}`).join(" ");
const paragraph = (count: number): NoteBlock => ({ type: "paragraph", text: words(count) });

function question(overrides: Partial<QuizQuestion> = {}): QuizQuestion {
  return {
    id: "theme:1",
    kind: "choice",
    prompt: "Qui ?",
    choices: ["a", "b", "c", "d"],
    answer: 2,
    why: "Parce que.",
    matches: [],
    difficulty: 2,
    ...overrides,
  };
}

describe("les écrans des notes", () => {
  it("ouvrent sur l'idée, puis les blocs, « À retenir » et la question", () => {
    const notes: ThemeNotes = { oneLiner: "L'idée.", blocks: [paragraph(80), paragraph(80)], takeaways: ["Une."] };
    expect(notesPages(notes, true).map((page) => page.type)).toEqual(["opening", "blocks", "blocks", "takeaways", "question"]);
    expect(notesPages(notes, false).map((page) => page.type)).toEqual(["opening", "blocks", "blocks", "takeaways"]);
  });

  it("lisent un ancien chapitre d'un seul écran", () => {
    expect(notesPages(null, true).map((page) => page.type)).toEqual(["legacy", "question"]);
  });

  it("gardent le sous-titre avec le bloc qu'il ouvre, et l'encadré qui le commente", () => {
    const blocks: NoteBlock[] = [
      { type: "subtitle", text: "Deux camps" },
      paragraph(90),
      { type: "callout", kind: "mistake", title: null, text: words(30) },
      paragraph(90),
    ];
    expect(noteScreens(blocks)).toEqual([
      [0, 3],
      [3, 4],
    ]);
  });

  it("font accueillir le suivant à un bloc trop court", () => {
    const blocks: NoteBlock[] = [paragraph(30), paragraph(40), paragraph(140)];
    // Le premier est mince : il prend le deuxième ; le troisième, trop lourd, reste seul.
    expect(noteScreens(blocks)).toEqual([
      [0, 2],
      [2, 3],
    ]);
  });

  it("ramènent un dernier bloc resté seul sur l'écran d'avant s'il y tient", () => {
    // Le premier n'est pas mince : il reste seul. Le dernier, mince, le rejoint s'il y tient.
    expect(noteScreens([paragraph(130), paragraph(20)])).toEqual([[0, 2]]);
    expect(noteScreens([paragraph(140), paragraph(20)])).toEqual([
      [0, 1],
      [1, 2],
    ]);
  });

  it("laissent son écran à un encadré en tête de thème", () => {
    const blocks: NoteBlock[] = [{ type: "callout", kind: "why", title: null, text: words(20) }, paragraph(130)];
    expect(noteScreens(blocks)).toEqual([
      [0, 1],
      [1, 2],
    ]);
    // Un bloc mince qui le suit, lui, le rejoint : l'écran reste court.
    expect(noteScreens([blocks[0]!, paragraph(30)])).toEqual([[0, 2]]);
  });

  it("pèsent le cadre des listes, des tableaux et des dates", () => {
    expect(screenWeight([{ type: "list", items: ["a b", "c"] }])).toBe(3 + 8);
    expect(screenWeight([{ type: "table", columns: ["x", "y"], rows: [["1", "2"]] }])).toBe(4 + 18 + 6);
    expect(screenWeight([{ type: "dates", items: [{ date: "1914", text: "Guerre" }] }])).toBe(2 + 18 + 4);
    expect(screenWeight([{ type: "subtitle", text: "Un" }])).toBe(1 + 6);
  });
});

describe("le glissé des notes", () => {
  const swipe = (dx: number, dy = 0, predicted?: number, rightToLeft = false) =>
    swipeDirection({ width: dx, height: dy }, { width: predicted ?? dx, height: dy }, rightToLeft);

  it("tourne la page quand il est franc, dans les deux sens", () => {
    expect(swipe(-90)).toBe("forward");
    expect(swipe(90)).toBe("back");
  });

  it("ne tourne pas sur un geste de travers", () => {
    expect(swipe(-90, 60)).toBeNull();
    expect(swipe(80, 40)).toBeNull();
    expect(swipe(-90, 30)).toBe("forward");
  });

  it("ne tourne pas sur un geste court, sauf lancé", () => {
    expect(swipe(-50)).toBeNull();
    expect(swipe(-50, 0, -220)).toBe("forward");
    expect(swipe(-50, 0, 220)).toBeNull();
    expect(swipe(-20, 0, -400)).toBeNull();
  });

  it("se lit en miroir de droite à gauche", () => {
    expect(swipe(90, 0, undefined, true)).toBe("forward");
    expect(swipe(-90, 0, undefined, true)).toBe("back");
  });
});

describe("les cartes d'une leçon", () => {
  const now = new Date("2026-10-22T10:00:00");
  const day = (offset: number) => new Date(now.getTime() + offset * 86_400_000).toISOString();
  const card = (index: number, overrides: Partial<LessonCard> = {}): LessonCard => ({
    id: `card-${index}`,
    front: `Carte ${index}`,
    kind: "basic",
    isSuspended: false,
    state: "review",
    dueDate: day(5),
    intervalDays: 10,
    position: index,
    ...overrides,
  });

  it("préfèrent les questions ratées, puis les dues, puis les neuves", () => {
    const cards = Array.from({ length: 14 }, (_, index) => card(index));
    cards[13] = card(13, { kind: "choice", front: "Qui ?" });
    cards[5] = card(5, { dueDate: day(-1) });
    cards[0] = card(0, { state: "new" });
    cards[1] = card(1, { state: "new" });
    const picked = circleCards(cards, new Set(["Qui ?"]), "lesson", 2, now).map((entry) => entry.id);
    expect(picked).toHaveLength(10);
    expect(picked[0]).toBe("card-13");
    expect(picked[1]).toBe("card-5");
    expect(picked.slice(2, 4)).toEqual(["card-0", "card-1"]);
    expect(new Set(picked).size).toBe(10);
    expect(circleCards(cards, new Set(["Qui ?"]), "lesson", 2, now).map((entry) => entry.id)).toEqual(picked);
  });

  it("laissent de côté les cartes suspendues", () => {
    const cards = [card(0, { isSuspended: true }), card(1)];
    expect(circleCards(cards, new Set(), "lesson", 0, now).map((entry) => entry.id)).toEqual(["card-1"]);
    expect(dueCards([card(0, { dueDate: day(-1), isSuspended: true }), card(1, { dueDate: day(-2) })], now).map((entry) => entry.id)).toEqual(["card-1"]);
  });

  it("font une séance des dues d'abord, puis de quinze neuves au plus", () => {
    const cards = [
      ...Array.from({ length: 20 }, (_, index) => card(index, { state: "new", position: 100 - index })),
      card(50, { dueDate: day(-2) }),
      card(51, { dueDate: day(-1) }),
      card(52, { state: "new", dueDate: day(-3) }),
    ];
    const queue = studyQueue(cards, now);
    expect(queue.slice(0, 2).map((entry) => entry.id)).toEqual(["card-50", "card-51"]);
    expect(queue).toHaveLength(2 + 15);
    expect(queue[2]!.position).toBeLessThan(queue[3]!.position);
  });

  it("disent où en est une carte", () => {
    expect(cardMastery({ state: "new", intervalDays: 0 })).toBe("new");
    expect(cardMastery({ state: "review", intervalDays: 20 })).toBe("learning");
    expect(cardMastery({ state: "review", intervalDays: 21 })).toBe("mastered");
    expect(masteryCounts([card(0, { state: "new" }), card(1, { intervalDays: 30 }), card(2, { intervalDays: 3 })])).toEqual({ new: 1, learning: 1, mastered: 1 });
  });

  it("font d'une question ratée une carte QCM, et d'un ordre une carte recto verso", () => {
    const choice = missedCardDraft(question());
    expect(choice).toEqual({ front: "Qui ?", back: "Parce que.", kind: "choice", choices: ["a", "b", "c", "d"], correctChoiceIndex: 2 });
    const order = missedCardDraft(question({ kind: "order", choices: ["un", "deux", "trois"] }));
    expect(order.kind).toBe("basic");
    expect(order.back).toBe("un → deux → trois\n\nParce que.");
    expect(isCardOfQuestion({ front: "Qui ?", kind: "choice" }, question())).toBe(true);
    expect(isCardOfQuestion({ front: "Qui ?", kind: "cloze" }, question())).toBe(false);
    const tomorrow = tomorrowStart(now);
    expect(tomorrow.getTime()).toBeGreaterThan(now.getTime());
    expect(tomorrow.getHours()).toBe(0);
    expect(tomorrow.getTime() - now.getTime()).toBeLessThanOrEqual(86_400_000);
  });
});

describe("l'ordre des propositions", () => {
  it("ne bouge pas sans graine, et se répète pour la même graine", () => {
    const q = question();
    expect(choiceOrder(q, 0n)).toEqual([0, 1, 2, 3]);
    expect(choiceOrder(q, 42n)).toEqual(choiceOrder(q, 42n));
    expect(choiceOrder(q, 42n).slice().sort()).toEqual([0, 1, 2, 3]);
    const seeds = Array.from({ length: 12 }, (_, index) => BigInt(index + 1));
    expect(seeds.some((seed) => choiceOrder(q, seed).join() !== "0,1,2,3")).toBe(true);
  });

  it("ne présente jamais un ordre ou une association dans le bon ordre", () => {
    const order = question({ kind: "order", choices: ["un", "deux", "trois"] });
    const match = question({ kind: "match", choices: ["a", "b", "c"], matches: ["1", "2", "3"] });
    for (let seed = 0n; seed < 40n; seed += 1n) {
      expect(orderPool(order, seed).join()).not.toBe("0,1,2");
      expect(matchRightOrder(match, seed).join()).not.toBe("0,1,2");
    }
    expect(orderPool(order, 5n)).toEqual(orderPool(order, 5n));
  });

  it("tire une graine neuve, jamais nulle", () => {
    expect(randomSeed()).not.toBe(0n);
    expect(randomSeed()).not.toBe(randomSeed());
  });
});

describe("la porte de Mika", () => {
  it("offre la première question, puis Pro", () => {
    expect(mikaGate({ isPro: false, freeQuestionUsed: false, askedToday: 0 })).toBe("allowed");
    expect(mikaGate({ isPro: false, freeQuestionUsed: true, askedToday: 0 })).toBe("paywall");
  });

  it("plafonne un abonné à trente par jour", () => {
    expect(mikaGate({ isPro: true, freeQuestionUsed: true, askedToday: 29 })).toBe("allowed");
    expect(mikaGate({ isPro: true, freeQuestionUsed: true, askedToday: 30 })).toBe("dailyCapReached");
  });

  it("n'envoie que les huit derniers tours, bornés", () => {
    const turns = mikaTurns(
      Array.from({ length: 12 }, (_, index) => ({ role: index % 2 === 0 ? ("user" as const) : ("mika" as const), text: "x".repeat(2_000) })),
    );
    expect(turns).toHaveLength(8);
    expect(turns.every((turn) => turn.text.length <= 1_500)).toBe(true);
    expect(turns[turns.length - 1]!.role).toBe("mika");
  });

  it("date le jour dans le calendrier de l'élève", () => {
    expect(dayStamp(new Date(2026, 0, 5, 23, 59))).toBe("2026-1-5");
  });
});
