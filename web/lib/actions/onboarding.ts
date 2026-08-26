"use server";

import { countryFor, newCardsPerDay, DEFAULT_DAILY_MINUTES } from "@micabo/core";

import { createClient } from "@/lib/supabase/server";

/**
 * Le déversement des réponses du parcours en base.
 *
 * Il écrit dans **les mêmes colonnes que l'iPhone** — `country_code`, `study_level`, `subjects`,
 * `institution_id`, `institution_name`, `onboarding_completed_at` — parce que c'est ce qui fait
 * qu'un étudiant qui commence sur le web arrive **déjà configuré** sur son téléphone. La ligne
 * existe déjà : c'est le déclencheur `handle_new_user` qui l'a créée à l'inscription, ici comme
 * là-bas.
 *
 * Deux choses qu'il n'écrit pas, et il faut le dire :
 *
 * - **`daily_minutes` reste à son défaut.** Le parcours ne pose pas la question — la date d'examen
 *   est une bien meilleure question que « combien de minutes par jour », et l'ajouter casserait le
 *   rythme du tunnel. Quinze minutes valent huit cartes neuves par jour, et ça se corrige dans les
 *   réglages.
 * - **`learning_goals` reste vide.** Le parcours web ne reprend ni les objectifs ni le rapport à
 *   l'oubli, et c'est sans conséquence : rien ne s'en sert dans la rédaction d'une fiche.
 */

export interface OnboardingPayload {
  country?: string;
  studyLevel?: string;
  subjects?: string[];
  institutionId?: string;
  institutionName?: string;
  examDate?: string;
  examName?: string;
}

export interface SaveResult {
  status: "saved" | "anonymous" | "error";
  message?: string;
  /** Vrai quand un examen a été créé. */
  examCreated?: boolean;
}

export async function saveOnboarding(payload: OnboardingPayload): Promise<SaveResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Pas de session : les réponses restent sur l'appareil et se déverseront à la connexion. Le
  // parcours doit rester traversable sans compte, sinon un fournisseur en panne le ferme.
  if (!user) return { status: "anonymous" };

  const profile: Record<string, unknown> = {
    id: user.id,
    onboarding_completed_at: new Date().toISOString(),
  };

  if (payload.country) profile.country_code = payload.country;
  if (payload.studyLevel) profile.study_level = payload.studyLevel;
  if (payload.subjects?.length) profile.subjects = payload.subjects;
  if (payload.institutionId) profile.institution_id = payload.institutionId;
  if (payload.institutionName) profile.institution_name = payload.institutionName;

  const { error: profileError } = await supabase
    .from("profiles")
    .upsert(profile, { onConflict: "id" });

  if (profileError) {
    return { status: "error", message: profileError.message };
  }

  // L'écran de la date d'examen crée une vraie ligne dans `exams`. C'est la seule chose que le
  // parcours écrit hors de `profiles`, et c'est ce qui rend la promesse tenable : « Micabo te
  // créera un parcours adapté à ton examen ».
  //
  // `is_planned` reste **faux**. Planifier veut dire déplacer les échéances de tout un jeu de
  // cartes, et il n'y a pas encore une seule carte : un plan posé sur rien n'est pas un plan.
  // Il se posera au premier import.
  let examCreated = false;
  if (payload.examDate) {
    const { error: examError } = await supabase.from("exams").insert({
      id: crypto.randomUUID(),
      user_id: user.id,
      name: payload.examName?.trim() || "Mon prochain examen",
      exam_date: payload.examDate,
      intensity: "standard",
      course_ids: [],
      is_planned: false,
    });
    examCreated = !examError;
  }

  return { status: "saved", examCreated };
}

/**
 * Ce que le rythme par défaut donne, pour l'annoncer sans mentir.
 *
 * Le parcours ne demande pas les minutes, donc il ne peut pas promettre un chiffre choisi par
 * l'étudiant — mais il peut dire ce que le défaut produit.
 */
export async function defaultPace(): Promise<{ minutes: number; newCards: number }> {
  return {
    minutes: DEFAULT_DAILY_MINUTES,
    newCards: newCardsPerDay(DEFAULT_DAILY_MINUTES),
  };
}

/** Le nom du pays, pour l'afficher côté serveur si besoin. */
export async function countryName(code: string): Promise<string> {
  return countryFor(code).name;
}
