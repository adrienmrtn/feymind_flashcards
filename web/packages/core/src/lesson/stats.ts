import { currentCircle, type PathCircle, pathProgress } from "./path-layout";
import { type LessonProgress, totalSeconds } from "./types";

/**
 * **Les trois chiffres de Home** : le temps passé à réviser, les leçons apprises, les
 * flashcards apprises. Tout est mesuré, rien n'est estimé. Jumeau de `HomeStats.swift`.
 */
export interface HomeStats {
  /** Le temps passé dans Notes, Quiz et Flashcards, toutes leçons confondues. */
  seconds: number;
  /** Les leçons arrivées à « Leçon terminée ». */
  learnedLessons: number;
  /** Les cartes dont le prochain rappel est à plus de sept jours. */
  learnedCards: number;
}

export interface StatsCard {
  state: string;
  dueDate: Date;
  isSuspended: boolean;
}

export const LEARNED_CARD_DAYS = 7;

/** Les flashcards apprises : celles dont le prochain rappel est à plus de sept jours. */
export function learnedCardCount(cards: readonly StatsCard[], now = new Date()): number {
  const horizon = now.getTime() + LEARNED_CARD_DAYS * 24 * 3600 * 1000;
  let count = 0;
  for (const card of cards) {
    if (!card.isSuspended && card.state !== "new" && card.dueDate.getTime() > horizon) count += 1;
  }
  return count;
}

export function homeStats(
  lessons: readonly { progress: LessonProgress }[],
  cards: readonly StatsCard[],
  now = new Date(),
): HomeStats {
  let seconds = 0;
  let learnedLessons = 0;
  for (const lesson of lessons) {
    seconds += totalSeconds(lesson.progress);
    if (lesson.progress.finishedAt !== null) learnedLessons += 1;
  }
  return { seconds, learnedLessons, learnedCards: learnedCardCount(cards, now) };
}

/**
 * « 12 min » sous l'heure, « 1,5 h » sous dix heures, « 14 h » au-delà : le nombre et son
 * unité, à formater dans la langue de l'interface (`lesson.home.minutes`, `lesson.home.hours`).
 */
export function studyTime(seconds: number): { unit: "minutes"; value: number } | { unit: "hours"; value: number } {
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return { unit: "minutes", value: minutes };
  const hours = seconds / 3600;
  return { unit: "hours", value: hours < 10 ? Math.round(hours * 10) / 10 : Math.round(hours) };
}

/** **« Reprendre »** : la dernière leçon ouverte, et l'étape où elle attend. */
export interface ResumeTarget {
  lessonId: string;
  title: string;
  circleNumber: number | null;
  circleTitle: string | null;
  percent: number;
}

export interface ResumeCandidate {
  id: string;
  title: string;
  lastOpenedAt: Date | null;
  circles: readonly PathCircle[];
  done: readonly string[];
}

/**
 * La leçon ouverte le plus récemment, terminée ou non : c'est celle qu'on veut retrouver. Un
 * cours jamais ouvert dans la refonte ne compte pas.
 */
export function resumeTarget(lessons: readonly ResumeCandidate[]): ResumeTarget | null {
  let best: ResumeCandidate | null = null;
  for (const lesson of lessons) {
    if (!lesson.lastOpenedAt) continue;
    if (!best || (best.lastOpenedAt && lesson.lastOpenedAt.getTime() > best.lastOpenedAt.getTime())) best = lesson;
  }
  if (!best) return null;
  const current = currentCircle(best.circles, best.done);
  return {
    lessonId: best.id,
    title: best.title,
    circleNumber: current?.number ?? null,
    circleTitle: current?.title ?? null,
    percent: pathProgress(best.circles, best.done).percent,
  };
}
