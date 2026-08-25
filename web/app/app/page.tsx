import Link from "next/link";

import { DEFAULT_DAILY_MINUTES, countryFor, newCardsPerDay, resolveStage } from "@micabo/core";

import { createClient } from "@/lib/supabase/server";

/**
 * L'entrée de l'app web — **et pour l'instant, la sortie du parcours.**
 *
 * Ce n'est pas encore le produit : les cours, la fiche, les cartes et la session arrivent à
 * l'étape 4. Cette page-là existe pour deux raisons, et ni l'une ni l'autre n'est décorative.
 *
 * D'abord, un parcours de neuf écrans qui se termine sur une page blanche est un parcours qu'on
 * regrette d'avoir fait. Ensuite, et surtout : elle **relit en base ce que le parcours a écrit**.
 * C'est la seule vérification qui compte pour l'étape 3 — pas que les écrans s'enchaînent, mais que
 * les réponses soient arrivées dans les colonnes que l'iPhone lit.
 */
export default async function AppHome() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Le filtre `id` est explicite, alors que le cloisonnement suffirait. C'est la leçon déjà écrite
  // côté iOS : une requête qui compte sur le cloisonnement pour ne pas ramasser les lignes des
  // autres est une requête qu'une politique ajoutée un jour recasse.
  const profile = user
    ? (
        await supabase
          .from("profiles")
          .select("country_code, study_level, subjects, institution_name, daily_minutes, onboarding_completed_at")
          .eq("id", user.id)
          .maybeSingle()
      ).data
    : null;

  const exam = user
    ? (
        await supabase
          .from("exams")
          .select("name, exam_date")
          .eq("user_id", user.id)
          .is("deleted_at", null)
          .order("exam_date", { ascending: true })
          .limit(1)
          .maybeSingle()
      ).data
    : null;

  const country = countryFor(profile?.country_code);
  const stage = resolveStage(country.code, { level: profile?.study_level ?? null });
  const minutes = profile?.daily_minutes ?? DEFAULT_DAILY_MINUTES;

  return (
    <main className="mx-auto max-w-[560px] px-screen py-20">
      <p className="eyebrow text-ink-tertiary">Ton parcours</p>
      <h1 className="mt-3 text-[32px] font-bold leading-tight text-ink">
        {user ? "Tout est prêt." : "Presque prêt."}
      </h1>

      {user ? (
        <>
          <p className="mt-4 text-[15px] leading-relaxed text-ink-secondary">
            Voici ce que Micabo sait de toi — relu en base, pas gardé en mémoire. Ton téléphone
            lira exactement les mêmes colonnes.
          </p>

          <dl className="paper mt-8 divide-y divide-hairline overflow-hidden rounded-group bg-surface">
            <Row label="Pays" value={`${country.flag} ${country.name}`} />
            <Row label="Niveau" value={stage ? `${stage.emoji} ${stage.title}` : "à préciser"} />
            <Row
              label="Matières"
              value={
                profile?.subjects?.length
                  ? `${profile.subjects.length} choisie${profile.subjects.length > 1 ? "s" : ""}`
                  : "aucune"
              }
            />
            <Row label="École" value={profile?.institution_name ?? "non renseignée"} />
            <Row
              label="Rythme"
              value={`${minutes} min par jour · ${newCardsPerDay(minutes)} cartes neuves`}
            />
            <Row
              label="Prochain examen"
              value={exam ? `${exam.name} · ${frenchDate(exam.exam_date)}` : "aucun"}
            />
          </dl>

          {profile?.subjects?.length ? (
            <div className="mt-3 flex flex-wrap gap-1.5">
              {profile.subjects.map((subject: string) => (
                <span
                  key={subject}
                  className="rounded-pill bg-surface-muted px-3 py-1.5 text-[13px] text-ink-secondary"
                >
                  {subject}
                </span>
              ))}
            </div>
          ) : null}
        </>
      ) : (
        <p className="mt-4 text-[15px] leading-relaxed text-ink-secondary">
          Tu n&apos;es pas connecté, donc tes réponses sont restées sur cet appareil. Elles
          rejoindront ton compte dès que tu en auras un — rien n&apos;est perdu.
        </p>
      )}

      <div className="mt-10 rounded-group bg-canvas-sage p-6">
        <p className="eyebrow text-ink-tertiary">Ce qui arrive</p>
        <p className="mt-2.5 text-[15px] leading-relaxed text-ink-reading">
          L&apos;import d&apos;un cours, la fiche, les cartes et la session au clavier. C&apos;est
          l&apos;étape suivante, et elle demande d&apos;abord de fermer un trou de sécurité : les
          fonctions qui appellent le modèle acceptent aujourd&apos;hui la clé publique du site, sans
          plafond.
        </p>
      </div>

      <p className="mt-8 text-[13px] text-ink-tertiary">
        <Link href="/" className="underline-draw font-medium text-ink-secondary">
          Retour au site
        </Link>
      </p>
    </main>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 px-5 py-3.5">
      <dt className="text-[13px] text-ink-tertiary">{label}</dt>
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
