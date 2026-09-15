import { notFound } from "next/navigation";
import Link from "next/link";

import {
  asExamKind,
  asStartingPoint,
  dayDifference,
  examAgenda,
  examCountdownLabel,
  examReadiness,
  isReviewBlock,
  masteryByCourse,
  masteryForCourses,
  mockQuestionCount,
  mockScore,
  planTerm,
  resolveEmoji,
  startOfDay,
  targetPercent,
  weakCards,
  TERM_HORIZON_DAYS,
  type AgendaEvent,
  type TermCard,
  type TermExam,
} from "@micabo/core";

import { ExamProgress } from "@/components/app/plan/ExamProgress";
import { ExamSchedule, type ScheduleDay } from "@/components/app/plan/ExamSchedule";
import { ExamSheet, type SheetCourse } from "@/components/app/plan/ExamSheet";
import { listCardSnapshots, listCourses, listExams } from "@/lib/data/courses";
import { loadCardDifficulty } from "@/lib/data/difficulty";
import {
  listExamOverrides,
  listMeasuresDone,
  listMockResults,
  loadThroughput,
} from "@/lib/data/mocks";
import { listOffDays, offDayOffsets } from "@/lib/data/off-days";
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

  const [exams, courses, snapshots, difficulties, mocks, throughput, offDays, measures, overrides] =
    await Promise.all([
      listExams(),
      listCourses(),
      listCardSnapshots(),
      loadCardDifficulty(),
      listMockResults(),
      loadThroughput(),
      listOffDays(),
      listMeasuresDone(),
      listExamOverrides(),
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
    // Le même agenda que l'accueil et que le téléphone : les tests honorés ne se reposent pas,
    // et une date choisie à la main tient d'un écran à l'autre.
    parcours: measures,
    overrides,
    offDays: offDayOffsets(offDays, today, TERM_HORIZON_DAYS),
  });

  /**
   * Les rendez-vous de cette épreuve, lus depuis l'agenda plutôt que depuis les blocs du plan.
   *
   * Le plan ne porte que les rendez-vous **à venir** - c'est tout ce dont il a besoin pour
   * remplir une journée - alors que la case doit aussi savoir le rang du rendez-vous, s'il a
   * déjà été honoré, et s'il a été déplacé. L'agenda dit les quatre, et c'est lui que l'app
   * lit : les deux écrans posent donc les mêmes jours.
   */
  const agendaExam = {
    id: exam.id,
    name: exam.name,
    examDate: new Date(`${exam.exam_date}T12:00:00`),
    kind: asExamKind(exam.kind),
    cardCount: overall.cardCount,
  };
  const events = examAgenda({ exams: [agendaExam], done: measures, overrides, now });

  /**
   * Où la dérivation aurait posé chaque rendez-vous, sans les choix de l'étudiant.
   *
   * Sert au seul « remettre à la date prévue » : sans ce second calcul, on saurait qu'un
   * rendez-vous a été déplacé sans pouvoir dire d'où, et le bouton promettrait un retour vers
   * une date que personne ne connaît.
   */
  const derived = new Map(
    examAgenda({ exams: [agendaExam], done: measures, now }).map(
      (event) => [`${event.kind}:${event.slot}`, event] as const,
    ),
  );

  const measureOn = (day: Date): AgendaEvent | undefined =>
    events.find((event) => event.date.getTime() === day.getTime());

  const schedule: ScheduleDay[] = plan.days
    .filter((day) => day.offset <= Math.max(0, daysRemaining))
    .map((day) => {
      const mine = day.blocks
        .filter((block) => block.examId === exam.id)
        .filter(isReviewBlock);
      const event = measureOn(day.date);
      const planned = event ? derived.get(`${event.kind}:${event.slot}`) : undefined;

      return {
        offset: day.offset,
        date: day.date.toISOString().slice(0, 10),
        cards: mine.reduce((sum, block) => sum + block.cardIds.length, 0),
        minutes: mine.reduce((sum, block) => sum + block.minutes, 0),
        measure: event
          ? {
              kind: event.kind,
              slot: event.slot,
              status: event.status,
              questionCount: event.questionCount,
              minutes: event.minutes,
              plannedDate:
                event.moved && planned ? planned.date.toISOString().slice(0, 10) : null,
            }
          : null,
        isExamDay: day.offset === daysRemaining,
        isOff: day.isOff,
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
        measured={readiness.measured}
        mockScore={readiness.mockScore}
        cardCount={overall.cardCount}
        daysRemaining={daysRemaining}
        targetScore={targetPercent(exam.target_score)}
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
        courses={sheetCourses}
        weak={weak}
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

