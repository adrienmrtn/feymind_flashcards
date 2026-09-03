import { Suspense } from "react";
import Link from "next/link";

import {
  countryFor,
  isStudyLevel,
  knowledgeDistribution,
  rankReviewedCards,
  resolveStage,
  streak as currentStreak,
  bestStreak,
  studyCounts,
} from "@micabo/core";

import { KnowledgePie } from "@/components/app/KnowledgePie";
import { Bar } from "@/components/app/Skeleton";
import { Flag } from "@/components/onboarding/Flag";
import { listCardSnapshots, listCourses, listExams, type CardSnapshotRow } from "@/lib/data/courses";
import { readProfile } from "@/lib/data/profile";
import { loadNewCardBudget, loadProfileStats } from "@/lib/data/reviews";
import type { Translator } from "@/lib/i18n/copy";
import { getTranslator } from "@/lib/i18n/server";

/**
 * Le profil, **en une page posée**.
 *
 * Une tête, deux chiffres, le camembert de la maîtrise, les cartes les
 * plus passées. Les réglages ont leur propre page.
 *
 * **L'historique arrive après la page.** La série et le palmarès sont les deux seules choses
 * ici qui dépendent de `review_logs`, et c'est de loin la lecture la plus lourde de l'app.
 * Le reste - qui l'on est, combien de cartes, la maîtrise - n'a pas à l'attendre.
 */
export default async function ProfilePage() {
  const [{ t }, profile, courses, cards, exams, budget] = await Promise.all([
    getTranslator(),
    readProfile(),
    listCourses(),
    listCardSnapshots(),
    listExams(),
    loadNewCardBudget(),
  ]);

  const country = countryFor(profile?.country_code);
  const stage = resolveStage(country.code, {
    level: isStudyLevel(profile?.study_level) ? profile.study_level : null,
  });
  const due = studyCounts(
    cards.map((card) => ({
      id: card.id,
      state: card.state,
      dueDate: new Date(card.due_date),
      position: card.position,
      createdAt: new Date(card.created_at),
      isSuspended: card.is_suspended,
    })),
    {
      limits: {
        newPerSession: budget.remaining,
        reviewsPerSession: Number.MAX_SAFE_INTEGER,
      },
    },
  ).total;
  const name = profile?.display_name ?? profile?.username ?? t("app.friends.yourAccount");
  const handle = profile?.username ?? "";

  const levels = knowledgeDistribution(
    cards.map((card) => ({ state: card.state, intervalDays: card.interval_days })),
  );
  return (
    <div className="profile-page">
      <header className="flex items-center gap-4">
        <span
          aria-hidden
          className="flex size-11 shrink-0 items-center justify-center rounded-full bg-sidebar-accent text-[15px] font-semibold text-sidebar-accent-foreground"
        >
          {name.trim().charAt(0).toUpperCase() || "?"}
        </span>
        <div className="min-w-0 flex-1">
        <h1 className="truncate text-lg font-semibold tracking-tight text-foreground">
          {name}
        </h1>
        <p className="mt-2 flex flex-wrap items-center justify-start gap-2 text-[14px] text-ink-secondary">
          {handle ? <span className="font-medium text-ink">@{handle}</span> : null}
          {handle ? <span className="text-ink-tertiary">·</span> : null}
          <span className="inline-flex items-center gap-1.5">
            <Flag iso={country.iso} emoji={country.flag} label={country.name} className="h-[14px] w-[18px]" />
            {country.name}
          </span>
          {stage ? (
            <>
              <span className="text-ink-tertiary">·</span>
              <span>{stage.title}</span>
            </>
          ) : null}
        </p>
        </div>
        <Link
          href={"/app/reglages" as never}
          aria-label={t("nav.settings")}
          className="pressable ml-auto flex size-11 shrink-0 items-center justify-center rounded-full text-ink-secondary hover:bg-surface-muted"
        >
          <SettingsGlyph />
        </Link>
      </header>

      <section
        className="saas-card relative mt-6 grid overflow-hidden sm:grid-cols-2"
        data-tour="profil-chiffres"
      >
        <div className="px-7 py-7">
          <p className="text-[13px] text-ink-tertiary">{t("app.profile.streak.label")}</p>
          <Suspense fallback={<StreakPending />}>
            <Streak t={t} />
          </Suspense>
        </div>
        <div className="border-t border-hairline px-7 py-7 sm:border-t-0 sm:border-l">
          <p className="text-[13px] text-ink-tertiary">{t("app.profile.cards.label")}</p>
          <p className="numeral mt-3 text-[44px] font-bold leading-none tracking-display text-ink">
            {cards.length}
          </p>
          <p className="mt-2 text-[13px] text-ink-tertiary">
            {t("app.profile.courseCount", { count: courses.length })}
          </p>
        </div>
      </section>

      {due > 0 ? (
        <Link
          href="/app/reviser"
          className="saas-card pressable hover-tile relative mt-4 flex items-center justify-between gap-4 px-7 py-5"
        >
          <span className="text-[15px] font-semibold text-ink">
            {t("app.profile.dueCards", { count: due })}
          </span>
          <span className="text-[14px] font-medium text-ink">{t("nav.review")}</span>
        </Link>
      ) : null}

      <section className="saas-card relative mt-4 px-7 py-7" data-tour="profil-maitrise">
        <p className="text-[13px] text-ink-tertiary">{t("app.profile.mastery.label")}</p>
        {cards.length === 0 ? (
          <p className="mt-4 text-[14.5px] leading-relaxed text-ink-secondary">
            {t("app.profile.mastery.empty")}
          </p>
        ) : (
          <KnowledgePie buckets={levels} />
        )}
      </section>

      <section className="saas-card relative mt-4 overflow-hidden" data-tour="profil-passees">
        <p className="px-7 pt-7 text-[13px] text-ink-tertiary">{t("app.profile.topCards.label")}</p>
        <Suspense fallback={<TopCardsPending />}>
          <TopCards t={t} cards={cards} />
        </Suspense>
      </section>

      <section className="saas-card relative mt-4 overflow-hidden">
        <p className="px-7 pt-7 text-[13px] text-ink-tertiary">{t("app.profile.aroundYou")}</p>
        <Link
          href={"/app/amis" as never}
          className="hover-row mt-3 flex items-center justify-between gap-4 px-7 py-4"
        >
          <span className="text-[15px] text-ink">{t("nav.friends")}</span>
          <span className="text-[13px] text-ink-tertiary">
            {handle ? `@${handle}` : t("app.common.add")}
          </span>
        </Link>
        {exams.length > 0 ? (
          <Link
            href={"/app/examens" as never}
            className="hover-row flex items-center justify-between gap-4 border-t border-hairline px-7 py-4"
          >
            <span className="text-[15px] text-ink">{t("nav.exams")}</span>
            <span className="numeral text-[13px] text-ink-tertiary">{exams.length}</span>
          </Link>
        ) : null}
        <Link
          href={"/app/reglages#abonnement" as never}
          className="hover-row flex items-center justify-between gap-4 border-t border-hairline px-7 py-4"
        >
          <span className="text-[15px] text-ink">{t("app.settings.subscription")}</span>
          <span className="text-[13px] text-ink-tertiary">{t("app.profile.subscriptionHint")}</span>
        </Link>
        <Link
          href={"/app/reglages" as never}
          className="hover-row flex items-center justify-between gap-4 border-t border-hairline px-7 py-4"
        >
          <span className="text-[15px] text-ink">{t("nav.settings")}</span>
          <span className="text-[13px] text-ink-tertiary">{t("app.profile.settingsHint")}</span>
        </Link>
      </section>
    </div>
  );
}

/**
 * La série, et le record s'il est meilleur.
 *
 * Les jours révisés sont une liste de dates, pas l'historique complet : c'est tout ce qu'une
 * série demande, et c'est ce qui a fait passer cette lecture du mégaoctet au kilooctet.
 */
async function Streak({ t }: { t: Translator }) {
  const { reviewDays } = await loadProfileStats();
  const dates = reviewDays.map((day) => new Date(day));
  const series = currentStreak(dates);
  const record = bestStreak(dates);

  return (
    <>
      <p className="numeral mt-3 text-[44px] font-bold leading-none tracking-display text-ink">
        {series}
      </p>
      <p className="mt-2 text-[13px] text-ink-tertiary">
        {series === 0
          ? t("app.profile.streak.empty")
          : t("app.profile.streak.days", { count: series })}
        {record > series ? t("app.profile.streak.record", { record }) : ""}
      </p>
    </>
  );
}

function StreakPending() {
  return (
    <>
      <Bar className="mt-3 h-[44px] w-16" />
      <Bar className="mt-3 h-3 w-40" />
    </>
  );
}

async function TopCards({ t, cards }: { t: Translator; cards: CardSnapshotRow[] }) {
  const { topCards } = await loadProfileStats();
  const ranked = rankReviewedCards(
    topCards,
    cards.map((card) => ({ id: card.id, front: card.front })),
  );

  if (ranked.length === 0) {
    return (
      <p className="px-7 pb-7 pt-4 text-[14.5px] leading-relaxed text-ink-secondary">
        {t("app.profile.topCards.empty")}
      </p>
    );
  }

  return (
    <ol className="mt-3 divide-y divide-hairline pb-2">
      {ranked.map((card, index) => (
        <li key={card.id} className="hover-row flex items-baseline gap-3.5 px-7 py-3.5">
          <span className="numeral w-5 shrink-0 text-[13px] text-ink-tertiary">{index + 1}</span>
          <span className="min-w-0 flex-1 truncate text-[14.5px] text-ink">{card.front}</span>
          <span className="shrink-0 text-[13px] text-ink-tertiary">
            <span className="numeral font-medium text-ink">{card.passes}</span>
          </span>
        </li>
      ))}
    </ol>
  );
}

function TopCardsPending() {
  return (
    <div className="px-7 pb-7 pt-4 space-y-3.5">
      {Array.from({ length: 3 }, (_, index) => (
        <Bar key={index} className="h-4 w-[62%]" />
      ))}
    </div>
  );
}

function SettingsGlyph() {
  return (
    <svg aria-hidden viewBox="0 0 20 20" className="size-5">
      <path
        d="M8.2 2.8h3.6l.4 1.7a5.4 5.4 0 0 1 1.5.9l1.6-.6 1.8 3.1-1.3 1.2c.1.4.1.8.1 1.2s0 .8-.1 1.2l1.3 1.2-1.8 3.1-1.6-.6a5.4 5.4 0 0 1-1.5.9l-.4 1.7H8.2l-.4-1.7a5.4 5.4 0 0 1-1.5-.9l-1.6.6L2.9 12.7l1.3-1.2A5.6 5.6 0 0 1 4.1 10c0-.4 0-.8.1-1.2L2.9 7.6 4.7 4.5l1.6.6a5.4 5.4 0 0 1 1.5-.9l.4-1.4z"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinejoin="round"
      />
      <circle cx="10" cy="10" r="2.1" fill="none" stroke="currentColor" strokeWidth="1.5" />
    </svg>
  );
}
