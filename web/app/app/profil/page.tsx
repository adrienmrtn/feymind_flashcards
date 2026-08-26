import Link from "next/link";

import {
  DEFAULT_DAILY_MINUTES,
  DEFAULT_SHEET_LENGTH,
  countryFor,
  isSheetLength,
  newCardsPerDay,
  resolveStage,
} from "@micabo/core";

import { ProfileSettings } from "@/components/app/ProfileSettings";
import { listAllCards, listCourses, listExams } from "@/lib/data/courses";
import { createClient } from "@/lib/supabase/server";

/**
 * Le profil : **un tableau de bord**, pas une pile de blocs gris.
 *
 * Trois chiffres en tête, l'acquis mis en avant parce que c'est le seul qui dise si le travail
 * paye, puis ce que Micabo sait de l'étudiant, puis les réglages. Ce qui était là avant alignait
 * six rangées d'égale importance dans une liste : tout y avait le même poids, donc rien ne se
 * lisait.
 *
 * Tout vient de **Supabase**, y compris les réglages qu'on modifie ici : c'est la même table que
 * l'iPhone lit et écrit.
 */
export default async function ProfilePage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const [profile, courses, cards, exams] = await Promise.all([
    user
      ? supabase
          .from("profiles")
          .select(
            "display_name, username, country_code, study_level, subjects, institution_name, daily_minutes, sheet_length",
          )
          .eq("id", user.id)
          .maybeSingle()
          .then((result) => result.data)
      : null,
    listCourses(),
    listAllCards(),
    listExams(),
  ]);

  const { count: reviews } = user
    ? await supabase
        .from("review_logs")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user.id)
    : { count: 0 };

  const country = countryFor(profile?.country_code);
  const stage = resolveStage(country.code, { level: profile?.study_level ?? null });
  const minutes = profile?.daily_minutes ?? DEFAULT_DAILY_MINUTES;
  const mature = cards.filter((card) => card.interval_days >= 21).length;
  const due = cards.filter((card) => new Date(card.due_date).getTime() <= Date.now()).length;
  const share = cards.length > 0 ? Math.round((mature / cards.length) * 100) : 0;
  const name = profile?.display_name ?? profile?.username ?? "Ton compte";

  return (
    <>
      <header className="flex flex-wrap items-center gap-4">
        {/* Une initiale sur un aplat de la palette : un avatar générique en niveaux de gris est le
            détail qui fait « écran de réglages ». */}
        <span
          aria-hidden
          className="flex h-14 w-14 shrink-0 items-center justify-center rounded-full bg-accent-soft text-[22px] font-bold text-accent"
        >
          {name.trim().charAt(0).toUpperCase() || "?"}
        </span>
        <div className="min-w-0">
          <h1 className="truncate text-[28px] font-bold leading-tight text-ink">{name}</h1>
          <p className="mt-1 text-[13.5px] text-ink-tertiary">
            <span className="emoji">{country.flag}</span> {country.name}
            {stage ? ` · ${stage.title}` : ""}
          </p>
        </div>
      </header>

      {/* La ligne qui dit si le travail paye. L'acquis passe devant le total : trois compteurs de
          même taille laissent chercher lequel compte. */}
      <section className="mt-9 grid gap-3 sm:grid-cols-[1.4fr_1fr_1fr]">
        <div className="rounded-group bg-ink p-6 text-on-ink">
          <p className="eyebrow text-on-ink-muted">Cartes acquises</p>
          <p className="numeral mt-3 text-[42px] font-bold leading-none">{mature}</p>
          <p className="mt-2 text-[13px] text-on-ink-muted">
            {cards.length === 0
              ? "Aucune carte pour l'instant."
              : `${share} % de tes ${cards.length} cartes ont dépassé trois semaines d'intervalle.`}
          </p>
        </div>

        <Tile value={courses.length} label={courses.length === 1 ? "cours" : "cours"} />
        <Tile value={reviews ?? 0} label={reviews === 1 ? "révision" : "révisions"} />
      </section>

      {due > 0 ? (
        <Link
          href="/app/reviser"
          className="pressable lift mt-3 flex items-center justify-between gap-4 rounded-group bg-accent-soft px-6 py-4"
        >
          <span className="text-[15px] font-semibold text-accent">
            <span className="numeral">{due}</span> carte{due > 1 ? "s" : ""} à revoir maintenant
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

      <div className="mt-10 grid gap-3 lg:grid-cols-2">
        <section>
          <p className="eyebrow mb-3 text-ink-tertiary">Ce que Micabo sait de toi</p>
          <dl className="paper divide-y divide-hairline overflow-hidden rounded-group bg-surface">
            <Row label="Matières" value={subjectsLabel(profile?.subjects)} />
            <Row label="École" value={profile?.institution_name ?? "non renseignée"} />
            <Row
              label="Rythme"
              value={`${minutes} min · ${newCardsPerDay(minutes)} cartes neuves par jour`}
            />
            <Row label="Langue des fiches" value={country.language === "fr" ? "Français" : "English"} />
          </dl>

          {/* Les examens ont leur propre onglet : le mode examen est la fonctionnalité que
              personne d'autre n'a, et une fonctionnalité rangée dans les réglages ne se trouve
              pas. Il n'en reste ici que le compte, et le lien. */}
          {exams.length > 0 ? (
            <Link
              href={"/app/examens" as never}
              className="pressable lift mt-3 flex items-center justify-between gap-4 rounded-group bg-surface px-5 py-4 paper"
            >
              <span className="text-[14.5px] text-ink">
                <span className="numeral font-semibold">{exams.length}</span> examen
                {exams.length > 1 ? "s" : ""} posé{exams.length > 1 ? "s" : ""}
              </span>
              <span className="text-[13px] text-ink-tertiary">Voir</span>
            </Link>
          ) : null}
        </section>

        <ProfileSettings
          initialName={profile?.display_name ?? ""}
          initialMinutes={minutes}
          initialLength={
            isSheetLength(profile?.sheet_length) ? profile.sheet_length : DEFAULT_SHEET_LENGTH
          }
        />
      </div>

      <p className="mt-12 text-[12.5px] text-ink-tertiary">
        <Link href="/" className="underline-draw">
          Le site
        </Link>
      </p>
    </>
  );
}

function Tile({ value, label }: { value: number; label: string }) {
  return (
    <div className="paper flex flex-col justify-center rounded-group bg-surface p-6">
      <p className="numeral text-[32px] font-bold leading-none text-ink">{value}</p>
      <p className="mt-1.5 text-[13px] text-ink-tertiary">{label}</p>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 px-5 py-3.5">
      <dt className="shrink-0 text-[13px] text-ink-tertiary">{label}</dt>
      <dd className="text-right text-[14.5px] font-medium text-ink">{value}</dd>
    </div>
  );
}

function subjectsLabel(subjects: string[] | null | undefined): string {
  if (!subjects?.length) return "aucune";
  const shown = subjects.slice(0, 4).join(", ");
  return subjects.length > 4 ? `${shown}, +${subjects.length - 4}` : shown;
}

function frenchDate(value: string): string {
  return new Date(`${value}T12:00:00`).toLocaleDateString("fr-FR", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}
