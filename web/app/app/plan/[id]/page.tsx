import { notFound } from "next/navigation";
import Link from "next/link";

import {
  asExamKind,
  asStartingPoint,
  dayDifference,
  examCountdownLabel,
  examReadiness,
  isMockBlock,
  isReviewBlock,
  masteryByCourse,
  masteryForCourses,
  mockQuestionCount,
  mockScore,
  planTerm,
  resolveEmoji,
  startOfDay,
  weakCards,
  type TermCard,
  type TermExam,
} from "@micabo/core";

import { ExamProgress } from "@/components/app/plan/ExamProgress";
import { ExamSchedule, type ScheduleDay } from "@/components/app/plan/ExamSchedule";
import { ExamSheet, type SheetCourse } from "@/components/app/plan/ExamSheet";
import { listCardSnapshots, listCourses, listExams } from "@/lib/data/courses";
import { loadCardDifficulty } from "@/lib/data/difficulty";
import { listMockResults, loadThroughput } from "@/lib/data/mocks";
import { getTranslator } from "@/lib/i18n/server";
import { projectedMastery } from "@/lib/term-plan";

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

  const [exams, courses, snapshots, difficulties, mocks, throughput] = await Promise.all([
    listExams(),
    listCourses(),
    listCardSnapshots(),
    loadCardDifficulty(),
    listMockResults(),
    loadThroughput(),
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

  // Le plan complet, puis la part qui concerne cette épreuve : les jours se lisent dans le
  // même emploi du temps que le reste, sinon la page promettrait un temps déjà pris ailleurs.
  const now = new Date();
  const today = startOfDay(now);
  const plan = planTerm({
    exams: exams.map(
      (row): TermExam => ({
        id: row.id,
        name: row.name,
        examDate: new Date(`${row.exam_date}T12:00:00`),
        intensity:
          row.intensity === "light" || row.intensity === "intense" ? row.intensity : "standard",
        courseIds: row.course_ids ?? [],
        formats: row.formats ?? [],
        kind: asExamKind(row.kind),
        startingPoint: asStartingPoint(row.starting_point),
      }),
    ),
    cards: snapshots.map(
      (card): TermCard => ({
        id: card.id,
        courseId: card.course_id,
        kind: card.kind,
        state: card.state,
        intervalDays: card.interval_days,
        dueDate: new Date(card.due_date),
        isSuspended: card.is_suspended,
      }),
    ),
    now,
    throughput,
    difficulties,
    mocks,
  });

  const schedule: ScheduleDay[] = plan.days
    .filter((day) => day.offset <= Math.max(0, daysRemaining))
    .map((day) => {
      const mine = day.blocks.filter((block) => block.examId === exam.id);
      const mock = mine.find(isMockBlock);
      const cards = mine
        .filter(isReviewBlock)
        .reduce((sum, block) => sum + block.cardIds.length, 0);

      return {
        offset: day.offset,
        date: day.date.toISOString().slice(0, 10),
        cards,
        minutes: mine.filter(isReviewBlock).reduce((sum, block) => sum + block.minutes, 0),
        mock: mock ? { questionCount: mock.questionCount, minutes: mock.minutes } : null,
        isExamDay: day.offset === daysRemaining,
      };
    });

  const mine = mocks
    .filter((mock) => mock.examId === exam.id)
    .sort((left, right) => right.finishedAt.getTime() - left.finishedAt.getTime());

  const readiness = examReadiness({
    masteryPercent: overall.percent,
    projectedPercent: projectedMastery(overall.percent, plan.passesByExam.get(exam.id) ?? 0, overall.cardCount),
    mocks,
    examId: exam.id,
    now,
  });

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
        <p className="text-[12.5px] font-medium text-ink-tertiary">
          <Link href={"/app/plan" as never} className="underline-draw">
            {t("nav.exams")}
          </Link>
        </p>
        <div className="mt-1 flex flex-wrap items-center justify-between gap-3">
          <h1 className="page-title">{exam.name}</h1>
          <span className="numeral rounded-full bg-caution-soft px-2.5 py-1 text-[12px] font-semibold text-caution">
            {examCountdownLabel(daysRemaining)}
          </span>
        </div>
        <p className="page-lead">
          {t("app.plan.sheet.lead", {
            percent: overall.percent,
            cards: overall.cardCount,
          })}
        </p>
      </header>

      <ExamProgress
        masteryPercent={overall.percent}
        projectedPercent={readiness.percent}
        measured={readiness.measured}
        mockScore={readiness.mockScore}
        cardCount={overall.cardCount}
        daysRemaining={daysRemaining}
        targetScore={exam.target_score}
        mocks={mine.slice(0, 8).map((mock) => ({
          id: mock.id,
          score: mockScore(mock),
          questionCount: mock.questionCount,
          finishedAt: mock.finishedAt.toISOString().slice(0, 10),
        }))}
      />

      {daysRemaining >= 0 ? (
        <ExamSchedule
          examId={exam.id}
          days={schedule}
          canRunMock={mockQuestionCount(overall.cardCount) > 0}
        />
      ) : null}

      <ExamSheet
        examId={exam.id}
        kind={asExamKind(exam.kind)}
        formats={exam.formats ?? []}
        courses={sheetCourses}
        weak={weak}
        availableKinds={[...kinds]}
        canRunMock={mockQuestionCount(overall.cardCount) > 0}
        mocks={mocks
          .filter((mock) => mock.examId === exam.id)
          .map((mock) => ({
            id: mock.id,
            score: mockScore(mock),
            questionCount: mock.questionCount,
            finishedAt: mock.finishedAt.toISOString().slice(0, 10),
          }))}
      />
    </>
  );
}

