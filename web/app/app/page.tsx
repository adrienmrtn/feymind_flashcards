import { Suspense } from "react";
import Link from "next/link";

import {
  activeDeadlines,
  addDays,
  buildQueue,
  courseAccent,
  isDue,
  resolveEmoji,
  startOfDay,
  weekStrip,
  WEEK_STRIP_RADIUS,
  type ExamInsight,
} from "@micabo/core";

import { ExamInsightCard } from "@/components/app/exams/ExamInsightCard";
import { Button } from "@/components/ui/button";
import { Card, CardAction, CardHeader, CardPanel, CardTitle } from "@/components/ui/card";
import { FriendActions } from "@/components/app/FriendActions";
import { WeekRanking } from "@/components/app/WeekRanking";
import { WeekStrip } from "@/components/app/WeekStrip";
import { examInsightFromRow, insightCardsFromSnapshots } from "@/lib/exams/from-rows";
import {
  listCardSnapshots,
  listCourses,
  listExams,
  listPendingFriendRequests,
  type CardSnapshotRow,
  type CourseRow,
  type ExamRow,
  type FriendRequestRow,
} from "@/lib/data/courses";
import { readProfile } from "@/lib/data/profile";
import { loadNewCardBudget, loadReviewDatesSince } from "@/lib/data/reviews";
import { listWeekReviewRanking } from "@/lib/data/social";
import { copyHeldBackNew } from "@/lib/i18n/copy";
import { getTranslator } from "@/lib/i18n/server";
import type { UiLocale } from "@/lib/i18n/locales";
import type { Translator } from "@/lib/i18n/copy";

/**
 * Le tableau de bord : les tâches d'abord, puis la semaine et les examens.
 *
 * Les tâches suivent **le rythme choisi**, pas toutes les cartes dues. Une
 * session qui vient de se terminer doit les actualiser tout de suite : c'est
 * `SessionDone` qui s'en charge en revenant ici, et non un rafraîchissement
 * posé sur la page. Monté sur la page, il refaisait **tout** le rendu serveur
 * à chaque arrivée - deux fois les données pour un seul écran.
 *
 * **Le classement attend derrière la page, pas devant.** C'est la lecture la plus lourde de
 * l'écran - un RPC qui remonte le cercle d'amis puis compte leurs passages - et c'est la
 * moins urgente : elle est sous la ligne de flottaison d'un téléphone, et la plupart du
 * temps elle ne rend rien. Dans le `Promise.all`, elle décidait à elle seule du moment où
 * les tâches du jour s'affichaient.
 */
export default async function DashboardPage() {
  const now = new Date();
  const today = startOfDay(now);
  const { t, locale } = await getTranslator();

  const [courses, cards, exams, friends, profile, budget, reviewDates] = await Promise.all([
    listCourses(),
    listCardSnapshots(),
    listExams(),
    listPendingFriendRequests(),
    readProfile(),
    loadNewCardBudget(),
    loadReviewDatesSince(addDays(today, -WEEK_STRIP_RADIUS)),
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

  const queue = todayQueue(cards, exams, now, budget.remaining);
  const tasks = tasksFromQueue(queue, cards, courses);
  const dueOutsideRhythm = countDue(cards, now) - queue.length;
  const upcoming = upcomingExamInsights(exams, cards, now, profile?.country_code);
  const greeting = greetingFor(now, t);
  const name = profile?.display_name?.trim().split(/\s+/)[0];

  return (
    <>
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold tracking-tight text-foreground">
            {name ? name : t("app.home.titleFallback")}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">{greeting}</p>
        </div>
      </header>

      <TodayTasks
        tasks={tasks}
        cardCount={cards.length}
        heldBack={Math.max(0, dueOutsideRhythm)}
        t={t}
      />

      <div className="grid min-w-0 items-stretch gap-4 lg:grid-cols-2">
        <div className="h-full min-w-0" data-tour="semaine">
          <WeekStrip days={week} locale={locale} t={t} />
        </div>
        <UpcomingExams next={upcoming[0] ?? null} others={Math.max(0, upcoming.length - 1)} t={t} />
      </div>

      <Suspense fallback={null}>
        <WeekRankingSection locale={locale} t={t} />
      </Suspense>

      <FriendsCard requests={friends} t={t} />
    </>
  );
}

/**
 * Rien en attendant, et c'est le bon squelette : le classement ne s'affiche qu'à partir de
 * deux personnes, donc un cadre vide se dresserait pour se retirer aussitôt chez la plupart.
 */
async function WeekRankingSection({
  locale,
  t,
}: {
  locale: UiLocale;
  t: Translator;
}) {
  const ranking = await listWeekReviewRanking();
  return <WeekRanking rows={ranking} locale={locale} t={t} />;
}

function TodayTasks({
  tasks,
  cardCount,
  heldBack,
  t,
}: {
  tasks: { course: CourseRow; due: number }[];
  cardCount: number;
  heldBack: number;
  t: Translator;
}) {
  return (
    <Card className="h-full" data-tour="taches">
      <CardHeader className="pb-2">
        <CardTitle className="text-[15px] font-semibold text-ink">{t("app.home.tasks.title")}</CardTitle>
        {tasks.length > 0 ? (
          <CardAction>
            <Button size="sm" render={<Link href={"/app/reviser?go=1" as never} />}>
              {t("app.home.tasks.reviewAll")}
            </Button>
          </CardAction>
        ) : null}
      </CardHeader>
      <CardPanel className="pt-0">
        {tasks.length > 0 ? (
          <ul className="divide-y divide-hairline">
            {tasks.map(({ course, due }) => (
              <li key={course.id} className="flex items-center gap-3 py-3 first:pt-1 last:pb-0">
                <span
                  aria-hidden
                  className="flex h-10 w-10 shrink-0 items-center justify-center rounded-tile text-[18px]"
                  style={{
                    backgroundColor: `${course.accent_hex ?? courseAccent(course.id)}1f`,
                  }}
                >
                  {resolveEmoji(course.emoji, course.subject, course.title)}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[15px] font-medium text-ink">
                    {course.title || t("app.course.untitled")}
                  </span>
                  <span className="numeral mt-0.5 block text-[13px] text-ink-tertiary">
                    {t("app.home.tasks.dueCards", { count: due })}
                  </span>
                </span>
                <Button
                  size="sm"
                  variant="outline"
                  render={<Link href={`/app/reviser?cours=${course.id}` as never} />}
                >
                  {t("app.review.verb")}
                </Button>
              </li>
            ))}
          </ul>
        ) : (
          <TodayEmpty cardCount={cardCount} heldBack={heldBack} t={t} />
        )}
      </CardPanel>
    </Card>
  );
}

function TodayEmpty({
  cardCount,
  heldBack,
  t,
}: {
  cardCount: number;
  heldBack: number;
  t: Translator;
}) {
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

  if (heldBack > 0) {
    return (
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-[15px] font-semibold text-ink">{t("app.home.empty.doneTitle")}</p>
          <p className="mt-0.5 text-[13px] text-ink-secondary">{copyHeldBackNew(t, heldBack)}</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button
            variant="outline"
            size="sm"
            render={<Link href={"/app/reviser" as never} />}
          >
            {t("app.home.empty.reviewAgain")}
          </Button>
          <Button
            variant="link"
            size="sm"
            className="h-auto px-0"
            render={<Link href={"/app/reglages" as never} />}
          >
            {t("app.home.empty.changePace")}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div>
      <p className="text-[15px] font-semibold text-ink">{t("app.home.empty.doneTitle")}</p>
      <p className="mt-0.5 text-[13px] text-ink-tertiary">{t("app.home.empty.doneTomorrow")}</p>
    </div>
  );
}

function UpcomingExams({
  next,
  others,
  t,
}: {
  next: ExamInsight | null;
  others: number;
  t: Translator;
}) {
  return (
    <section className="flex h-full min-h-0 min-w-0 flex-col" data-tour="examens">
      <div className="mb-3 flex min-w-0 items-end justify-between gap-3">
        <h2 className="min-w-0 text-[15px] font-semibold text-ink">{t("app.home.exams.title")}</h2>
        <Button
          variant="link"
          size="sm"
          className="h-auto shrink-0 px-0"
          render={<Link href={"/app/examens" as never} />}
        >
          {next ? t("app.home.exams.see") : t("app.home.exams.add")}
        </Button>
      </div>
      {next ? (
        <div className="min-h-0 min-w-0 flex-1">
          <ExamInsightCard insight={next} href={"/app/examens" as never} />
          {others > 0 ? (
            <p className="mt-3 text-[13px] text-ink-tertiary">
              <Link href={"/app/examens" as never} className="underline-draw">
                {others === 1
                  ? t("app.home.exams.oneOther")
                  : t("app.home.exams.otherCount", { count: others })}
              </Link>
            </p>
          ) : null}
        </div>
      ) : (
        <Card className="min-w-0 flex-1 overflow-hidden">
          <CardPanel className="flex h-full min-w-0 flex-col items-stretch gap-3 sm:flex-row sm:items-center sm:justify-between">
            <p className="min-w-0 text-[15px] font-medium text-ink">{t("app.home.exams.none")}</p>
            <Button size="sm" className="shrink-0 self-start sm:self-auto" render={<Link href={"/app/examens" as never} />}>
              {t("app.home.exams.add")}
            </Button>
          </CardPanel>
        </Card>
      )}
    </section>
  );
}

function FriendsCard({ requests, t }: { requests: FriendRequestRow[]; t: Translator }) {
  return (
    <Card data-tour="amis">
      <CardHeader className="pb-2">
        <CardTitle className="text-[15px] font-semibold text-ink">{t("app.home.friends.title")}</CardTitle>
        <CardAction>
          <Button variant="link" size="sm" className="h-auto px-0" render={<Link href={"/app/amis" as never} />}>
            {t("app.common.see")}
          </Button>
        </CardAction>
      </CardHeader>
      <CardPanel className="pt-0">
        {requests.length === 0 ? (
          <div className="flex flex-wrap items-center justify-between gap-3">
            <p className="text-[15px] font-medium text-ink">{t("app.home.friends.noPending")}</p>
            <Button size="sm" variant="outline" render={<Link href={"/app/amis" as never} />}>
              {t("app.common.add")}
            </Button>
          </div>
        ) : (
          <ul className="space-y-2">
            {requests.map((request) => (
              <li
                key={request.requesterId}
                className="flex items-center justify-between gap-3 rounded-button bg-surface-muted px-3 py-2.5"
              >
                <Link
                  href={`/app/u/${request.username ?? ""}` as never}
                  className="truncate text-[14.5px] font-medium text-ink"
                >
                  {request.username ? `@${request.username}` : t("app.home.friends.someone")}
                </Link>
                <FriendActions personId={request.requesterId} relation="awaitingMe" />
              </li>
            ))}
          </ul>
        )}
      </CardPanel>
    </Card>
  );
}

function todayQueue(
  cards: CardSnapshotRow[],
  exams: ExamRow[],
  now: Date,
  newRemaining: number,
) {
  const queueCards = cards.map((card) => ({
    id: card.id,
    state: card.state,
    dueDate: new Date(card.due_date),
    position: card.position,
    createdAt: new Date(card.created_at),
    isSuspended: card.is_suspended,
  }));

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

  return buildQueue(queueCards, {
    now,
    limits: { newPerSession: newRemaining, reviewsPerSession: Number.MAX_SAFE_INTEGER },
    deadlines,
  });
}

function tasksFromQueue(
  queue: { id: string }[],
  cards: CardSnapshotRow[],
  courses: CourseRow[],
): { course: CourseRow; due: number }[] {
  const byId = new Map(cards.map((card) => [card.id, card]));
  const counts = new Map<string, number>();

  for (const item of queue) {
    const courseId = byId.get(item.id)?.course_id;
    if (!courseId) continue;
    counts.set(courseId, (counts.get(courseId) ?? 0) + 1);
  }

  return courses
    .filter((course) => (counts.get(course.id) ?? 0) > 0)
    .map((course) => ({ course, due: counts.get(course.id) ?? 0 }))
    .sort((left, right) => right.due - left.due);
}

function countDue(cards: CardSnapshotRow[], now: Date): number {
  return cards.filter((card) =>
    isDue(
      {
        id: card.id,
        state: card.state,
        dueDate: new Date(card.due_date),
        position: card.position,
        createdAt: new Date(card.created_at),
        isSuspended: card.is_suspended,
      },
      now,
    ),
  ).length;
}

function upcomingExamInsights(
  exams: ExamRow[],
  cards: CardSnapshotRow[],
  now: Date,
  country?: string | null,
): ExamInsight[] {
  const snapshots = insightCardsFromSnapshots(cards);
  return exams
    .map((exam) => examInsightFromRow(exam, snapshots, [], { now, country }))
    .filter((exam) => exam.daysRemaining >= 0)
    .sort((left, right) => left.daysRemaining - right.daysRemaining);
}

function greetingFor(now: Date, t: Translator): string {
  const hour = now.getHours();
  if (hour < 6) return t("app.home.greeting.night");
  if (hour < 12) return t("app.home.greeting.morning");
  if (hour < 18) return t("app.home.greeting.afternoon");
  return t("app.home.greeting.evening");
}
