import Link from "next/link";

import {
  DEFAULT_DAILY_MINUTES,
  DEFAULT_SHEET_LENGTH,
  countryFor,
  isSheetLength,
  knowledgeDistribution,
  mostReviewedCards,
  resolveStage,
  streak as currentStreak,
  bestStreak,
  studyCounts,
  sheetLanguage,
} from "@micabo/core";

import { DeleteAccount } from "@/components/app/DeleteAccount";
import { ProfileSettings } from "@/components/app/ProfileSettings";
import { ReplayOnboarding } from "@/components/app/ReplayOnboarding";
import { SignOutButton } from "@/components/app/SignOutButton";
import { SheetLanguageCard } from "@/components/app/SheetLanguageCard";
import { Flag } from "@/components/onboarding/Flag";
import { listCardSnapshots, listCourses, listExams } from "@/lib/data/courses";
import { loadNewCardBudget } from "@/lib/data/reviews";
import { currentUser } from "@/lib/data/user";
import { createClient } from "@/lib/supabase/server";

/**
 * Le profil, **en une page posée**.
 *
 * Une tête, deux chiffres, puis de grandes cartes blanches. Les emojis de
 * section et les tuiles qui sautent au survol sont restés dehors : c'est
 * ce qui faisait lire une pile de gadgets au lieu d'un compte.
 */
export default async function ProfilePage() {
  const supabase = await createClient();
  const user = await currentUser();

  const [profile, courses, cards, exams, logs, budget] = await Promise.all([
    user
      ? supabase
          .from("profiles")
          .select(
            "display_name, username, country_code, study_level, subjects, institution_name, institution_id, daily_minutes, sheet_length, sheet_language",
          )
          .eq("id", user.id)
          .maybeSingle()
          .then((result) => result.data)
      : null,
    listCourses(),
    listCardSnapshots(),
    listExams(),
    user
      ? supabase
          .from("review_logs")
          .select("card_id, reviewed_at")
          .eq("user_id", user.id)
          .limit(20000)
          .then((result) => result.data ?? [])
      : Promise.resolve([]),
    loadNewCardBudget(),
  ]);

  const country = countryFor(profile?.country_code);
  const stage = resolveStage(country.code, { level: profile?.study_level ?? null });
  const minutes = profile?.daily_minutes ?? DEFAULT_DAILY_MINUTES;
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
  const name = profile?.display_name ?? profile?.username ?? "Ton compte";
  const handle = profile?.username ?? "";

  const reviewDates = (
    logs as { card_id: string | null; reviewed_at: string }[]
  ).map((log) => new Date(log.reviewed_at));
  const series = currentStreak(reviewDates);
  const record = bestStreak(reviewDates);
  const levels = knowledgeDistribution(
    cards.map((card) => ({ state: card.state, intervalDays: card.interval_days })),
  );
  const topCards = mostReviewedCards(
    (logs as { card_id: string | null }[]).map((log) => ({ cardId: log.card_id })),
    cards.map((card) => ({ id: card.id, front: card.front })),
  );
  const peak = Math.max(1, ...levels.map((level) => level.count));

  return (
    <div className="profile-page">
      <header className="relative pt-4 text-center">
        <span
          aria-hidden
          className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-white text-[22px] font-semibold text-ink shadow-paper"
        >
          {name.trim().charAt(0).toUpperCase() || "?"}
        </span>
        <h1 className="mt-5 truncate text-[32px] font-bold leading-tight tracking-tight-title text-ink">
          {name}
        </h1>
        <p className="mt-2 flex flex-wrap items-center justify-center gap-2 text-[14px] text-ink-secondary">
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
      </header>

      <section className="saas-card relative mt-10 grid overflow-hidden sm:grid-cols-2">
        <div className="px-7 py-7">
          <p className="text-[13px] text-ink-tertiary">Série</p>
          <p className="numeral mt-3 text-[44px] font-bold leading-none tracking-display text-ink">
            {series}
          </p>
          <p className="mt-2 text-[13px] text-ink-tertiary">
            {series === 0
              ? "Ta première carte notée lance la série."
              : series === 1
                ? "1 jour"
                : `${series} jours`}
            {record > series ? ` · record ${record}` : ""}
          </p>
        </div>
        <div className="border-t border-hairline px-7 py-7 sm:border-t-0 sm:border-l">
          <p className="text-[13px] text-ink-tertiary">Cartes</p>
          <p className="numeral mt-3 text-[44px] font-bold leading-none tracking-display text-ink">
            {cards.length}
          </p>
          <p className="mt-2 text-[13px] text-ink-tertiary">
            {courses.length === 1 ? "1 cours" : `${courses.length} cours`}
          </p>
        </div>
      </section>

      {due > 0 ? (
        <Link
          href="/app/reviser"
          className="saas-card pressable relative mt-4 flex items-center justify-between gap-4 px-7 py-5"
        >
          <span className="text-[15px] font-semibold text-ink">
            <span className="numeral">{due}</span> carte{due > 1 ? "s" : ""} à revoir
          </span>
          <span className="text-[14px] font-medium text-ink">Réviser</span>
        </Link>
      ) : null}

      <section className="saas-card relative mt-4 px-7 py-7">
        <p className="text-[13px] text-ink-tertiary">Niveau de connaissance</p>
        {cards.length === 0 ? (
          <p className="mt-4 text-[14.5px] leading-relaxed text-ink-secondary">
            Tes cartes se rangeront ici : nouvelles, en cours, en révision, parfaitement
            maîtrisées.
          </p>
        ) : (
          <div className="mt-6 flex h-36 items-end gap-3">
            {levels.map((level) => (
              <div key={level.id} className="flex min-w-0 flex-1 flex-col items-center gap-2">
                <span className="numeral text-[13px] font-semibold text-ink">{level.count}</span>
                <div className="flex h-24 w-full items-end">
                  <div
                    className={`w-full rounded-t-md ${barTone(level.id)}`}
                    style={{
                      height: `${Math.max(level.count > 0 ? 8 : 4, Math.round((level.count / peak) * 100))}%`,
                    }}
                  />
                </div>
                <span className="text-center text-[11px] leading-tight text-ink-tertiary">
                  {level.label}
                </span>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="saas-card relative mt-4 overflow-hidden">
        <p className="px-7 pt-7 text-[13px] text-ink-tertiary">Cartes les plus passées</p>
        {topCards.length === 0 ? (
          <p className="px-7 pb-7 pt-4 text-[14.5px] leading-relaxed text-ink-secondary">
            Note tes premières cartes pour voir celles que tu revois le plus.
          </p>
        ) : (
          <ol className="mt-3 divide-y divide-hairline pb-2">
            {topCards.map((card, index) => (
              <li key={card.id} className="flex items-baseline gap-3.5 px-7 py-3.5">
                <span className="numeral w-5 shrink-0 text-[13px] text-ink-tertiary">
                  {index + 1}
                </span>
                <span className="min-w-0 flex-1 truncate text-[14.5px] text-ink">{card.front}</span>
                <span className="shrink-0 text-[13px] text-ink-tertiary">
                  <span className="numeral font-medium text-ink">{card.passes}</span>
                </span>
              </li>
            ))}
          </ol>
        )}
      </section>

      <div className="relative mt-4 grid gap-4 lg:grid-cols-2">
        <section className="saas-card overflow-hidden">
          <p className="px-7 pt-7 text-[13px] text-ink-tertiary">Autour de toi</p>
          <Link
            href={"/app/amis" as never}
            className="mt-3 flex items-center justify-between gap-4 px-7 py-4"
          >
            <span className="text-[15px] text-ink">Amis</span>
            <span className="text-[13px] text-ink-tertiary">
              {handle ? `@${handle}` : "Ajouter"}
            </span>
          </Link>
          {exams.length > 0 ? (
            <Link
              href={"/app/examens" as never}
              className="flex items-center justify-between gap-4 border-t border-hairline px-7 py-4"
            >
              <span className="text-[15px] text-ink">Examens</span>
              <span className="numeral text-[13px] text-ink-tertiary">{exams.length}</span>
            </Link>
          ) : null}
          <div className="border-t border-hairline px-7 py-6">
            <SheetLanguageCard
              initial={sheetLanguage(profile?.sheet_language, profile?.country_code)}
              embedded
            />
          </div>
        </section>

        <ProfileSettings
          initialName={profile?.display_name ?? ""}
          initialUsername={handle}
          initialMinutes={minutes}
          initialLength={
            isSheetLength(profile?.sheet_length) ? profile.sheet_length : DEFAULT_SHEET_LENGTH
          }
          initialSubjects={Array.isArray(profile?.subjects) ? profile.subjects : []}
          initialSchool={profile?.institution_name ?? ""}
          initialSchoolId={profile?.institution_id ?? null}
        />
      </div>

      <section className="saas-card relative mt-4 overflow-hidden">
        <SignOutButton />
        <div className="border-t border-hairline">
          <ReplayOnboarding />
        </div>
      </section>

      <DeleteAccount email={user?.email ?? ""} />
    </div>
  );
}

function barTone(level: string): string {
  switch (level) {
    case "new":
      return "bg-ink-tertiary/30";
    case "learning":
      return "bg-ink-tertiary/55";
    case "review":
      return "bg-ink-secondary/70";
    default:
      return "bg-ink";
  }
}
