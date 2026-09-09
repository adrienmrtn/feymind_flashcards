import {
  adherenceFrom,
  capacityFor,
  dayDifference,
  examReadiness,
  feasibility,
  isMockBlock,
  levers,
  loadBars,
  masteryForCourses,
  planTerm,
  resolveEmoji,
  asExamKind,
  asStartingPoint,
  startOfDay,
  todayBlocks,
  todayCardCount,
  weeklyTotal,
  type TermCard,
  type TermExam,
} from "@micabo/core";

import { PlanWorkspace, type PlanExam, type PlanTodayBlock } from "@/components/app/plan/PlanWorkspace";
import { readAvailability } from "@/lib/data/availability";
import { listCardSnapshots, listCourses, listExams } from "@/lib/data/courses";
import { loadCardDifficulty, loadDailyReviews } from "@/lib/data/difficulty";
import { listMockResults, loadThroughput } from "@/lib/data/mocks";
import { readProfile } from "@/lib/data/profile";
import { getTranslator } from "@/lib/i18n/server";

/**
 * **La page centrale du produit : le plan.**
 *
 * L'accueil listait des cartes dues, c'est-à-dire une file d'attente. Il répond maintenant à
 * la question qui amène l'étudiant ici - « est-ce que je vais y arriver » - parce que c'est
 * elle qui distingue ce produit d'un jeu de flashcards. Les cartes, les cours et les
 * statistiques n'ont pas disparu : ils sont devenus les moyens, et ils vivent derrière.
 *
 *
 * Tout est calculé ici, à chaque rendu, et rien n'est stocké. Un plan est une **fonction** des
 * épreuves, des cartes, du journal de révision et du temps disponible : le mettre en table
 * obligerait à l'invalider à chaque note donnée, c'est-à-dire des dizaines de fois par
 * session, pour économiser un calcul qui tient dans quelques millisecondes. Le jour où le
 * volume l'exigera, `plan_days` existe pour ça - pas avant.
 *
 * Les quatre lectures sont déjà en cache et partagées avec le tableau de bord : ouvrir le
 * Plan après l'accueil ne touche pas la base.
 */
export default async function PlanPage() {
  const now = new Date();
  const today = startOfDay(now);
  const { t } = await getTranslator();

  const [
    exams,
    courses,
    snapshots,
    availability,
    difficulties,
    profile,
    throughput,
    mocks,
    daily,
  ] = await Promise.all([
    listExams(),
    listCourses(),
    listCardSnapshots(),
    readAvailability(),
    loadCardDifficulty(),
    readProfile(),
    loadThroughput(),
    listMockResults(),
    loadDailyReviews(30),
  ]);

  // Le plan se règle sur ce que cet étudiant fait réellement : son débit, et la part de son
  // temps déclaré qu'il tient. Sans mesure, les deux retombent sur le comportement d'avant.
  const adherence = adherenceFrom(
    daily,
    (date) => capacityFor(availability, date),
    throughput,
    now,
  );

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
    availability,
    now,
    throughput,
    adherence,
    mocks,
    difficulties,
  });
  const verdict = feasibility(plan);
  const bars = loadBars(plan);

  const titles = new Map(courses.map((course) => [course.id, course]));
  const cardCounts = new Map<string, number>();
  for (const card of snapshots) {
    if (!card.course_id || card.is_suspended) continue;
    cardCounts.set(card.course_id, (cardCounts.get(card.course_id) ?? 0) + 1);
  }

  const planExams: PlanExam[] = exams
    .map((exam) => {
      const courseIds = exam.course_ids ?? [];
      const mastery = masteryForCourses(
        snapshots.map((card) => ({
          id: card.id,
          courseId: card.course_id,
          state: card.state,
          intervalDays: card.interval_days,
          isSuspended: card.is_suspended,
        })),
        difficulties,
        courseIds,
      );

      // Un blanc passé l'emporte sur la projection : une formule qui annonce 88 % contre un
      // score mesuré à 54 a tort, et c'est le score qu'il faut croire.
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
      };
    })
    .sort((left, right) => left.daysRemaining - right.daysRemaining);

  const blocks: PlanTodayBlock[] = todayBlocks(plan).map((block) => {
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

  const todayCards = todayCardCount(plan);
  const mine = courses.filter((course) => !course.is_from_library);
  const greeting = profile?.display_name?.trim().split(/\s+/)[0] ?? null;

  return (
    <>
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold tracking-tight text-foreground">
            {greeting ? greeting : t("app.plan.title")}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">{t("app.plan.lead")}</p>
        </div>
      </header>

      <PlanWorkspace
        bars={bars}
        verdict={verdict}
        levers={levers(plan, verdict)}
        exams={planExams}
        todayBlocks={blocks}
        todayMinutes={plan.days[0]?.minutes ?? 0}
        adherence={adherence}
        throughput={throughput}
        todayCards={todayCards}
        weeklyMinutes={weeklyTotal(availability.weekly)}
        courses={mine.map((course) => ({ id: course.id, title: course.title }))}
      />
    </>
  );
}

/**
 * Où la maîtrise arrivera le jour J, si le plan est suivi.
 *
 * Chaque passage prévu rapproche le programme de son plafond, avec un rendement décroissant :
 * le premier passage sur une carte neuve vaut beaucoup, le quatrième presque rien. On ne
 * promet jamais 100 % - il resterait toujours des cartes que l'étudiant rate.
 */
function projectedMastery(current: number, passes: number, cardCount: number): number {
  if (cardCount === 0) return current;
  const perCard = passes / cardCount;
  const gain = (100 - current) * (1 - Math.exp(-perCard / 1.8));
  return Math.min(97, Math.round(current + gain));
}

function asIntensity(value: string): "light" | "standard" | "intense" {
  return value === "light" || value === "intense" ? value : "standard";
}
