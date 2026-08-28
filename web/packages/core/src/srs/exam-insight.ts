/**
 * Ce que la carte d'examen montre : avancée, charge, courbes, points faibles.
 *
 * Ce n'est pas un décor. Les barres à gauche sont les révisions déjà faites, celles
 * à droite le plan. Les deux courbes partent du même point aujourd'hui : avec le
 * plan elles montent vers le jour J, sans lui elles redescendent.
 */

import { isMature, type CardState } from "./types";
import { desiredGradeLabel } from "./grade-scale";
import {
  addDays,
  dayDifference,
  planExam,
  startOfDay,
  type ExamIntensity,
} from "./exam";

export const EXAM_CHART_PAST_DAYS = 12;

export type WeakKind = "qcm" | "trou" | "schema" | "question";

export interface InsightCard {
  id: string;
  courseId: string | null;
  front: string;
  kind: string;
  state: CardState;
  intervalDays: number;
  dueDate: Date;
  lapses: number;
  isSuspended: boolean;
}

export interface InsightReview {
  cardId: string;
  at: Date;
}

export interface ExamInsightInput {
  id: string;
  name: string;
  examDate: Date;
  intensity: ExamIntensity;
  targetScore: number;
  courseIds: string[];
  cards: readonly InsightCard[];
  reviews: readonly InsightReview[];
  now?: Date;
  country?: string | null;
}

export interface ExamWeakPoint {
  id: string;
  kind: WeakKind;
  kindLabel: string;
  prompt: string;
  note: string;
}

export interface ExamChart {
  /** Décalage depuis aujourd'hui, un cran par barre. */
  offsets: number[];
  reviews: number[];
  withMicabo: number[];
  without: number[];
  todayIndex: number;
  examIndex: number;
}

export interface ExamInsight {
  id: string;
  name: string;
  daysRemaining: number;
  gradeLabel: string;
  learnedPct: number;
  cardCount: number;
  chart: ExamChart;
  weak: ExamWeakPoint[];
}

export function buildExamInsight(input: ExamInsightInput): ExamInsight {
  const now = input.now ?? new Date();
  const today = startOfDay(now);
  const examDay = startOfDay(input.examDate);
  const daysRemaining = dayDifference(today, examDay);
  const ids = new Set(input.courseIds);
  const cards = input.cards.filter(
    (card) => card.courseId && ids.has(card.courseId) && !card.isSuspended,
  );
  const cardIds = new Set(cards.map((card) => card.id));
  const reviews = input.reviews.filter((review) => cardIds.has(review.cardId));

  const learnedPct = learnedPercent(cards);
  const readinessNow = averageReadiness(cards);
  const plan =
    daysRemaining >= 0
      ? planExam(
          cards.map((card) => ({
            id: card.id,
            state: card.state,
            intervalDays: card.intervalDays,
            dueDate: card.dueDate,
          })),
          examDay,
          { now, intensity: input.intensity },
        )
      : null;

  const readinessExam = plan ? projectedReadiness(cards, plan.days) : readinessNow;
  const readinessWithout =
    daysRemaining <= 0
      ? readinessNow
      : Math.max(8, Math.round(readinessNow * Math.exp(-daysRemaining / 8)));

  const offsets = chartOffsets(daysRemaining);
  const todayIndex = offsets.indexOf(0);
  const examIndex = offsets.lastIndexOf(Math.max(0, daysRemaining));

  const pastCounts = reviewsByOffset(reviews, today, EXAM_CHART_PAST_DAYS);
  const reviewsBars = offsets.map((offset) => {
    if (offset < 0) return pastCounts.get(offset) ?? 0;
    if (offset === daysRemaining && daysRemaining > 0) return 0;
    if (offset === 0) {
      const done = pastCounts.get(0) ?? 0;
      const planned = plan?.projection.load[0] ?? 0;
      return Math.max(done, planned);
    }
    return plan?.projection.load[offset] ?? 0;
  });

  const withMicabo = offsets.map((offset) =>
    sampleCurve(offset, daysRemaining, readinessNow, readinessExam),
  );
  const without = offsets.map((offset) =>
    sampleCurve(offset, daysRemaining, readinessNow, readinessWithout),
  );

  return {
    id: input.id,
    name: input.name.trim() || "Examen",
    daysRemaining,
    gradeLabel: desiredGradeLabel(input.targetScore, input.country),
    learnedPct,
    cardCount: cards.length,
    chart: {
      offsets,
      reviews: reviewsBars,
      withMicabo,
      without,
      todayIndex: todayIndex < 0 ? 0 : todayIndex,
      examIndex: examIndex < 0 ? offsets.length - 1 : examIndex,
    },
    weak: weakPoints(cards, now),
  };
}

export function learnedPercent(cards: readonly InsightCard[]): number {
  if (cards.length === 0) return 0;
  const started = cards.filter((card) => card.state !== "new").length;
  return Math.round((started / cards.length) * 100);
}

export function cardKindLabel(kind: string): { id: WeakKind; label: string } {
  if (kind === "choice") return { id: "qcm", label: "QCM" };
  if (kind === "cloze") return { id: "trou", label: "Trou" };
  if (kind === "occlusion") return { id: "schema", label: "Schéma" };
  return { id: "question", label: "Question" };
}

export function weakNote(card: InsightCard, now: Date): string {
  if (card.lapses > 0) {
    return card.lapses === 1 ? "1 oubli" : `${card.lapses} oublis`;
  }
  if (card.state === "new") return "Nouvelle";
  if (startOfDay(card.dueDate).getTime() <= startOfDay(now).getTime()) {
    return "Encore due";
  }
  return "Fragile";
}

function weakPoints(cards: readonly InsightCard[], now: Date): ExamWeakPoint[] {
  return [...cards]
    .sort((left, right) => weakScore(right, now) - weakScore(left, now) || left.id.localeCompare(right.id))
    .filter((card) => weakScore(card, now) > 0)
    .slice(0, 3)
    .map((card) => {
      const kind = cardKindLabel(card.kind);
      return {
        id: card.id,
        kind: kind.id,
        kindLabel: kind.label,
        prompt: card.front.trim() || "Carte sans question",
        note: weakNote(card, now),
      };
    });
}

function weakScore(card: InsightCard, now: Date): number {
  let score = card.lapses * 100;
  if (card.state === "new") score += 20;
  if (startOfDay(card.dueDate).getTime() <= startOfDay(now).getTime()) score += 30;
  if (card.state === "relearning") score += 40;
  if (card.state === "learning") score += 10;
  if (card.intervalDays > 0 && card.intervalDays < 4) score += 8;
  return score;
}

function readinessOf(card: InsightCard): number {
  if (card.state === "new") return 0;
  if (card.state === "learning" || card.state === "relearning") return 36;
  if (isMature(card.intervalDays)) return 92;
  return 68;
}

function averageReadiness(cards: readonly InsightCard[]): number {
  if (cards.length === 0) return 0;
  const total = cards.reduce((sum, card) => sum + readinessOf(card), 0);
  return Math.round(total / cards.length);
}

function projectedReadiness(
  cards: readonly InsightCard[],
  days: ReadonlyMap<string, number[]>,
): number {
  if (cards.length === 0) return 0;
  const total = cards.reduce((sum, card) => {
    const passes = days.get(card.id)?.length ?? 0;
    const now = readinessOf(card);
    if (passes === 0) return sum + now;
    if (card.state === "new") return sum + Math.min(82, 48 + passes * 10);
    return sum + Math.min(98, now + passes * 6);
  }, 0);
  return Math.round(total / cards.length);
}

/**
 * La fenêtre du graphe : douze jours derrière, puis jusqu'à l'examen.
 * Au-delà de six jours devant, on garde aujourd'hui, deux points, le jour J.
 */
export function chartOffsets(daysRemaining: number): number[] {
  const past = Array.from({ length: EXAM_CHART_PAST_DAYS }, (_, index) => index - EXAM_CHART_PAST_DAYS);
  if (daysRemaining <= 0) return [...past, 0];
  if (daysRemaining <= 6) {
    return [...past, ...Array.from({ length: daysRemaining + 1 }, (_, index) => index)];
  }
  const mid = [
    Math.max(1, Math.round(daysRemaining / 3)),
    Math.max(2, Math.round((daysRemaining * 2) / 3)),
  ];
  const future = [...new Set([0, ...mid, daysRemaining])].sort((left, right) => left - right);
  return [...past, ...future];
}

function sampleCurve(
  offset: number,
  daysRemaining: number,
  today: number,
  end: number,
): number {
  if (offset <= 0) {
    const span = EXAM_CHART_PAST_DAYS;
    const t = (offset + span) / span;
    const start = Math.max(0, Math.round(today * 0.82));
    return Math.round(start + (today - start) * t);
  }
  if (daysRemaining <= 0) return today;
  const t = Math.min(1, offset / daysRemaining);
  const eased = 1 - (1 - t) ** 2;
  return Math.round(today + (end - today) * eased);
}

function reviewsByOffset(
  reviews: readonly InsightReview[],
  today: Date,
  pastDays: number,
): Map<number, number> {
  const counts = new Map<number, number>();
  for (const review of reviews) {
    const offset = dayDifference(today, startOfDay(review.at));
    if (offset < -pastDays || offset > 0) continue;
    counts.set(offset, (counts.get(offset) ?? 0) + 1);
  }
  return counts;
}
