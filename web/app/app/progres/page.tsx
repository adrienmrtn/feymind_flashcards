import Link from "next/link";
import { Suspense } from "react";

import {
  currentStreak,
  longestStreak,
  masteryOf,
  rankReviewedCards,
  studyStats,
  weakCards,
} from "@micabo/core";

import { ActivityChart } from "@/components/app/charts/ActivityChart";
import { MasteryBar } from "@/components/app/charts/MasteryBar";
import { Bar } from "@/components/app/Skeleton";
import { listCardSnapshots, listCourses, type CardSnapshotRow } from "@/lib/data/courses";
import { loadCardDifficulty, loadDailyReviews } from "@/lib/data/difficulty";
import { loadProfileStats } from "@/lib/data/reviews";
import { getTranslator } from "@/lib/i18n/server";
import type { Translator } from "@/lib/i18n/copy";

/**
 * **Les progrès : la seule page de mesure.**
 *
 * Avant, trois écrans mesuraient : Progrès (maîtrise, semaine, statistiques), Profil (série,
 * camembert, cartes les plus passées) et la fiche d'épreuve. Chacun avec son vocabulaire.
 * Il n'en reste qu'un, et il lit dans l'ordre : ce que je sais (la maîtrise), ce que je fais
 * (l'activité), ce qui résiste. Le camembert est parti : il découpait les mêmes cartes en
 * quatre parts qui ne recoupaient pas celles de la maîtrise.
 */
export default async function ProgressPage() {
  const now = new Date();
  const [{ t }, courses, cards, difficulties, daily] = await Promise.all([
    getTranslator(),
    listCourses(),
    listCardSnapshots(),
    loadCardDifficulty(),
    loadDailyReviews(),
  ]);

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
    { limit: 5 },
  );
  const titles = new Map(courses.map((course) => [course.id, course.title]));

  return (
    <>
      <header>
        <h1 className="page-title">{t("app.progress.title")}</h1>
        <p className="page-lead">{t("app.progress.lead")}</p>
      </header>

      <Suspense fallback={<StatsPending />}>
        <StatTiles stats={stats} cardCount={cards.length} courseCount={courses.length} t={t} />
      </Suspense>

      <section className="panel p-5" data-tour="maitrise">
        <div className="flex flex-wrap items-baseline justify-between gap-3">
          <div>
            <h2 className="section-title">{t("app.home.mastery.title")}</h2>
            <p className="section-lead">{t("app.progress.masteryLead")}</p>
          </div>
          <Link href={"/app/cours" as never} className="underline-draw text-[12.5px] font-medium text-ink-secondary">
            {t("app.home.mastery.byCourse")}
          </Link>
        </div>
        {mastery.cardCount === 0 ? (
          <p className="mt-3 text-[13.5px] text-ink-secondary">{t("app.home.mastery.empty")}</p>
        ) : (
          <>
            <p className="mt-4 flex items-baseline gap-2">
              <span className="hero-value">
                {mastery.percent}
                <span className="text-[20px] text-ink-secondary"> %</span>
              </span>
              <span className="text-[13px] text-ink-tertiary">
                {t("app.home.mastery.of", { count: mastery.cardCount })}
              </span>
            </p>
            <MasteryBar mastery={mastery} className="mt-4" />
          </>
        )}
      </section>

      <section className="panel p-5" data-tour="statistiques">
        <div className="flex flex-wrap items-baseline justify-between gap-3">
          <div>
            <h2 className="section-title">{t("app.progress.activity")}</h2>
            <p className="section-lead">{t("app.progress.activityLead")}</p>
          </div>
          {stats.best ? (
            <p className="numeral text-[12.5px] text-ink-tertiary">
              {t("app.home.stats.averageDetail", { best: stats.best.passes })}
            </p>
          ) : null}
        </div>
        <div className="mt-4">
          <ActivityChart daily={daily} now={now} />
        </div>
      </section>

      <div className="grid gap-4 md:grid-cols-2">
        <WeakPanel weak={weak} titles={titles} t={t} />
        <Suspense fallback={<TopCardsPending />}>
          <TopCards cards={cards} t={t} />
        </Suspense>
      </div>
    </>
  );
}

async function StatTiles({
  stats,
  cardCount,
  courseCount,
  t,
}: {
  stats: ReturnType<typeof studyStats>;
  cardCount: number;
  courseCount: number;
  t: Translator;
}) {
  const { reviewDays } = await loadProfileStats();
  const dates = reviewDays.map((day) => new Date(day));
  const streak = currentStreak(dates);
  const record = Math.max(longestStreak(dates), stats.bestStreak);

  return (
    <dl className="grid grid-cols-2 gap-3 md:grid-cols-4" data-tour="profil-chiffres">
      <Stat
        label={t("app.home.stats.streak")}
        value={t("app.progress.days", { count: streak })}
        detail={t("app.home.stats.streakDetail", { best: record })}
      />
      <Stat
        label={t("app.home.stats.passes")}
        value={stats.totalPasses.toLocaleString()}
        detail={t("app.home.stats.passesDetail", { days: stats.activeDays })}
      />
      <Stat
        label={t("app.home.stats.accuracy")}
        value={`${stats.accuracyPercent} %`}
        detail={t("app.home.stats.accuracyDetail")}
      />
      <Stat
        label={t("app.profile.cards.label")}
        value={cardCount.toLocaleString()}
        detail={t("app.profile.courseCount", { count: courseCount })}
      />
    </dl>
  );
}

function Stat({ label, value, detail }: { label: string; value: string; detail: string }) {
  return (
    <div className="panel min-w-0 px-4 py-3.5">
      <dt className="stat-label truncate">{label}</dt>
      <dd className="stat-value mt-2">{value}</dd>
      <p className="mt-1.5 truncate text-[12px] text-ink-tertiary">{detail}</p>
    </div>
  );
}

function StatsPending() {
  return (
    <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
      {Array.from({ length: 4 }, (_, index) => (
        <div key={index} className="panel px-4 py-3.5">
          <Bar className="h-3 w-16" />
          <Bar className="mt-3 h-6 w-12" />
          <Bar className="mt-2 h-3 w-24" />
        </div>
      ))}
    </div>
  );
}

function WeakPanel({
  weak,
  titles,
  t,
}: {
  weak: { id: string; courseId: string | null; front: string; againCount: number; reviews: number }[];
  titles: Map<string, string>;
  t: Translator;
}) {
  return (
    <section className="panel flex min-w-0 flex-col p-5">
      <h2 className="section-title">{t("app.home.weak.title")}</h2>
      {weak.length === 0 ? (
        <p className="section-lead">{t("app.home.weak.none")}</p>
      ) : (
        <>
          <p className="section-lead">{t("app.home.weak.lead")}</p>
          <ul className="mt-3 divide-y divide-hairline">
            {weak.map((card) => (
              <li key={card.id} className="py-2.5">
                <p className="line-clamp-2 text-[13.5px] text-ink">{card.front}</p>
                <p className="numeral mt-0.5 text-[12px] text-ink-tertiary">
                  {[card.courseId ? titles.get(card.courseId) : null, t("app.home.weak.line", { again: card.againCount, reviews: card.reviews })]
                    .filter(Boolean)
                    .join(" · ")}
                </p>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  );
}

async function TopCards({ cards, t }: { cards: CardSnapshotRow[]; t: Translator }) {
  const { topCards } = await loadProfileStats();
  const ranked = rankReviewedCards(
    topCards,
    cards.map((card) => ({ id: card.id, front: card.front })),
  ).slice(0, 5);

  return (
    <section className="panel flex min-w-0 flex-col p-5" data-tour="profil-passees">
      <h2 className="section-title">{t("app.profile.topCards.label")}</h2>
      {ranked.length === 0 ? (
        <p className="section-lead">{t("app.profile.topCards.empty")}</p>
      ) : (
        <ol className="mt-3 divide-y divide-hairline">
          {ranked.map((card, index) => (
            <li key={card.id} className="flex items-baseline gap-3 py-2.5">
              <span className="numeral w-4 shrink-0 text-[12px] text-ink-tertiary">{index + 1}</span>
              <span className="min-w-0 flex-1 truncate text-[13.5px] text-ink">{card.front}</span>
              <span className="numeral shrink-0 text-[12.5px] font-medium text-ink">{card.passes}</span>
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}

function TopCardsPending() {
  return (
    <div className="panel p-5">
      <Bar className="h-4 w-40" />
      {Array.from({ length: 4 }, (_, index) => (
        <Bar key={index} className="mt-3.5 h-4 w-[62%]" />
      ))}
    </div>
  );
}
