"use server";

import type { Route } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import { countryFor } from "@micabo/core";

import { shouldPreserveRemoteProfile } from "@/lib/auth/existing-account";
import { ONBOARDING_CREATE_COOKIE } from "@/lib/auth/onboarding-create";
import { ONBOARDING_REPLAY_COOKIE } from "@/lib/auth/onboarding-replay";
import { revalidateUserData } from "@/lib/data/cache";
import { createClient } from "@/lib/supabase/server";

/**
 * Le déversement des réponses du parcours en base.
 *
 * Il écrit dans **les mêmes colonnes que l'iPhone** - `country_code`, `study_level`, `subjects`,
 * `institution_id`, `institution_name`, `onboarding_completed_at` - parce que c'est ce qui fait
 * qu'un étudiant qui commence sur le web arrive **déjà configuré** sur son téléphone. La ligne
 * existe déjà : c'est le déclencheur `handle_new_user` qui l'a créée à l'inscription, ici comme
 * là-bas.
 *
 * Deux choses qu'il n'écrit pas, et il faut le dire :
 *
 * - **`daily_minutes` reste à son défaut.** Le parcours ne pose plus cette question - ni celle
 *   de la date d'examen : il montre ce que Micabo change, et le rythme se corrige dans les
 *   réglages. Quinze minutes valent huit cartes neuves par jour.
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
  /** Les jours sans révision, en numéros ISO : 1 pour lundi, 7 pour dimanche. */
  restDays?: number[];
  /** La moyenne d'aujourd'hui et celle qu'on vise, sur l'échelle 10-20 du produit. */
  currentScore?: number;
  targetScore?: number;
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

  const jar = await cookies();
  const replaying = jar.get(ONBOARDING_REPLAY_COOKIE)?.value === "1";
  if (!replaying && (await shouldPreserveRemoteProfile(supabase, user.id))) {
    jar.delete(ONBOARDING_CREATE_COOKIE);
    return { status: "saved" };
  }

  const profile: Record<string, unknown> = {
    id: user.id,
    onboarding_completed_at: new Date().toISOString(),
  };

  if (payload.country) profile.country_code = payload.country;
  if (payload.studyLevel) profile.study_level = payload.studyLevel;
  if (payload.subjects?.length) profile.subjects = payload.subjects;
  if (payload.institutionId) profile.institution_id = payload.institutionId;
  if (payload.institutionName) profile.institution_name = payload.institutionName;

  /**
   * Les jours de repos deviennent une semaine de minutes, lundi en premier.
   *
   * La colonne existait et attendait exactement ça : sept valeurs, zéro pour un jour sans
   * révision. C'est ce qui rend la question du parcours autre chose qu'un décor - le plan lit
   * cette semaine et ne pose rien sur les zéros. Les autres jours reprennent le rythme
   * quotidien du profil, qui est aussi ce qu'ils valaient sans cette ligne.
   */
  if (payload.restDays?.length) {
    const daily = await dailyMinutesOf(supabase, user.id);
    profile.weekly_minutes = Array.from({ length: 7 }, (_, index) =>
      payload.restDays!.includes(index + 1) ? 0 : daily,
    );
  }

  const { error: profileError } = await supabase
    .from("profiles")
    .upsert(profile, { onConflict: "id" });

  if (profileError) {
    return { status: "error", message: profileError.message };
  }

  jar.delete(ONBOARDING_REPLAY_COOKIE);
  jar.delete(ONBOARDING_CREATE_COOKIE);

  // Une date encore présente dans les réponses (un ancien parcours) crée une vraie ligne
  // dans `exams`. Le parcours actuel n'en pose plus : il montre l'exemple, et l'examen
  // se crée plus tard, dans l'app.
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
      target_score: 15,
      course_ids: [],
      is_planned: false,
    });
    examCreated = !examError;
  }

  // Le parcours écrit le pays, le niveau, l'école : les mêmes colonnes que l'app relit ensuite
  // depuis son cache. Sans ce mot, l'accueil pourrait s'ouvrir sur le profil d'avant.
  revalidateUserData(user.id, "profile");
  if (examCreated) revalidateUserData(user.id, "exams");

  return { status: "saved", examCreated };
}


/** Le rythme quotidien déjà déclaré, ou le défaut de la colonne. */
async function dailyMinutesOf(
  supabase: Awaited<ReturnType<typeof createClient>>,
  userId: string,
): Promise<number> {
  const { data } = await supabase
    .from("profiles")
    .select("daily_minutes")
    .eq("id", userId)
    .maybeSingle();
  const minutes = (data as { daily_minutes?: number } | null)?.daily_minutes;
  return typeof minutes === "number" && minutes > 0 ? minutes : 15;
}

/** Le nom du pays, pour l'afficher côté serveur si besoin. */
export async function countryName(code: string): Promise<string> {
  return countryFor(code).name;
}

/** Rouvre le parcours, même avec une session. Pour déboguer depuis le profil. */
export async function replayOnboarding(): Promise<never> {
  const jar = await cookies();
  jar.set(ONBOARDING_REPLAY_COOKIE, "1", {
    path: "/",
    maxAge: 60 * 60 * 12,
    sameSite: "lax",
    httpOnly: true,
  });
  redirect("/commencer/bienvenue" as Route);
}
