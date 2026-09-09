import Link from "next/link";

import {
  addDays,
  courseAccent,
  examCountdownLabel,
  feasibility,
  isDue,
  masteryOf,
  minutesForCards,
  planTerm,
  resolveEmoji,
  startOfDay,
  studyStats,
  todayBlocks,
  todayCardCount,
  weakCards,
  weekStrip,
  WEEK_STRIP_RADIUS,
  type TermCard,
  type TermExam,
} from "@micabo/core";

import { MasteryCard } from "@/components/app/home/MasteryCard";
import { StatsRow } from "@/components/app/home/StatsRow";
import { Button } from "@/components/ui/button";
import { Card, CardAction, CardHeader, CardPanel, CardTitle } from "@/components/ui/card";
import { WeekStrip } from "@/components/app/WeekStrip";
import { readAvailability } from "@/lib/data/availability";
import {
  listCardSnapshots,
  listCourses,
  listExams,
  type CardSnapshotRow,
  type CourseRow,
} from "@/lib/data/courses";
import { loadCardDifficulty, loadDailyReviews } from "@/lib/data/difficulty";
import { readProfile } from "@/lib/data/profile";
import { loadNewCardBudget, loadReviewDatesSince } from "@/lib/data/reviews";
import { getTranslator } from "@/lib/i18n/server";
import type { UiLocale } from "@/lib/i18n/locales";
import type { Translator } from "@/lib/i18n/copy";

/**
 * Le tableau de bord : **le travail du jour, puis la mesure.**
 *
 * Trois changements de fond par rapport à la version qui listait des cartes dues.
 *
 * - **Le travail vient du plan**, pas de la file de révision seule. Ce sont les mêmes cartes,
 *   mais l'ordre est celui de la période : ce que trois épreuves se disputent ne se décide pas
 *   en regardant aujourd'hui isolément.
 * - **Chaque bloc dit pour quelle épreuve il existe.** « Biologie, 24 cartes » ne motive
 *   personne ; « Biologie pour le partiel du 14 » si.
 * - **Le social descend.** Le classement et les demandes d'amis vivent sur leur page. Ils
 *   étaient au même niveau visuel que le travail, ce qui n'a jamais été vrai.
 *
 * Sans aucune épreuve déclarée, le plan est vide et l'écran retombe sur les cartes dues :
 * personne n'est bloqué derrière la déclaration d'un examen.
 */
export default async function DashboardPage() {
  const now = new Date();
  const today = startOfDay(now);
  const { t, locale } = await getTranslator();

  const [courses, cards, exams, profile, budget, reviewDates, availability, difficulties, daily] =
    await Promise.all([
      listCourses(),
      listCardSnapshots(),
      listExams(),
      readProfile(),
      loadNewCardBudget(),
      loadReviewDatesSince(addDays(today, -WEEK_STRIP_RADIUS)),
      readAvailability(),
      loadCardDifficulty(),
      loadDailyReviews(),
    ]);

  const week = weekStrip(
    cards.map((card) => ({
      dueDate: new Date(card.due_date),
      isSuspended: card.is_suspended,
      state: card.state,
    })),
    reviewDates,
    now,
    { newRemaining: budget.remaining },
  );

  const plan = planTerm({
    exams: exams.map(toTermExam),
    cards: cards.map(toTermCard),
    availability,
    now,
  });
  const verdict = feasibility(plan);

  const mastery = masteryOf(
    cards.map((card) => ({
      id: card.id,
      courseId: card.course_id,
      state: card.state,
      intervalDays: card.interval_days,
      isSuspended: card.is_suspended,
    })),
    difficulties,
  );

  const stats = studyStats(daily, now);
  const titles = new Map(courses.map((course) => [course.id, course]));
  const planned = todayBlocks(plan);
  const plannedCards = todayCardCount(plan);

  const tasks = planned.length > 0
    ? planned.map((block) => {
        const course = block.courseId ? titles.get(block.courseId) : undefined;
        return {
          key: `${block.examId}:${block.courseId ?? "sans"}`,
          courseId: block.courseId,
          title: course?.title || t("app.course.untitled"),
          emoji: course ? resolveEmoji(course.emoji, course.subject, course.title) : "📘",
          count: block.cardIds.length,
          minutes: block.minutes,
          examName: block.examName,
        };
      })
    : dueByCourse(cards, courses, now, t);

  const weak = weakCards(
    cards.map((card) => ({
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
    { limit: 3 },
  );

  const nextExam = exams
    .map((exam) => ({
      id: exam.id,
      name: exam.name,
      days: Math.round(
        (startOfDay(new Date(`${exam.exam_date}T12:00:00`)).getTime() - today.getTime()) /
          86_400_000,
      ),
    }))
    .filter((exam) => exam.days >= 0)
    .sort((left, right) => left.days - right.days)[0];

  const name = profile?.display_name?.trim().split(/\s+/)[0];
  const totalMinutes = plannedCards > 0 ? minutesForCards(plannedCards) : 0;

  return (
    <>
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold tracking-tight text-foreground">
            {name ? name : t("app.home.titleFallback")}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">{greetingFor(now, t)}</p>
        </div>
        {nextExam ? (
          <Link
            href={"/app/plan" as never}
            className="hover-tile flex items-center gap-2 rounded-pill bg-caution-soft px-3 py-1.5"
          >
            <span className="truncate text-[13px] font-medium text-caution">{nextExam.name}</span>
            <span className="numeral text-[13px] font-semibold text-caution">
              {examCountdownLabel(nextExam.days)}
            </span>
          </Link>
        ) : null}
      </header>

      <TodayCard
        tasks={tasks}
        cardCount={cards.length}
        minutes={totalMinutes}
        fromPlan={planned.length > 0}
        tight={verdict.level === "short"}
        t={t}
      />

      <MasteryCard mastery={mastery} />

      <div className="grid min-w-0 items-stretch gap-4 lg:grid-cols-2">
        <div className="h-full min-w-0" data-tour="semaine">
          <WeekStrip days={week} locale={locale as UiLocale} t={t} />
        </div>
        <WeakCard weak={weak} t={t} />
      </div>

      <StatsRow stats={stats} daily={daily} />
    </>
  );
}

interface TodayTask {
  key: string;
  courseId: string | null;
  title: string;
  emoji: string;
  count: number;
  minutes: number;
  examName: string | null;
}

function TodayCard({
  tasks,
  cardCount,
  minutes,
  fromPlan,
  tight,
  t,
}: {
  tasks: TodayTask[];
  cardCount: number;
  minutes: number;
  fromPlan: boolean;
  tight: boolean;
  t: Translator;
}) {
  return (
    <Card data-tour="taches">
      <CardHeader className="pb-2">
        <CardTitle className="text-[15px] font-semibold text-ink">
          {t("app.home.tasks.title")}
        </CardTitle>
        {tasks.length > 0 ? (
          <CardAction>
            <Button size="sm" render={<Link href={"/app/reviser?go=1" as never} />}>
              {minutes > 0
                ? t("app.home.tasks.startMinutes", { minutes })
                : t("app.home.tasks.reviewAll")}
            </Button>
          </CardAction>
        ) : null}
      </CardHeader>
      <CardPanel className="pt-0">
        {tasks.length === 0 ? (
          <TodayEmpty cardCount={cardCount} t={t} />
        ) : (
          <>
            <ul className="divide-y divide-hairline">
              {tasks.map((task) => (
                <li key={task.key} className="flex items-center gap-3 py-3 first:pt-1 last:pb-0">
                  <Link
                    href={
                      (task.courseId ? `/app/c/${task.courseId}` : "/app/cours") as never
                    }
                    className="hover-row -mx-2 flex min-w-0 flex-1 items-center gap-3 rounded-tile px-2 py-1"
                  >
                    <span
                      aria-hidden
                      className="flex h-10 w-10 shrink-0 items-center justify-center rounded-tile text-[18px]"
                      style={{
                        backgroundColor: `${courseAccent(task.courseId ?? task.key)}1f`,
                      }}
                    >
                      {task.emoji}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-[15px] font-medium text-ink">
                        <span className="underline-draw">{task.title}</span>
                      </span>
                      <span className="numeral mt-0.5 block truncate text-[13px] text-ink-tertiary">
                        {task.examName
                          ? t("app.home.tasks.forExam", {
                              cards: task.count,
                              minutes: task.minutes,
                              exam: task.examName,
                            })
                          : t("app.home.tasks.dueCards", { count: task.count })}
                      </span>
                    </span>
                  </Link>
                  <Button
                    size="sm"
                    variant="outline"
                    render={
                      <Link
                        href={
                          (task.courseId
                            ? `/app/reviser?cours=${task.courseId}`
                            : "/app/reviser") as never
                        }
                      />
                    }
                  >
                    {t("app.review.verb")}
                  </Button>
                </li>
              ))}
            </ul>

            {fromPlan ? (
              <p className="mt-3 text-[12.5px] text-ink-tertiary">
                {tight ? (
                  <Link href={"/app/plan" as never} className="underline-draw text-caution">
                    {t("app.home.tasks.planTight")}
                  </Link>
                ) : (
                  t("app.home.tasks.fromPlan")
                )}
              </p>
            ) : null}
          </>
        )}
      </CardPanel>
    </Card>
  );
}

function TodayEmpty({ cardCount, t }: { cardCount: number; t: Translator }) {
  if (cardCount === 0) {
    return (
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-[15px] font-semibold text-ink">{t("app.home.empty.noCardsTitle")}</p>
          <p className="mt-0.5 text-[13px] text-ink-tertiary">{t("app.home.empty.noCardsBody")}</p>
        </div>
        <Button size="sm" render={<Link href={"/app/importer" as never} />}>
          {t("nav.import")}
        </Button>
      </div>
    );
  }

  return (
    <div className="flex flex-wrap items-center justify-between gap-3">
      <div>
        <p className="text-[15px] font-semibold text-ink">{t("app.home.empty.doneTitle")}</p>
        <p className="mt-0.5 text-[13px] text-ink-tertiary">{t("app.home.empty.doneTomorrow")}</p>
      </div>
      <Button variant="outline" size="sm" render={<Link href={"/app/reviser" as never} />}>
        {t("app.home.empty.reviewAgain")}
      </Button>
    </div>
  );
}

/**
 * Ce qui résiste, sur l'accueil.
 *
 * Trois cartes au plus : c'est une invitation à corriger, pas un rapport d'échec. La liste
 * complète vit sur la fiche de l'épreuve, là où on peut agir dessus.
 */
function WeakCard({
  weak,
  t,
}: {
  weak: { id: string; front: string; againCount: number; reviews: number }[];
  t: Translator;
}) {
  return (
    <section className="flex h-full min-w-0 flex-col rounded-group border border-border bg-card p-5">
      <h2 className="text-[15px] font-semibold text-ink">{t("app.home.weak.title")}</h2>
      {weak.length === 0 ? (
        <p className="mt-2 text-[13.5px] text-ink-secondary">{t("app.home.weak.none")}</p>
      ) : (
        <>
          <p className="mt-1 text-[13px] text-ink-secondary">{t("app.home.weak.lead")}</p>
          <ul className="mt-3 space-y-2">
            {weak.map((card) => (
              <li key={card.id} className="rounded-button bg-surface-muted px-3 py-2.5">
                <p className="line-clamp-2 text-[13.5px] text-ink">{card.front}</p>
                <p className="numeral mt-1 text-[12px] text-ink-tertiary">
                  {t("app.home.weak.line", {
                    again: card.againCount,
                    reviews: card.reviews,
                  })}
                </p>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  );
}

/** Sans épreuve déclarée, on retombe sur les cartes dues, groupées par cours. */
function dueByCourse(
  cards: CardSnapshotRow[],
  courses: CourseRow[],
  now: Date,
  t: Translator,
): TodayTask[] {
  const counts = new Map<string, number>();
  for (const card of cards) {
    if (!card.course_id) continue;
    const due = isDue(
      {
        id: card.id,
        state: card.state,
        dueDate: new Date(card.due_date),
        position: card.position,
        createdAt: new Date(card.created_at),
        isSuspended: card.is_suspended,
      },
      now,
    );
    if (due) counts.set(card.course_id, (counts.get(card.course_id) ?? 0) + 1);
  }

  return courses
    .filter((course) => (counts.get(course.id) ?? 0) > 0)
    .map((course) => ({
      key: course.id,
      courseId: course.id,
      title: course.title || t("app.course.untitled"),
      emoji: resolveEmoji(course.emoji, course.subject, course.title),
      count: counts.get(course.id) ?? 0,
      minutes: minutesForCards(counts.get(course.id) ?? 0),
      examName: null,
    }))
    .sort((left, right) => right.count - left.count);
}

function toTermCard(card: CardSnapshotRow): TermCard {
  return {
    id: card.id,
    courseId: card.course_id,
    kind: card.kind,
    state: card.state,
    intervalDays: card.interval_days,
    dueDate: new Date(card.due_date),
    isSuspended: card.is_suspended,
  };
}

function toTermExam(exam: {
  id: string;
  name: string;
  exam_date: string;
  intensity: string;
  course_ids: string[] | null;
  formats: string[] | null;
}): TermExam {
  return {
    id: exam.id,
    name: exam.name,
    examDate: new Date(`${exam.exam_date}T12:00:00`),
    intensity:
      exam.intensity === "light" || exam.intensity === "intense" ? exam.intensity : "standard",
    courseIds: exam.course_ids ?? [],
    formats: exam.formats ?? [],
  };
}

function greetingFor(now: Date, t: Translator): string {
  const hour = now.getHours();
  if (hour < 6) return t("app.home.greeting.night");
  if (hour < 12) return t("app.home.greeting.morning");
  if (hour < 18) return t("app.home.greeting.afternoon");
  return t("app.home.greeting.evening");
}
