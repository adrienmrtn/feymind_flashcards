import {
  dayDifference,
  feasibility,
  levers,
  loadBars,
  masteryForCourses,
  minutesForCards,
  planTerm,
  resolveEmoji,
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
import { loadCardDifficulty } from "@/lib/data/difficulty";
import { readProfile } from "@/lib/data/profile";
import { getTranslator } from "@/lib/i18n/server";

/**
 * Le Plan : **l'écran qui répond à « est-ce que je vais y arriver ».**
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

  const [exams, courses, snapshots, availability, difficulties, profile] = await Promise.all([
    listExams(),
    listCourses(),
    listCardSnapshots(),
    readAvailability(),
    loadCardDifficulty(),
    readProfile(),
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
  }));

  const plan = planTerm({ exams: termExams, cards: termCards, availability, now });
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

      return {
        id: exam.id,
        name: exam.name,
        examDate: exam.exam_date,
        daysRemaining: dayDifference(today, new Date(`${exam.exam_date}T12:00:00`)),
        courseIds,
        masteryPercent: mastery.percent,
        projectedPercent: projectedMastery(mastery.percent, plan.passesByExam.get(exam.id) ?? 0, mastery.cardCount),
        cardCount: mastery.cardCount,
        isPlanned: exam.is_planned,
      };
    })
    .sort((left, right) => left.daysRemaining - right.daysRemaining);

  const blocks: PlanTodayBlock[] = todayBlocks(plan).map((block) => {
    const course = block.courseId ? titles.get(block.courseId) : undefined;
    return {
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

  return (
    <>
      <header>
        <h1 className="text-lg font-semibold tracking-tight text-foreground">
          {t("app.plan.title")}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">{t("app.plan.lead")}</p>
      </header>

      <PlanWorkspace
        bars={bars}
        verdict={verdict}
        levers={levers(plan, verdict)}
        exams={planExams}
        todayBlocks={blocks}
        todayMinutes={minutesForCards(todayCards)}
        todayCards={todayCards}
        weeklyMinutes={weeklyTotal(availability.weekly)}
        countryCode={profile?.country_code}
        courses={mine.map((course) => ({
          id: course.id,
          title: course.title,
          emoji: resolveEmoji(course.emoji, course.subject, course.title),
          cardCount: cardCounts.get(course.id) ?? 0,
        }))}
        cards={snapshots.map((card) => ({
          id: card.id,
          courseId: card.course_id,
          state: card.state,
          intervalDays: card.interval_days,
          dueDate: card.due_date,
          isSuspended: card.is_suspended,
        }))}
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
