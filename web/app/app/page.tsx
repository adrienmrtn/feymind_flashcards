import Link from "next/link";

import {
  activeDeadlines,
  buildQueue,
  clampTargetScore,
  courseAccent,
  dayDifference,
  desiredGradeLabel,
  examCountdownLabel,
  examUrgency,
  isDue,
  resolveEmoji,
  startOfDay,
  addDays,
  targetScoreFromIntensity,
  weekStrip,
  WEEK_STRIP_RADIUS,
  type ExamIntensity,
} from "@micabo/core";

import { Button } from "@/components/ui/button";
import { Card, CardAction, CardHeader, CardPanel, CardTitle } from "@/components/ui/card";
import { FriendActions } from "@/components/app/FriendActions";
import { MobileAppCard } from "@/components/app/MobileAppCard";
import { RefreshOnVisit } from "@/components/app/RefreshOnVisit";
import { WeekRanking } from "@/components/app/WeekRanking";
import { WeekStrip } from "@/components/app/WeekStrip";
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
import { loadNewCardBudget, loadReviewDatesSince } from "@/lib/data/reviews";
import { listWeekReviewRanking } from "@/lib/data/social";
import { currentUser } from "@/lib/data/user";
import { createClient } from "@/lib/supabase/server";

/**
 * Le tableau de bord : la semaine, les tâches du jour, les examens, le téléphone.
 *
 * Les tâches suivent **le rythme choisi**, pas toutes les cartes dues. Une
 * session qui vient de se terminer doit les actualiser tout de suite.
 */
export default async function DashboardPage() {
  const supabase = await createClient();
  const user = await currentUser();

  const now = new Date();
  const today = startOfDay(now);

  const [courses, cards, exams, friends, profile, budget, reviewDates, ranking] = await Promise.all([
    listCourses(),
    listCardSnapshots(),
    listExams(),
    listPendingFriendRequests(),
    user
      ? supabase
          .from("profiles")
          .select("display_name, country_code")
          .eq("id", user.id)
          .maybeSingle()
          .then((result) => result.data)
      : null,
    loadNewCardBudget(),
    loadReviewDatesSince(addDays(today, -WEEK_STRIP_RADIUS)),
    listWeekReviewRanking(),
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
  const upcoming = upcomingExams(exams, cards, today, profile?.country_code);
  const greeting = greetingFor(now);
  const name = profile?.display_name?.trim().split(/\s+/)[0];

  return (
    <>
      <RefreshOnVisit />
      <header>
        <p className="eyebrow text-ink-tertiary">{greeting}</p>
        <h1 className="mt-2 text-[32px] font-bold leading-tight text-ink">
          {name ? `${name}.` : "Tableau de bord"}
        </h1>
      </header>

      <WeekStrip days={week} />

      <div className="mt-8 grid items-stretch gap-4 lg:grid-cols-2">
        <TodayTasks
          tasks={tasks}
          cardCount={cards.length}
          heldBack={Math.max(0, dueOutsideRhythm)}
        />
        <MobileAppCard />
      </div>

      <UpcomingExams exams={upcoming} />

      <WeekRanking rows={ranking} />

      <div className="mt-8">
        <FriendsCard requests={friends} />
      </div>
    </>
  );
}

function TodayTasks({
  tasks,
  cardCount,
  heldBack,
}: {
  tasks: { course: CourseRow; due: number }[];
  cardCount: number;
  heldBack: number;
}) {
  return (
    <Card className="h-full rounded-group shadow-none">
      <CardHeader className="pb-2">
        <CardTitle className="text-[15px] font-semibold text-ink">Tâches du jour</CardTitle>
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
                    {course.title || "Sans titre"}
                  </span>
                  <span className="numeral mt-0.5 block text-[13px] text-ink-tertiary">
                    {due} carte{due > 1 ? "s" : ""} à réviser
                  </span>
                </span>
                <Button
                  size="sm"
                  variant="outline"
                  render={<Link href={`/app/reviser?cours=${course.id}` as never} />}
                >
                  Réviser
                </Button>
              </li>
            ))}
          </ul>
        ) : (
          <TodayEmpty cardCount={cardCount} heldBack={heldBack} />
        )}
      </CardPanel>
    </Card>
  );
}

function TodayEmpty({ cardCount, heldBack }: { cardCount: number; heldBack: number }) {
  if (cardCount === 0) {
    return (
      <div>
        <p className="text-[16px] font-semibold text-ink">Pas encore de cartes</p>
        <p className="mt-1.5 text-[13.5px] leading-relaxed text-ink-secondary">
          Importe un cours : Micabo en tire tes premières cartes et te les repose au bon moment.
        </p>
        <Button
          variant="outline"
          size="sm"
          className="mt-4"
          render={<Link href={"/app/importer" as never} />}
        >
          Importer un cours
        </Button>
      </div>
    );
  }

  if (heldBack > 0) {
    return (
      <div className="flex items-start gap-3.5">
        <span
          aria-hidden
          className="mt-0.5 flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-ink text-[18px] font-semibold text-on-ink"
        >
          ✓
        </span>
        <div className="min-w-0">
          <p className="text-[16px] font-semibold text-ink">Rythme tenu</p>
          <p className="mt-1 text-[13.5px] leading-relaxed text-ink-secondary">
            Tes cartes du jour sont faites. Il en reste {heldBack} hors rythme — elles
            attendent demain, c&apos;est le rythme que tu as choisi.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex items-start gap-3.5">
      <span
        aria-hidden
        className="mt-0.5 flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-ink text-[18px] font-semibold text-on-ink"
      >
        ✓
      </span>
      <div className="min-w-0">
        <p className="text-[16px] font-semibold text-ink">Tout est à jour</p>
        <p className="mt-1 text-[13.5px] leading-relaxed text-ink-secondary">
          Aucune carte n&apos;est due aujourd&apos;hui. Le rythme a fait son travail — profite-en.
        </p>
      </div>
    </div>
  );
}

function UpcomingExams({
  exams,
}: {
  exams: {
    id: string;
    name: string;
    days: number;
    grade: string;
    progress: number;
  }[];
}) {
  return (
    <Card className="mt-8 rounded-group shadow-none">
      <CardHeader className="pb-2">
        <CardTitle className="text-[15px] font-semibold text-ink">Prochains examens</CardTitle>
        <CardAction>
          <Button
            variant="link"
            size="sm"
            className="h-auto px-0"
            render={<Link href={"/app/examens" as never} />}
          >
            {exams.length > 0 ? "Voir" : "Ajouter"}
          </Button>
        </CardAction>
      </CardHeader>
      <CardPanel className="pt-0">
        {exams.length === 0 ? (
          <>
            <p className="text-[15px] font-medium text-ink">Aucun examen à venir</p>
            <p className="mt-1.5 text-[13.5px] leading-relaxed text-ink-secondary">
              Une date remet les cartes dans le bon ordre. Sans elle, la répétition
              espacée ignore le jour J.
            </p>
          </>
        ) : (
          <ul className="divide-y divide-hairline">
            {exams.map((exam) => {
              const urgency = examUrgency(exam.days);
              const tone =
                urgency === "critical"
                  ? "bg-negative-soft text-negative"
                  : urgency === "soon"
                    ? "bg-caution-soft text-caution"
                    : urgency === "upcoming"
                      ? "bg-info-soft text-info"
                      : "bg-surface-muted text-ink-secondary";

              return (
                <li key={exam.id}>
                  <Link
                    href={"/app/examens" as never}
                    className="flex items-center gap-4 py-3.5 first:pt-1 last:pb-0"
                  >
                    <span className="min-w-0 flex-1">
                      <span className="flex items-center gap-2">
                        <span className="truncate text-[15px] font-medium text-ink">{exam.name}</span>
                        <span
                          className={`shrink-0 rounded-pill px-2 py-0.5 text-[11.5px] font-semibold ${tone}`}
                        >
                          {examCountdownLabel(exam.days)}
                        </span>
                      </span>
                      <span className="mt-1.5 flex items-center gap-3 text-[13px] text-ink-tertiary">
                        <span>
                          Note souhaitée{" "}
                          <span className="font-medium text-ink">{exam.grade}</span>
                        </span>
                        <span className="numeral">
                          <span className="font-medium text-ink">{exam.progress} %</span>{" "}
                          d&apos;avancée
                        </span>
                      </span>
                      <span
                        aria-hidden
                        className="mt-2 block h-1.5 overflow-hidden rounded-pill bg-surface-muted"
                      >
                        <span
                          className="block h-full rounded-pill bg-ink"
                          style={{ width: `${exam.progress}%` }}
                        />
                      </span>
                    </span>
                  </Link>
                </li>
              );
            })}
          </ul>
        )}
      </CardPanel>
    </Card>
  );
}

function FriendsCard({ requests }: { requests: FriendRequestRow[] }) {
  return (
    <Card className="rounded-group shadow-none">
      <CardHeader className="pb-2">
        <CardTitle className="text-[15px] font-semibold text-ink">Amis</CardTitle>
        <CardAction>
          <Button variant="link" size="sm" className="h-auto px-0" render={<Link href={"/app/amis" as never} />}>
            Voir
          </Button>
        </CardAction>
      </CardHeader>
      <CardPanel className="pt-0">
        {requests.length === 0 ? (
          <>
            <p className="text-[15px] font-medium text-ink">Personne en attente.</p>
            <p className="mt-1.5 text-[13.5px] leading-relaxed text-ink-secondary">
              Cherche un @ pour ajouter quelqu&apos;un. C&apos;est le même annuaire que sur
              l&apos;iPhone.
            </p>
            <Button
              variant="outline"
              size="sm"
              className="mt-4"
              render={<Link href={"/app/amis" as never} />}
            >
              Ajouter un ami
            </Button>
          </>
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
                  {request.username ? `@${request.username}` : "Quelqu'un"}
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

function upcomingExams(
  exams: ExamRow[],
  cards: CardSnapshotRow[],
  today: Date,
  country?: string | null,
) {
  return exams
    .map((exam) => {
      const day = startOfDay(new Date(`${exam.exam_date}T12:00:00`));
      return {
        id: exam.id,
        name: exam.name,
        days: dayDifference(today, day),
        grade: desiredGradeLabel(examTargetScore(exam), country),
        progress: examProgressPct(exam, cards),
      };
    })
    .filter((exam) => exam.days >= 0)
    .sort((left, right) => left.days - right.days)
    .slice(0, 5);
}

function examTargetScore(exam: ExamRow): number {
  if (typeof exam.target_score === "number") return clampTargetScore(exam.target_score);
  return targetScoreFromIntensity(asIntensity(exam.intensity));
}

function examProgressPct(exam: ExamRow, cards: CardSnapshotRow[]): number {
  const ids = new Set(exam.course_ids ?? []);
  const relevant = cards.filter(
    (card) => card.course_id && ids.has(card.course_id) && !card.is_suspended,
  );
  if (relevant.length === 0) return 0;
  const started = relevant.filter((card) => card.state !== "new").length;
  return Math.round((started / relevant.length) * 100);
}

function asIntensity(value: string): ExamIntensity {
  return value === "light" || value === "intense" || value === "standard" ? value : "standard";
}

function greetingFor(now: Date): string {
  const hour = now.getHours();
  if (hour < 6) return "Bonne nuit";
  if (hour < 12) return "Bonjour";
  if (hour < 18) return "Bon après-midi";
  return "Bonsoir";
}
