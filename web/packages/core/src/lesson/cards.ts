import { CIRCLE_CARD_COUNT, pickCards, pickingSeed, type CardCandidate } from "./picking";
import { answerText, type QuizQuestion } from "./types";

/**
 * **Les flashcards d'une leçon** : lesquelles on révise, dans quel ordre, et la carte que
 * devient une question ratée. Jumeau de la partie « cartes » de `LessonSession.swift`, de
 * `CardMastery` et de `LessonReview.cardForMissed`.
 */

/** Ce que le tirage sait d'une carte, quelle que soit la table d'où elle vient. */
export interface LessonCard {
  id: string;
  front: string;
  kind: string;
  isSuspended: boolean;
  state: "new" | "learning" | "review" | "relearning";
  dueDate: string | Date;
  intervalDays: number;
  position: number;
}

function dueAt(card: LessonCard): number {
  return new Date(card.dueDate).getTime();
}

function active<T extends LessonCard>(cards: readonly T[]): T[] {
  return cards.filter((card) => !card.isSuspended);
}

/**
 * Les dix cartes d'une révision de leçon : les questions ratées d'abord, puis les cartes dues,
 * puis les neuves dans l'ordre de la leçon, puis un tirage du reste. La graine suit le nombre
 * d'étapes faites : une révision relancée au même point redonne les mêmes cartes.
 */
export function circleCards<T extends LessonCard>(
  cards: readonly T[],
  missedPrompts: ReadonlySet<string>,
  lessonId: string,
  doneCount: number,
  now = new Date(),
): T[] {
  const pool = active(cards);
  const candidates: CardCandidate[] = pool.map((card) => ({
    id: card.id,
    isMissedQuestion: card.kind === "choice" && missedPrompts.has(card.front),
    isDue: dueAt(card) <= now.getTime(),
    isNew: card.state === "new",
    position: card.position,
  }));
  const ids = pickCards(candidates, CIRCLE_CARD_COUNT, pickingSeed(lessonId.toUpperCase(), "cards", String(doneCount)));
  const byId = new Map(pool.map((card) => [card.id, card]));
  return ids.map((id) => byId.get(id)).filter((card): card is T => card !== undefined);
}

/** Une séance de révision : les cartes dues d'abord, puis des nouvelles, quinze au plus. */
export const NEW_CARDS_PER_SESSION = 15;
/** Une séance ne dépasse pas trente cartes. */
export const SESSION_CAP = 30;

export function studyQueue<T extends LessonCard>(cards: readonly T[], now = new Date()): T[] {
  const pool = active(cards);
  const due = pool
    .filter((card) => card.state !== "new" && dueAt(card) <= now.getTime())
    .sort((a, b) => dueAt(a) - dueAt(b));
  const fresh = pool
    .filter((card) => card.state === "new")
    .sort((a, b) => a.position - b.position)
    .slice(0, NEW_CARDS_PER_SESSION);
  return [...due, ...fresh].slice(0, SESSION_CAP);
}

/** Les cartes de la leçon à revoir aujourd'hui. */
export function dueCards<T extends LessonCard>(cards: readonly T[], now = new Date()): T[] {
  return active(cards)
    .filter((card) => card.state !== "new" && dueAt(card) <= now.getTime())
    .sort((a, b) => dueAt(a) - dueAt(b));
}

/** Où en est une carte, en trois mots que tout le monde comprend. */
export type CardMastery = "new" | "learning" | "mastered";
export const CARD_MASTERIES: readonly CardMastery[] = ["new", "learning", "mastered"];
/** Ancrée : son prochain rappel est à trois semaines ou plus. */
export const MASTERED_INTERVAL_DAYS = 21;

export function cardMastery(card: Pick<LessonCard, "state" | "intervalDays">): CardMastery {
  if (card.state === "new") return "new";
  return card.intervalDays >= MASTERED_INTERVAL_DAYS ? "mastered" : "learning";
}

export function masteryCounts(cards: readonly LessonCard[]): Record<CardMastery, number> {
  const counts: Record<CardMastery, number> = { new: 0, learning: 0, mastered: 0 };
  for (const card of cards) counts[cardMastery(card)] += 1;
  return counts;
}

/** Ce qu'une question ratée écrit comme carte. */
export interface MissedCardDraft {
  front: string;
  back: string;
  kind: "choice" | "basic";
  choices: string[];
  correctChoiceIndex: number;
}

/**
 * **Une question ratée devient une flashcard à revoir demain.** Un QCM garde ses
 * propositions ; un ordre ou une association se révise en recto verso : la question, et au dos
 * la bonne réponse en clair, puis pourquoi.
 */
export function missedCardDraft(question: QuizQuestion): MissedCardDraft {
  switch (question.kind) {
    case "choice":
    case "truefalse":
    case "gap":
      return {
        front: question.prompt,
        back: question.why,
        kind: "choice",
        choices: question.choices,
        correctChoiceIndex: question.answer,
      };
    case "order":
    case "match":
      return {
        front: question.prompt,
        back: [answerText(question), question.why].filter((part) => part.length > 0).join("\n\n"),
        kind: "basic",
        choices: [],
        correctChoiceIndex: 0,
      };
  }
}

/** Le début du jour suivant : l'échéance d'une carte faite d'une question ratée. */
export function tomorrowStart(now = new Date()): Date {
  const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  return next;
}

/** Vrai pour une carte déjà faite de cette question : ratée une seconde fois, elle revient. */
export function isCardOfQuestion(card: Pick<LessonCard, "front" | "kind">, question: QuizQuestion): boolean {
  return card.front === question.prompt && (card.kind === "choice" || card.kind === "basic");
}
