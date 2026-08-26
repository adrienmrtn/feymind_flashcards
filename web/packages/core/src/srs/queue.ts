/**
 * L'ordre d'une session, porté depuis `Micabo/SRS/StudyQueue.swift`.
 *
 * L'ordre d'Anki : l'apprentissage en retard d'abord, puis les révisions, puis les cartes
 * neuves. Les cartes sous échéance d'examen font exception au plafond de cartes neuves — sans
 * cette exception, le plan annoncé à la confirmation serait un mensonge : il promet quarante
 * cartes aujourd'hui, et le rythme quotidien n'en laisserait passer que huit. Le plafond garde
 * tout son sens hors examen, où il n'y a pas de date à tenir.
 */

import { newCardsPerDay, DEFAULT_DAILY_MINUTES } from "./daily-load";
import type { ExamDeadlines } from "./exam";
import { NO_DEADLINES } from "./exam";
import type { CardState } from "./types";

/** Ce dont la file a besoin pour ordonner une carte, et rien de plus. */
export interface QueueCard {
  id: string;
  state: CardState;
  dueDate: Date;
  position: number;
  createdAt: Date;
  isSuspended: boolean;
}

export interface QueueLimits {
  newPerSession: number;
  reviewsPerSession: number;
}

export const DEFAULT_LIMITS: QueueLimits = { newPerSession: 20, reviewsPerSession: 200 };
export const UNLIMITED: QueueLimits = {
  newPerSession: Number.MAX_SAFE_INTEGER,
  reviewsPerSession: Number.MAX_SAFE_INTEGER,
};

/**
 * Plafond issu du rythme quotidien : c'est ce qui rend le réglage utile. Les révisions dues ne
 * sont pas rationnées, seule l'introduction de cartes neuves l'est.
 */
export function dailyLimits(dailyMinutes: number = DEFAULT_DAILY_MINUTES): QueueLimits {
  return {
    newPerSession: newCardsPerDay(dailyMinutes),
    reviewsPerSession: Number.MAX_SAFE_INTEGER,
  };
}

/** Répartition des cartes à réviser, affichée en haut des sessions. */
export interface StudyCounts {
  newCards: number;
  learning: number;
  review: number;
  total: number;
}

export function isDue(card: QueueCard, now: Date): boolean {
  if (card.isSuspended) return false;
  return card.dueDate.getTime() <= now.getTime();
}

export function buildQueue(
  cards: QueueCard[],
  options: { now?: Date; limits?: QueueLimits; deadlines?: ExamDeadlines } = {},
): QueueCard[] {
  const now = options.now ?? new Date();
  const limits = options.limits ?? DEFAULT_LIMITS;
  const deadlines = options.deadlines ?? NO_DEADLINES;

  const due = cards.filter((card) => isDue(card, now));

  const learning = due
    .filter((card) => card.state === "learning" || card.state === "relearning")
    .sort((first, second) => first.dueDate.getTime() - second.dueDate.getTime());

  const reviews = due
    .filter((card) => card.state === "review")
    .sort((first, second) =>
      byDeadline(
        deadlines.get(first.id) ?? null,
        first.dueDate,
        deadlines.get(second.id) ?? null,
        second.dueDate,
      ),
    )
    .slice(0, limits.reviewsPerSession);

  const newCards = due.filter((card) => card.state === "new");
  const examNewCards = newCards.filter((card) => deadlines.has(card.id)).sort(byPosition);
  const otherNewCards = newCards
    .filter((card) => !deadlines.has(card.id))
    .sort(byPosition)
    .slice(0, limits.newPerSession);

  return [...learning, ...reviews, ...examNewCards, ...otherNewCards];
}

export function studyCounts(
  cards: QueueCard[],
  options: { now?: Date; limits?: QueueLimits; deadlines?: ExamDeadlines } = {},
): StudyCounts {
  const queue = buildQueue(cards, options);
  const newCards = queue.filter((card) => card.state === "new").length;
  const learning = queue.filter(
    (card) => card.state === "learning" || card.state === "relearning",
  ).length;
  const review = queue.filter((card) => card.state === "review").length;
  return { newCards, learning, review, total: newCards + learning + review };
}

function byPosition(first: QueueCard, second: QueueCard): number {
  if (first.position !== second.position) return first.position - second.position;
  return first.createdAt.getTime() - second.createdAt.getTime();
}

/**
 * Une carte sous échéance passe devant, et l'échéance la plus proche devant les autres. À
 * égalité, l'ordre reste celui d'Anki : la plus en retard d'abord.
 */
function byDeadline(
  firstDeadline: Date | null,
  firstDue: Date,
  secondDeadline: Date | null,
  secondDue: Date,
): number {
  if (firstDeadline && secondDeadline) {
    if (firstDeadline.getTime() === secondDeadline.getTime()) {
      return firstDue.getTime() - secondDue.getTime();
    }
    return firstDeadline.getTime() - secondDeadline.getTime();
  }
  if (firstDeadline) return -1;
  if (secondDeadline) return 1;
  return firstDue.getTime() - secondDue.getTime();
}
