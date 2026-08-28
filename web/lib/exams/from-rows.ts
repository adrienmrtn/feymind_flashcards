import {
  buildExamInsight,
  clampTargetScore,
  targetScoreFromIntensity,
  type ExamInsight,
  type ExamIntensity,
  type InsightCard,
  type InsightReview,
} from "@micabo/core";

import type { CardSnapshotRow, ExamRow } from "@/lib/data/courses";

export function insightCardsFromSnapshots(cards: CardSnapshotRow[]): InsightCard[] {
  return cards.map((card) => ({
    id: card.id,
    courseId: card.course_id,
    front: card.front,
    kind: card.kind || "basic",
    state: card.state,
    intervalDays: card.interval_days,
    dueDate: new Date(card.due_date),
    lapses: card.lapses,
    isSuspended: card.is_suspended,
  }));
}

export function examInsightFromRow(
  exam: ExamRow,
  cards: InsightCard[],
  reviews: InsightReview[],
  options: { now?: Date; country?: string | null } = {},
): ExamInsight {
  return buildExamInsight({
    id: exam.id,
    name: exam.name,
    examDate: new Date(`${exam.exam_date}T12:00:00`),
    intensity: asIntensity(exam.intensity),
    targetScore:
      typeof exam.target_score === "number"
        ? clampTargetScore(exam.target_score)
        : targetScoreFromIntensity(asIntensity(exam.intensity)),
    courseIds: exam.course_ids ?? [],
    cards,
    reviews,
    now: options.now,
    country: options.country,
  });
}

function asIntensity(value: string): ExamIntensity {
  return value === "light" || value === "intense" || value === "standard" ? value : "standard";
}
