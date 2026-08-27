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
} from "@micabo/core";

import { DeleteAccount } from "@/components/app/DeleteAccount";
import { ProfileSettings } from "@/components/app/ProfileSettings";
import { ReplayOnboarding } from "@/components/app/ReplayOnboarding";
import { listCardSnapshots, listCourses, listExams } from "@/lib/data/courses";
import { loadNewCardBudget } from "@/lib/data/reviews";
import { currentUser } from "@/lib/data/user";
import { createClient } from "@/lib/supabase/server";

/**
 * Le profil : **un tableau de bord**.
 *
 * La série d'abord, le volume de cartes ensuite, puis ce que le travail a
 * vraiment produit : les cartes les plus passées, et la répartition par
 * niveau de connaissance. Les compteurs de révisions et d'acquis n'y sont
 * plus — ils ne disaient rien qu'on ne lise déjà dans ces deux blocs.
 */
export default async function ProfilePage() {
  const supabase = await createClient();
  const user = await currentUser();

  const [profile, courses, cards, exams, logs, budget] = await Promise.all([
    user
      ? supabase
          .from("profiles")
          .select(
            "display_name, username, country_code, study_level, subjects, institution_name, institution_id, daily_minutes, sheet_length",
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
    <>
      <header className="flex flex-wrap items-center gap-4">
        <span
          aria-hidden
          className="flex h-14 w-14 shrink-0 items-center justify-center rounded-full bg-accent-soft text-[22px] font-bold text-accent"
        >
          {name.trim().charAt(0).toUpperCase() || "?"}
        </span>
        <div className="min-w-0">
          <h1 className="truncate text-[28px] font-bold leading-tight text-ink">{name}</h1>
          <p className="mt-1 text-[13.5px] text-ink-tertiary">
            {handle ? <span className="font-medium text-ink">@{handle}</span> : null}
            {handle ? " · " : null}
            <span className="emoji">{country.flag}</span> {country.name}
            {stage ? ` · ${stage.title}` : ""}
          </p>
        </div>
      </header>

      <section className="mt-9 grid gap-3 sm:grid-cols-[1.4fr_1fr]">
        <div className="hover-tile rounded-group bg-ink p-6 text-on-ink">
          <p className="eyebrow text-on-ink-muted">🔥 Série</p>
          <p className="numeral mt-3 text-[42px] font-bold leading-none">{series}</p>
          <p className="mt-2 text-[13px] text-on-ink-muted">
            {series === 0
              ? "Ta première carte notée lance la série."
              : series === 1
                ? "1 jour de série"
                : `${series} jours de série`}
            {record > series ? ` · record ${record}` : ""}
          </p>
        </div>

        <Tile
          value={cards.length}
          label={cards.length === 1 ? "🃏 carte" : "🃏 cartes"}
          hint={courses.length === 1 ? "1 cours" : `${courses.length} cours`}
        />
      </section>

      {due > 0 ? (
        <Link
          href="/app/reviser"
          className="pressable lift mt-3 flex items-center justify-between gap-4 rounded-group bg-accent-soft px-6 py-4"
        >
          <span className="text-[15px] font-semibold text-accent">
            ⚡ <span className="numeral">{due}</span> carte{due > 1 ? "s" : ""} à revoir maintenant
          </span>
          <svg
            aria-hidden
            viewBox="0 0 20 20"
            className="h-4 w-4 shrink-0 text-accent"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M4 10h11M11 5l5 5-5 5" />
          </svg>
        </Link>
      ) : null}

      <section className="mt-8">
        <p className="eyebrow mb-3 text-ink-tertiary">Niveau de connaissance</p>
        {cards.length === 0 ? (
          <p className="paper rounded-group bg-surface px-5 py-4 text-[14.5px] text-ink-secondary">
            Tes cartes se rangeront ici : nouvelles, en cours, en révision, parfaitement
            maîtrisées.
          </p>
        ) : (
            <div className="paper hover-tile rounded-group bg-surface px-5 py-5">
            <div className="flex h-36 items-end gap-3">
              {levels.map((level) => (
                <div key={level.id} className="group flex min-w-0 flex-1 flex-col items-center gap-2">
                  <span className="numeral text-[13px] font-semibold text-ink">{level.count}</span>
                  <div className="flex h-24 w-full items-end">
                    <div
                      className={`w-full origin-bottom rounded-t-md transition-transform duration-hover ease-out-strong group-hover:scale-y-110 ${barTone(level.id)}`}
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
          </div>
        )}
      </section>

      <section className="mt-8">
        <p className="eyebrow mb-3 text-ink-tertiary">Cartes les plus passées</p>
        {topCards.length === 0 ? (
          <p className="paper rounded-group bg-surface px-5 py-4 text-[14.5px] text-ink-secondary">
            Note tes premières cartes pour voir celles que tu revois le plus.
          </p>
        ) : (
          <ol className="paper divide-y divide-hairline overflow-hidden rounded-group bg-surface">
            {topCards.map((card, index) => (
              <li key={card.id} className="hover-row flex items-baseline gap-3.5 px-5 py-3.5">
                <span className="numeral w-5 shrink-0 text-[13px] text-ink-tertiary">
                  {index + 1}
                </span>
                <span className="min-w-0 flex-1 truncate text-[14.5px] text-ink">{card.front}</span>
                <span className="shrink-0 text-[13px] text-ink-tertiary">
                  <span className="numeral font-medium text-ink">{card.passes}</span>{" "}
                  passage{card.passes > 1 ? "s" : ""}
                </span>
              </li>
            ))}
          </ol>
        )}
      </section>

      <div className="mt-10 grid gap-3 lg:grid-cols-2">
        <section>
          <p className="eyebrow mb-3 text-ink-tertiary">Ce que Micabo sait de toi</p>
          <Link
            href={"/app/amis" as never}
            className="pressable lift mb-3 flex items-center justify-between gap-4 rounded-group bg-surface px-5 py-4 paper"
          >
            <span className="text-[14.5px] text-ink">👋 Amis</span>
            <span className="text-[13px] text-ink-tertiary">
              {handle ? `@${handle}` : "Ajouter quelqu'un"}
            </span>
          </Link>

          <dl className="paper divide-y divide-hairline overflow-hidden rounded-group bg-surface">
            <Row
              label="🌐 Langue des fiches"
              value={country.language === "fr" ? "Français" : "English"}
            />
          </dl>

          {exams.length > 0 ? (
            <Link
              href={"/app/examens" as never}
              className="pressable lift mt-3 flex items-center justify-between gap-4 rounded-group bg-surface px-5 py-4 paper"
            >
              <span className="text-[14.5px] text-ink">
                📅 <span className="numeral font-semibold">{exams.length}</span> examen
                {exams.length > 1 ? "s" : ""} posé{exams.length > 1 ? "s" : ""}
              </span>
              <span className="text-[13px] text-ink-tertiary">Voir</span>
            </Link>
          ) : null}
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

      <section className="mt-10">
        <p className="eyebrow mb-3 text-ink-tertiary">Débogage</p>
        <ReplayOnboarding />
      </section>

      <DeleteAccount email={user?.email ?? ""} />
    </>
  );
}

function barTone(level: string): string {
  switch (level) {
    case "new":
      return "bg-ink-tertiary/35";
    case "learning":
      return "bg-accent";
    case "review":
      return "bg-caution";
    default:
      return "bg-ink";
  }
}

function Tile({ value, label, hint }: { value: number; label: string; hint?: string }) {
  return (
    <div className="paper hover-tile flex flex-col justify-center rounded-group bg-surface p-6">
      <p className="numeral text-[32px] font-bold leading-none text-ink">{value}</p>
      <p className="mt-1.5 text-[13px] text-ink-tertiary">{label}</p>
      {hint ? <p className="mt-1 text-[12px] text-ink-tertiary">{hint}</p> : null}
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="hover-row flex items-baseline justify-between gap-4 px-5 py-3.5">
      <dt className="shrink-0 text-[13px] text-ink-tertiary">{label}</dt>
      <dd className="text-right text-[14.5px] font-medium text-ink">{value}</dd>
    </div>
  );
}
