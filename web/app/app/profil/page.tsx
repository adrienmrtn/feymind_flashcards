import Link from "next/link";

import {
  DEFAULT_DAILY_MINUTES,
  countryFor,
  newCardsPerDay,
  resolveStage,
} from "@micabo/core";

import { listAllCards, listCourses, listExams } from "@/lib/data/courses";
import { createClient } from "@/lib/supabase/server";

/**
 * Le profil : **un tableau de bord**, pas un écran de réglages.
 *
 * C'est le rôle qu'il a dans l'app, et il vaut ici : les totaux, ce qui est en cours, et ce que
 * Micabo sait de l'étudiant. Les réglages viendront s'y accrocher, en haut à droite, comme
 * là-bas.
 *
 * La ligne qui compte est celle du profil relu **en base** : c'est la vérification qu'un compte
 * né sur le web arrive configuré sur le téléphone, dans les mêmes colonnes.
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

  return (
    <>
      <header>
        <p className="eyebrow text-ink-tertiary">{profile?.username ?? "Ton compte"}</p>
        <h1 className="mt-2 text-[32px] font-bold leading-tight text-ink">
          {profile?.display_name ?? "Profil"}
        </h1>
      </header>

      <dl className="mt-9 grid grid-cols-3 gap-3">
        <Total value={courses.length} label={courses.length === 1 ? "cours" : "cours"} />
        <Total value={cards.length} label="cartes" />
        <Total value={reviews ?? 0} label="révisions" />
      </dl>

      <p className="mt-3 text-[13px] text-ink-tertiary">
        Dont <span className="numeral font-semibold text-ink-secondary">{mature}</span> carte
        {mature > 1 ? "s" : ""} acquise{mature > 1 ? "s" : ""} — un intervalle qui a dépassé trois
        semaines.
      </p>

      <section className="mt-12">
        <p className="eyebrow text-ink-tertiary">Ce que Micabo sait de toi</p>
        <dl className="paper mt-4 divide-y divide-hairline overflow-hidden rounded-group bg-surface">
          <Row label="Pays" value={`${country.flag} ${country.name}`} />
          <Row label="Niveau" value={stage ? `${stage.emoji} ${stage.title}` : "à préciser"} />
          <Row
            label="Matières"
            value={
              profile?.subjects?.length
                ? profile.subjects.slice(0, 4).join(", ") +
                  (profile.subjects.length > 4 ? `, +${profile.subjects.length - 4}` : "")
                : "aucune"
            }
          />
          <Row label="École" value={profile?.institution_name ?? "non renseignée"} />
          <Row
            label="Rythme"
            value={`${minutes} min par jour · ${newCardsPerDay(minutes)} cartes neuves`}
          />
          <Row
            label="Langue des fiches"
            value={country.language === "fr" ? "Français" : "English"}
          />
        </dl>
        <p className="mt-3 text-[12.5px] leading-relaxed text-ink-tertiary">
          Ce sont les colonnes que ton téléphone lit aussi. Le stade d&apos;étude commande la
          rédaction des fiches, et le pays commande à la fois le système scolaire de référence et la
          langue.
        </p>
      </section>

      {exams.length > 0 ? (
        <section className="mt-12">
          <p className="eyebrow text-ink-tertiary">Examens</p>
          <div className="paper mt-4 divide-y divide-hairline overflow-hidden rounded-group bg-surface">
            {exams.map((exam) => (
              <Row
                key={exam.id}
                label={exam.name}
                value={`${frenchDate(exam.exam_date)}${exam.is_planned ? " · planifié" : ""}`}
              />
            ))}
          </div>
          <p className="mt-3 text-[12.5px] leading-relaxed text-ink-tertiary">
            Le mode examen — celui qui replanifie tout un jeu de cartes autour de la date — arrive
            avec l&apos;écran des examens. Un plan posé avant qu&apos;il y ait des cartes ne
            planifie rien.
          </p>
        </section>
      ) : null}

      <p className="mt-16 text-[12.5px] text-ink-tertiary">
        <Link href="/" className="underline-draw">
          Le site
        </Link>
      </p>
    </>
  );
}

function Total({ value, label }: { value: number; label: string }) {
  return (
    <div className="paper rounded-group bg-surface py-5 text-center">
      <dd className="numeral text-[28px] font-bold text-ink">{value}</dd>
      <dt className="mt-0.5 text-[12px] text-ink-tertiary">{label}</dt>
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

function frenchDate(value: string): string {
  return new Date(`${value}T12:00:00`).toLocaleDateString("fr-FR", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}
