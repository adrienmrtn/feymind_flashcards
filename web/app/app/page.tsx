import Link from "next/link";

import {
  courseAccent,
  isDue,
  resolveEmoji,
  startOfDay,
  addDays,
  weekStrip,
  WEEK_STRIP_RADIUS,
} from "@micabo/core";

import { Button } from "@/components/ui/button";
import { Card, CardAction, CardHeader, CardPanel, CardTitle } from "@/components/ui/card";
import { FriendActions } from "@/components/app/FriendActions";
import { MobileAppCard } from "@/components/app/MobileAppCard";
import { WeekRanking } from "@/components/app/WeekRanking";
import { WeekStrip } from "@/components/app/WeekStrip";
import {
  listCardSnapshots,
  listCourses,
  listPendingFriendRequests,
  type CourseRow,
  type FriendRequestRow,
} from "@/lib/data/courses";
import { loadNewCardBudget, loadReviewDatesSince } from "@/lib/data/reviews";
import { listWeekReviewRanking } from "@/lib/data/social";
import { currentUser } from "@/lib/data/user";
import { createClient } from "@/lib/supabase/server";

/**
 * Le tableau de bord : la semaine, les tâches du jour, le téléphone, les amis.
 *
 * La langue des fiches vit sur le profil. Les cartes difficiles n'ont plus
 * leur place ici : on vient pour ce qu'il y a à faire aujourd'hui.
 */
export default async function DashboardPage() {
  const supabase = await createClient();
  const user = await currentUser();

  const now = new Date();
  const today = startOfDay(now);

  const [courses, cards, friends, profile, budget, reviewDates, ranking] = await Promise.all([
    listCourses(),
    listCardSnapshots(),
    listPendingFriendRequests(),
    user
      ? supabase
          .from("profiles")
          .select("display_name")
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

  const tasks = dueTodayByCourse(cards, courses, now);
  const greeting = greetingFor(now);
  const name = profile?.display_name?.trim().split(/\s+/)[0];

  return (
    <>
      <header>
        <p className="eyebrow text-ink-tertiary">{greeting}</p>
        <h1 className="mt-2 text-[32px] font-bold leading-tight text-ink">
          {name ? `${name}.` : "Tableau de bord"}
        </h1>
      </header>

      <WeekStrip days={week} />

      <div className="mt-8 grid gap-4 lg:grid-cols-2">
        <TodayTasks tasks={tasks} />
        <MobileAppCard />
      </div>

      <WeekRanking rows={ranking} />

      <div className="mt-8">
        <FriendsCard requests={friends} />
      </div>
    </>
  );
}

function TodayTasks({
  tasks,
}: {
  tasks: { course: CourseRow; due: number }[];
}) {
  return (
    <Card className="rounded-group shadow-none">
      <CardHeader className="pb-2">
        <CardTitle className="text-[15px] font-semibold text-ink">Tâches du jour</CardTitle>
      </CardHeader>
      <CardPanel className="pt-0">
        {tasks.length === 0 ? (
          <p className="text-[14.5px] leading-relaxed text-ink-secondary">
            Rien à réviser aujourd&apos;hui.
          </p>
        ) : (
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

function dueTodayByCourse(
  cards: Awaited<ReturnType<typeof listCardSnapshots>>,
  courses: CourseRow[],
  now: Date,
): { course: CourseRow; due: number }[] {
  const counts = new Map<string, number>();
  for (const card of cards) {
    if (!card.course_id) continue;
    if (
      !isDue(
        {
          id: card.id,
          state: card.state,
          dueDate: new Date(card.due_date),
          position: card.position,
          createdAt: new Date(card.created_at),
          isSuspended: card.is_suspended,
        },
        now,
      )
    ) {
      continue;
    }
    counts.set(card.course_id, (counts.get(card.course_id) ?? 0) + 1);
  }

  return courses
    .filter((course) => (counts.get(course.id) ?? 0) > 0)
    .map((course) => ({ course, due: counts.get(course.id) ?? 0 }))
    .sort((left, right) => right.due - left.due);
}

function greetingFor(now: Date): string {
  const hour = now.getHours();
  if (hour < 6) return "Bonne nuit";
  if (hour < 12) return "Bonjour";
  if (hour < 18) return "Bon après-midi";
  return "Bonsoir";
}
