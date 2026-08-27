/**
 * L'ordre d'une session, porté depuis `Micabo/SRS/StudyQueue.swift`.
 *
 * L'ordre d'Anki : l'apprentissage en retard d'abord, puis les révisions, puis les cartes
 * neuves. Les cartes sous échéance d'examen passent **devant** les autres neuves, mais elles
 * restent dans le plafond du jour : une session depuis un cours et la session globale
 * partagent le même budget. Sans ça, réviser huit cartes neuves depuis un cours laisserait
 * la page Réviser en promettre encore cinq.
 */

import { newCardsPerDay, DEFAULT_DAILY_MINUTES } from "./daily-load";
import { addDays, NO_DEADLINES, startOfDay, type ExamDeadlines } from "./exam";
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

/** Plus haut cran du curseur de cartes neuves, au-delà du rythme quotidien. */
export const SESSION_NEW_SLIDER_CAP = 60;

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

/** Combien de cartes neuves on peut encore introduire aujourd'hui, rythme moins déjà vues. */
export function remainingNewCards(
  introducedToday: number,
  dailyMinutes: number = DEFAULT_DAILY_MINUTES,
): number {
  return Math.max(0, newCardsPerDay(dailyMinutes) - Math.max(0, introducedToday));
}

/**
 * Plafond de **cette** session. Un override vient du curseur ; sinon on sert le reste
 * du rythme, pour qu'une session depuis un cours compte comme une session normale.
 */
export function sessionNewLimit(options: {
  dailyMinutes?: number;
  introducedToday: number;
  override?: number | null;
}): number {
  if (options.override != null && Number.isFinite(options.override)) {
    return Math.max(0, Math.round(options.override));
  }
  return remainingNewCards(options.introducedToday, options.dailyMinutes);
}

/** Le curseur commence au rythme, et peut monter un peu au-dessus. */
export function sessionNewSliderMax(rhythmNew: number): number {
  return Math.max(20, Math.min(SESSION_NEW_SLIDER_CAP, Math.max(rhythmNew * 2, rhythmNew)));
}

export interface NewIntroductionEvent {
  stateBefore: string;
  reviewedAt: Date;
}

/**
 * Cartes passées de « neuve » à autre chose aujourd'hui. On compte les faits, pas l'état
 * actuel : une carte déjà notée n'est plus `new`, mais elle a bien consommé le budget.
 */
export function countNewIntroducedToday(
  events: readonly NewIntroductionEvent[],
  now: Date = new Date(),
): number {
  const start = startOfDay(now).getTime();
  const end = addDays(startOfDay(now), 1).getTime();
  let count = 0;
  for (const event of events) {
    if (event.stateBefore !== "new") continue;
    const at = event.reviewedAt.getTime();
    if (at >= start && at < end) count += 1;
  }
  return count;
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
  const otherNewCards = newCards.filter((card) => !deadlines.has(card.id)).sort(byPosition);
  // L'examen choisit l'ordre, pas le volume : le budget du jour s'applique à toutes.
  const introduced = [...examNewCards, ...otherNewCards].slice(0, limits.newPerSession);

  return [...learning, ...reviews, ...introduced];
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
