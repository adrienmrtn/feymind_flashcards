import {
  LEARN_AHEAD_SECONDS,
  activeDeadlines,
  buildQueue,
  sessionNewLimit,
} from "@micabo/core";

import { ReviewSetup } from "@/components/app/ReviewSetup";
import { Session } from "@/components/app/Session";
import {
  listAllCards,
  listCardSnapshots,
  listCards,
  listCourses,
  listExams,
  type CardSnapshotRow,
  type CourseRow,
  type ExamRow,
} from "@/lib/data/courses";
import { examMarksFor } from "@/lib/data/exam-marks";
import { readEntitlement } from "@/lib/data/entitlement";
import { loadNewCardBudget } from "@/lib/data/reviews";

/**
 * La session, **et l'écran qui la précède.**
 *
 * `?cours=<id>` restreint la session à un cours. La file reste construite par le
 * **même `buildQueue`**, seulement sur un sous-ensemble de cartes. Le plafond de
 * neuves est celui du **jour** : une session depuis un cours consomme le même
 * budget que Réviser.
 *
 * L'anticipation d'Anki (dix minutes) ne s'applique **que** si la session a
 * déjà commencé (`?go=1`). Sans ça, refermer une session rouvrait tout de suite
 * les cartes d'apprentissage qu'on venait de noter.
 *
 * **L'écran d'avant ne lit plus les cartes en entier.** Il compte ce qui est dû, donc il lui
 * faut des échéances et des états - pas les recto, les verso, les indices ni les schémas de
 * toutes les cartes du compte. C'était la lecture la plus lourde de l'app, faite à chaque
 * clic sur Réviser, pour afficher un nombre : l'instantané mis en cache dit la même chose.
 * Le contenu n'arrive qu'avec la session (`?go=1`), et pour un seul cours quand c'en est un.
 */
export default async function ReviewPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;
  const courseId = typeof params.cours === "string" ? params.cours : null;
  const started = params.go === "1";
  const override = parseNewOverride(params.neuves);

  if (!started) {
    const [snapshots, courses, exams, right, budget] = await Promise.all([
      listCardSnapshots(),
      listCourses(),
      listExams(),
      readEntitlement(),
      loadNewCardBudget(),
    ]);

    return (
      <Setup
        courseId={courseId}
        cards={courseId ? snapshots.filter((card) => card.course_id === courseId) : snapshots}
        courses={courses}
        exams={exams}
        budget={budget}
        isPro={right.isPro}
      />
    );
  }

  const [allCards, courses, exams, right, budget] = await Promise.all([
    courseId ? listCards(courseId) : listAllCards(),
    listCourses(),
    listExams(),
    readEntitlement(),
    loadNewCardBudget(),
  ]);

  const cards = courseId ? allCards.filter((card) => card.course_id === courseId) : allCards;
  const now = new Date();
  const newPerSession = sessionNewLimit({
    dailyMinutes: budget.minutes,
    introducedToday: budget.introducedToday,
    override,
  });

  // Une session en cours doit survivre à un rechargement : les cartes notées
  // « 1 min » ou « 10 min » restent dans **cette** file. Ce n'est pas une
  // invitation à en ouvrir une nouvelle.
  const horizon = new Date(now.getTime() + LEARN_AHEAD_SECONDS * 1000);
  const deadlines = activeDeadlines(
    exams.map((exam) => ({
      date: new Date(`${exam.exam_date}T12:00:00`),
      isPlanned: exam.is_planned,
      courseIds: exam.course_ids ?? [],
    })),
    cards.map((card) => ({
      id: card.id,
      courseId: card.course_id,
      isSuspended: card.is_suspended,
    })),
    now,
  );

  const queue = buildQueue(
    cards.map((card) => ({
      id: card.id,
      state: card.state,
      dueDate: new Date(card.due_date),
      position: card.position,
      createdAt: new Date(card.created_at),
      isSuspended: card.is_suspended,
    })),
    {
      now: horizon,
      limits: { newPerSession, reviewsPerSession: Number.MAX_SAFE_INTEGER },
      deadlines,
    },
  );

  const byId = new Map(cards.map((card) => [card.id, card]));
  const titles = new Map(courses.map((course) => [course.id, course.title]));
  const marks = examMarksFor(exams, cards);

  const ordered = queue
    .map((item) => byId.get(item.id))
    .filter((card): card is NonNullable<typeof card> => Boolean(card))
    .map((card) => ({
      id: card.id,
      front: card.front,
      back: card.back,
      hint: card.hint,
      kind: card.kind,
      choices: card.choices ?? [],
      answerIndex: card.correct_choice_index,
      courseTitle: card.course_id ? (titles.get(card.course_id) ?? null) : null,
      exam: marks.get(card.id) ?? null,
      imagePath: card.image_path,
      maskX: card.mask_x ?? 0,
      maskY: card.mask_y ?? 0,
      maskWidth: card.mask_width ?? 0,
      maskHeight: card.mask_height ?? 0,
      snapshot: {
        state: card.state,
        intervalDays: card.interval_days,
        easeFactor: card.ease_factor,
        repetitions: card.repetitions,
        lapses: card.lapses,
        stepIndex: card.step_index,
        dueDate: card.due_date,
      },
    }));

  if (ordered.length === 0) {
    return (
      <Setup
        courseId={courseId}
        cards={cards}
        courses={courses}
        exams={exams}
        budget={budget}
        isPro={right.isPro}
      />
    );
  }

  const dueNew = cards.filter(
    (card) => !card.is_suspended && card.state === "new" && new Date(card.due_date) <= now,
  ).length;

  return (
    <Session
      cards={ordered}
      isPro={right.isPro}
      leftoverNew={Math.max(0, dueNew - newPerSession)}
    />
  );
}

/**
 * L'écran d'avant, écrit une fois.
 *
 * Il se rend depuis deux endroits - on arrive sur Réviser, ou la file s'avère vide - et les
 * deux appels étaient recopiés à l'identique.
 */
function Setup({
  courseId,
  cards,
  courses,
  exams,
  budget,
  isPro,
}: {
  courseId: string | null;
  cards: readonly CardSnapshotRow[];
  courses: readonly CourseRow[];
  exams: readonly ExamRow[];
  budget: { rhythmNew: number; introducedToday: number; remaining: number };
  isPro: boolean;
}) {
  return (
    <ReviewSetup
      courseId={courseId}
      cards={cards.map((card) => ({
        id: card.id,
        courseId: card.course_id,
        state: card.state,
        dueDate: card.due_date,
        position: card.position,
        createdAt: card.created_at,
        isSuspended: card.is_suspended,
      }))}
      courses={courses.map((course) => ({
        id: course.id,
        title: course.title,
        emoji: course.emoji,
        subject: course.subject,
      }))}
      exams={exams.map((exam) => ({
        date: exam.exam_date,
        isPlanned: exam.is_planned,
        courseIds: exam.course_ids ?? [],
      }))}
      rhythmNew={budget.rhythmNew}
      introducedToday={budget.introducedToday}
      remaining={budget.remaining}
      isPro={isPro}
    />
  );
}

function parseNewOverride(raw: string | string[] | undefined): number | null {
  if (typeof raw !== "string" || raw === "") return null;
  const value = Number(raw);
  if (!Number.isFinite(value)) return null;
  return Math.max(0, Math.round(value));
}
