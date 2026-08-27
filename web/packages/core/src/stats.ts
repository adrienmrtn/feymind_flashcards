/**
 * Statistiques de révision : la série, le record, et le niveau de chaque carte.
 *
 * Porté depuis `Micabo/SRS/StudyStats.swift`. Une série reste valide tant que
 * la veille a été travaillée : rien aujourd'hui ne la casse. Le record se
 * calcule sur tout l'historique, pas sur une fenêtre.
 */

import { addDays, startOfDay } from "./srs/exam";
import { isMature, type CardState } from "./srs/types";

export type KnowledgeLevel = "new" | "learning" | "review" | "mastered";

export const KNOWLEDGE_LEVELS: readonly KnowledgeLevel[] = [
  "new",
  "learning",
  "review",
  "mastered",
];

export const KNOWLEDGE_LEVEL_LABELS: Record<KnowledgeLevel, string> = {
  new: "Nouvelles",
  learning: "En cours",
  review: "En révision",
  mastered: "Parfaitement maîtrisées",
};

export interface KnowledgeCard {
  state: CardState;
  intervalDays: number;
}

export interface KnowledgeBucket {
  id: KnowledgeLevel;
  label: string;
  count: number;
}

export interface ReviewedCard {
  id: string;
  front: string;
  passes: number;
}

/** Nombre de jours consécutifs avec au moins une révision, aujourd'hui inclus ou non. */
export function streak(reviewDates: readonly Date[], now: Date = new Date()): number {
  if (reviewDates.length === 0) return 0;

  const days = new Set(reviewDates.map((date) => startOfDay(date).getTime()));
  let cursor = startOfDay(now).getTime();

  if (!days.has(cursor)) {
    const yesterday = addDays(startOfDay(now), -1).getTime();
    if (!days.has(yesterday)) return 0;
    cursor = yesterday;
  }

  let count = 0;
  while (days.has(cursor)) {
    count += 1;
    cursor = addDays(new Date(cursor), -1).getTime();
  }
  return count;
}

/** La plus longue série jamais tenue, aujourd'hui comprise. */
export function bestStreak(reviewDates: readonly Date[]): number {
  if (reviewDates.length === 0) return 0;

  const days = [...new Set(reviewDates.map((date) => startOfDay(date).getTime()))].sort(
    (first, second) => first - second,
  );
  let best = 1;
  let run = 1;

  for (let index = 1; index < days.length; index += 1) {
    const previous = days[index - 1];
    const day = days[index];
    if (previous == null || day == null) continue;
    if (day === addDays(new Date(previous), 1).getTime()) {
      run += 1;
      best = Math.max(best, run);
    } else {
      run = 1;
    }
  }
  return best;
}

export function knowledgeLevel(card: KnowledgeCard): KnowledgeLevel {
  if (isMature(card.intervalDays)) return "mastered";
  if (card.state === "new") return "new";
  if (card.state === "learning" || card.state === "relearning") return "learning";
  return "review";
}

export function knowledgeDistribution(cards: readonly KnowledgeCard[]): KnowledgeBucket[] {
  const counts: Record<KnowledgeLevel, number> = {
    new: 0,
    learning: 0,
    review: 0,
    mastered: 0,
  };
  for (const card of cards) {
    counts[knowledgeLevel(card)] += 1;
  }
  return KNOWLEDGE_LEVELS.map((id) => ({
    id,
    label: KNOWLEDGE_LEVEL_LABELS[id],
    count: counts[id],
  }));
}

export function mostReviewedCards(
  logs: readonly { cardId: string | null }[],
  cards: readonly { id: string; front: string }[],
  limit = 5,
): ReviewedCard[] {
  const fronts = new Map(cards.map((card) => [card.id, card.front]));
  const counts = new Map<string, number>();

  for (const log of logs) {
    if (!log.cardId || !fronts.has(log.cardId)) continue;
    counts.set(log.cardId, (counts.get(log.cardId) ?? 0) + 1);
  }

  return [...counts.entries()]
    .sort((first, second) => second[1] - first[1] || first[0].localeCompare(second[0]))
    .slice(0, limit)
    .map(([id, passes]) => ({
      id,
      front: fronts.get(id) ?? "",
      passes,
    }));
}

/** « 12 vues · 3 ajouts » — les deux compteurs publics d'un cours. */
export function courseAudienceLabel(viewCount: number, adoptCount: number): string {
  const views = viewCount <= 1 ? `${viewCount} vue` : `${viewCount} vues`;
  const adopts = adoptCount <= 1 ? `${adoptCount} ajout` : `${adoptCount} ajouts`;
  return `${views} · ${adopts}`;
}
