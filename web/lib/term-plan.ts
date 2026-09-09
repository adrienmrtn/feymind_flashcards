import "server-only";

import {
  asExamKind,
  asStartingPoint,
  dayDifference,
  examReadiness,
  isMockBlock,
  loadBars,
  masteryForCourses,
  planTerm,
  resolveEmoji,
  startOfDay,
  termLoad,
  TERM_HORIZON_DAYS,
  todayBlocks,
  todayCardCount,
  type LoadBar,
  type TermCard,
  type TermExam,
  type TermLoad,
  type TermPlan,
  type Throughput,
} from "@micabo/core";

import {
  listCardSnapshots,
  listCourses,
  listExams,
  type CardSnapshotRow,
  type CourseRow,
  type ExamRow,
} from "@/lib/data/courses";
import { loadCardDifficulty } from "@/lib/data/difficulty";
import { listMockResults, loadThroughput } from "@/lib/data/mocks";
import { listOffDays, offDayOffsets, weeklyOffOffsets } from "@/lib/data/off-days";
import { readProfile, type ProfileRow } from "@/lib/data/profile";
import { getTranslator } from "@/lib/i18n/server";

/**
 * Le plan de la période, calculé une fois pour les écrans qui en vivent.
 *
 * L'accueil en montre le jour, le hub des examens en montre la période : c'est le même
 * calcul, sur les mêmes lectures (toutes en cache), et le garder à un seul endroit évite que
 * les deux écrans ne finissent par dire deux choses différentes.
 */

export interface PlanExam {
  id: string;
  name: string;
  examDate: string;
  daysRemaining: number;
  courseIds: string[];
  masteryPercent: number;
  projectedPercent: number;
  measured: boolean;
  mockScore: number | null;
  cardCount: number;
  isPlanned: boolean;
  targetScore: number | null;
}

export interface PlanTodayBlock {
  kind: "review" | "mock";
  courseId: string | null;
  courseTitle: string;
  emoji: string;
  examId: string;
  examName: string;
  cards: number;
  minutes: number;
}

export interface TermSnapshot {
  now: Date;
  today: Date;
  plan: TermPlan;
  load: TermLoad;
  bars: LoadBar[];
  exams: PlanExam[];
  upcoming: PlanExam[];
  blocks: PlanTodayBlock[];
  todayCards: number;
  todayMinutes: number;
  throughput: Throughput;
  courses: CourseRow[];
  snapshots: CardSnapshotRow[];
  rawExams: ExamRow[];
  profile: ProfileRow | null;
}

export async function loadTermSnapshot(): Promise<TermSnapshot> {
  const now = new Date();
  const today = startOfDay(now);
  const { t } = await getTranslator();

  const [exams, courses, snapshots, difficulties, profile, throughput, mocks, offDays] =
    await Promise.all([
      listExams(),
      listCourses(),
      listCardSnapshots(),
      loadCardDifficulty(),
      readProfile(),
      loadThroughput(),
      listMockResults(),
      listOffDays(),
    ]);

  const termCards: TermCard[] = snapshots.map((card) => ({
    id: card.id,
    courseId: card.course_id,
    kind: card.kind,
    state: card.state,
    intervalDays: card.interval_days,
    dueDate: new Date(card.due_date),
    isSuspended: card.is_suspended,
  }));

  const termExams: TermExam[] = exams.map((exam) => ({
    id: exam.id,
    name: exam.name,
    examDate: new Date(`${exam.exam_date}T12:00:00`),
    intensity: asIntensity(exam.intensity),
    courseIds: exam.course_ids ?? [],
    formats: exam.formats ?? [],
    kind: asExamKind(exam.kind),
    startingPoint: asStartingPoint(exam.starting_point),
  }));

  const plan = planTerm({
    exams: termExams,
    cards: termCards,
    now,
    throughput,
    mocks,
    difficulties,
    // L'habitude de la semaine et les dates posées à la main, ensemble. La première vient du
    // parcours d'inscription : sans cette ligne, répondre « jamais le dimanche » n'aurait
    // aucune suite, et le plan poserait du travail le dimanche jusqu'à ce qu'on le lui
    // interdise date par date.
    offDays: [
      ...new Set([
        ...offDayOffsets(offDays, today, TERM_HORIZON_DAYS),
        ...weeklyOffOffsets(profile?.weekly_minutes ?? null, today, TERM_HORIZON_DAYS),
      ]),
    ],
  });
  /**
   * Une carte encore à faire : due, et pas mise de côté.
   *
   * C'est exactement ce que la session de révision servira. Compter autrement ferait dire à
   * l'accueil un nombre que le bouton « Réviser » ne tient pas.
   */
  const dueById = new Map(snapshots.map((card) => [card.id, card]));
  const pending = (cardId: string) => {
    const card = dueById.get(cardId);
    if (!card || card.is_suspended) return false;
    return new Date(card.due_date).getTime() <= now.getTime();
  };

  const load = termLoad(plan);
  const bars = loadBars(plan);
  const titles = new Map(courses.map((course) => [course.id, course]));

  const masteryCards = snapshots.map((card) => ({
    id: card.id,
    courseId: card.course_id,
    state: card.state,
    intervalDays: card.interval_days,
    isSuspended: card.is_suspended,
  }));

  const planExams: PlanExam[] = exams
    .map((exam) => {
      const courseIds = exam.course_ids ?? [];
      const mastery = masteryForCourses(masteryCards, difficulties, courseIds);
      const readiness = examReadiness({
        masteryPercent: mastery.percent,
        projectedPercent: projectedMastery(
          mastery.percent,
          plan.passesByExam.get(exam.id) ?? 0,
          mastery.cardCount,
        ),
        mocks,
        examId: exam.id,
        now,
      });
      return {
        id: exam.id,
        name: exam.name,
        examDate: exam.exam_date,
        daysRemaining: dayDifference(today, new Date(`${exam.exam_date}T12:00:00`)),
        courseIds,
        masteryPercent: mastery.percent,
        projectedPercent: readiness.percent,
        measured: readiness.measured,
        mockScore: readiness.mockScore,
        cardCount: mastery.cardCount,
        isPlanned: exam.is_planned,
        targetScore: exam.target_score,
      };
    })
    .sort((left, right) => left.daysRemaining - right.daysRemaining);

  const blocks: PlanTodayBlock[] = todayBlocks(plan, pending).map((block) => {
    if (isMockBlock(block)) {
      return {
        kind: "mock" as const,
        courseId: null,
        courseTitle: t("app.mock.blockTitle"),
        emoji: "⏱",
        examId: block.examId,
        examName: block.examName,
        cards: block.questionCount,
        minutes: block.minutes,
      };
    }
    const course = block.courseId ? titles.get(block.courseId) : undefined;
    return {
      kind: "review" as const,
      courseId: block.courseId,
      courseTitle: course?.title || t("app.course.untitled"),
      emoji: course ? resolveEmoji(course.emoji, course.subject, course.title) : "📘",
      examId: block.examId,
      examName: block.examName,
      cards: block.cardIds.length,
      minutes: block.minutes,
    };
  });

  return {
    now,
    today,
    plan,
    load,
    bars,
    exams: planExams,
    upcoming: planExams.filter((exam) => exam.daysRemaining >= 0),
    blocks,
    todayCards: todayCardCount(plan, pending),
    todayMinutes: plan.days[0]?.minutes ?? 0,
    throughput,
    courses,
    snapshots,
    rawExams: exams,
    profile,
  };
}

/**
 * Où la maîtrise arrivera le jour J, si le plan est suivi.
 *
 * Chaque passage prévu rapproche le programme de son plafond, avec un rendement décroissant :
 * le premier passage sur une carte neuve vaut beaucoup, le quatrième presque rien. On ne
 * promet jamais 100 % - il resterait toujours des cartes que l'étudiant rate.
 */
export function projectedMastery(current: number, passes: number, cardCount: number): number {
  if (cardCount === 0) return current;
  const perCard = passes / cardCount;
  const gain = (100 - current) * (1 - Math.exp(-perCard / 1.8));
  return Math.min(97, Math.round(current + gain));
}

function asIntensity(value: string): "light" | "standard" | "intense" {
  return value === "light" || value === "intense" ? value : "standard";
}
