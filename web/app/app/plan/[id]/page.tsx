import { notFound } from "next/navigation";
import Link from "next/link";

import {
  asExamKind,
  dayDifference,
  examCountdownLabel,
  masteryByCourse,
  masteryForCourses,
  resolveEmoji,
  startOfDay,
  weakCards,
} from "@micabo/core";

import { ExamSheet, type SheetCourse } from "@/components/app/plan/ExamSheet";
import { listCardSnapshots, listCourses, listExams } from "@/lib/data/courses";
import { loadCardDifficulty } from "@/lib/data/difficulty";
import { getTranslator } from "@/lib/i18n/server";

/** Combien de points faibles on montre : au-delà, la liste cesse d'être une liste d'actions. */
const WEAK_SHOWN = 6;

/**
 * La fiche d'une épreuve.
 *
 * Elle répond à deux questions que le Plan ne peut pas poser sans se charger : **où j'en suis
 * sur cette épreuve**, et **sur quoi je me plante**. La seconde n'existait nulle part dans le
 * produit : l'état de répétition disait ce que l'algorithme croit, jamais ce que l'étudiant a
 * réellement répondu.
 */
export default async function ExamSheetPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const { t } = await getTranslator();

  const [exams, courses, snapshots, difficulties] = await Promise.all([
    listExams(),
    listCourses(),
    listCardSnapshots(),
    loadCardDifficulty(),
  ]);

  const exam = exams.find((row) => row.id === id);
  if (!exam) notFound();

  const courseIds = exam.course_ids ?? [];
  const daysRemaining = dayDifference(
    startOfDay(new Date()),
    startOfDay(new Date(`${exam.exam_date}T12:00:00`)),
  );

  const masteryCards = snapshots.map((card) => ({
    id: card.id,
    courseId: card.course_id,
    state: card.state,
    intervalDays: card.interval_days,
    isSuspended: card.is_suspended,
  }));

  const overall = masteryForCourses(masteryCards, difficulties, courseIds);
  const byCourse = masteryByCourse(masteryCards, difficulties);

  const counts = new Map<string, number>();
  const kinds = new Set<string>();
  for (const card of snapshots) {
    if (!card.course_id || card.is_suspended) continue;
    if (!courseIds.includes(card.course_id)) continue;
    counts.set(card.course_id, (counts.get(card.course_id) ?? 0) + 1);
    kinds.add(card.kind);
  }

  const sheetCourses: SheetCourse[] = courseIds
    .map((courseId) => courses.find((course) => course.id === courseId))
    .filter((course): course is NonNullable<typeof course> => Boolean(course))
    .map((course) => ({
      id: course.id,
      title: course.title,
      emoji: resolveEmoji(course.emoji, course.subject, course.title),
      cardCount: counts.get(course.id) ?? 0,
      masteryPercent: byCourse.get(course.id)?.percent ?? 0,
    }));

  const weak = weakCards(
    snapshots.map((card) => ({
      id: card.id,
      courseId: card.course_id,
      front: card.front,
      kind: card.kind,
      state: card.state,
      intervalDays: card.interval_days,
      lapses: card.lapses,
      isSuspended: card.is_suspended,
    })),
    difficulties,
    { courseIds, limit: WEAK_SHOWN },
  );

  return (
    <>
      <header>
        <p className="eyebrow text-ink-tertiary">
          <Link href={"/app/plan" as never} className="underline-draw">
            {t("app.plan.title")}
          </Link>
        </p>
        <div className="mt-1 flex flex-wrap items-baseline justify-between gap-3">
          <h1 className="text-lg font-semibold tracking-tight text-foreground">{exam.name}</h1>
          <span className="numeral rounded-pill bg-caution-soft px-2.5 py-1 text-[12px] font-semibold text-caution">
            {examCountdownLabel(daysRemaining)}
          </span>
        </div>
        <p className="mt-1 text-sm text-muted-foreground">
          {t("app.plan.sheet.lead", {
            percent: overall.percent,
            cards: overall.cardCount,
          })}
        </p>
      </header>

      <ExamSheet
        examId={exam.id}
        kind={asExamKind(exam.kind)}
        formats={exam.formats ?? []}
        courses={sheetCourses}
        weak={weak}
        availableKinds={[...kinds]}
      />
    </>
  );
}
