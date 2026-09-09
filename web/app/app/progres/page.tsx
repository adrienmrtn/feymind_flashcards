import Link from "next/link";

import {
  addDays,
  adherenceFrom,
  asExamKind,
  capacityFor,
  examCountdownLabel,
  feasibility,
  masteryOf,
  planTerm,
  startOfDay,
  studyStats,
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
import { listMockResults, loadThroughput } from "@/lib/data/mocks";
import { readProfile } from "@/lib/data/profile";
import { loadNewCardBudget, loadReviewDatesSince } from "@/lib/data/reviews";
import { getTranslator } from "@/lib/i18n/server";
import type { UiLocale } from "@/lib/i18n/locales";
import type { Translator } from "@/lib/i18n/copy";

/**
 * **Les progrès : la mesure, une fois que le plan a la charge du travail.**
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
export default async function ProgressPage() {
  const now = new Date();
  const today = startOfDay(now);
  const { t, locale } = await getTranslator();

  const [
    courses,
    cards,
    exams,
    profile,
    budget,
    reviewDates,
    availability,
    difficulties,
    daily,
    throughput,
    mocks,
  ] = await Promise.all([
    listCourses(),
    listCardSnapshots(),
    listExams(),
    readProfile(),
    loadNewCardBudget(),
    loadReviewDatesSince(addDays(today, -WEEK_STRIP_RADIUS)),
    readAvailability(),
    loadCardDifficulty(),
    loadDailyReviews(),
    loadThroughput(),
    listMockResults(),
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
    throughput,
    mocks,
    difficulties,
    adherence: adherenceFrom(
      daily,
      (date) => capacityFor(availability, date),
      throughput,
      now,
    ),
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


  return (
    <>
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold tracking-tight text-foreground">
            {t("app.progress.title")}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">{t("app.progress.lead")}</p>
        </div>
        {nextExam ? (
          <Link
            href={"/app" as never}
            className="hover-tile flex items-center gap-2 rounded-pill bg-caution-soft px-3 py-1.5"
          >
            <span className="truncate text-[13px] font-medium text-caution">{nextExam.name}</span>
            <span className="numeral text-[13px] font-semibold text-caution">
              {examCountdownLabel(nextExam.days)}
            </span>
          </Link>
        ) : null}
      </header>

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
  kind: string;
}): TermExam {
  return {
    id: exam.id,
    name: exam.name,
    examDate: new Date(`${exam.exam_date}T12:00:00`),
    intensity:
      exam.intensity === "light" || exam.intensity === "intense" ? exam.intensity : "standard",
    courseIds: exam.course_ids ?? [],
    formats: exam.formats ?? [],
    kind: asExamKind(exam.kind),
  };
}

function greetingFor(now: Date, t: Translator): string {
  const hour = now.getHours();
  if (hour < 6) return t("app.home.greeting.night");
  if (hour < 12) return t("app.home.greeting.morning");
  if (hour < 18) return t("app.home.greeting.afternoon");
  return t("app.home.greeting.evening");
}
