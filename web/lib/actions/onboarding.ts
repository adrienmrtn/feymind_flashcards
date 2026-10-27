"use server";

import type { Route } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import { COUNTRIES, TARGET_SCORE_MIN, countryFor, isStudyLevel, type CountryCode, type EducationStage } from "@micabo/core";

import { shouldPreserveRemoteProfile } from "@/lib/auth/existing-account";
import { ONBOARDING_CREATE_COOKIE } from "@/lib/auth/onboarding-create";
import { ONBOARDING_REPLAY_COOKIE } from "@/lib/auth/onboarding-replay";
import { revalidateUserData } from "@/lib/data/cache";
import { getTranslator } from "@/lib/i18n/server";
import { stageAnswer } from "@/lib/lesson/learner";
import { updateLocalLearner } from "@/lib/lesson/learner-cookie";
import { installDemoLesson } from "@/lib/onboarding/demo-lesson";
import { cleanWorries, isDailyMinutes, isExamDate } from "@/lib/onboarding/questions";
import { stageOfTrack, trackById, yearById, type SchoolTrack } from "@/lib/onboarding/school-system";
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
 * Chaque réponse a une destination, et une seule :
 *
 * - **`profiles`** : le pays, le registre, les matières, l'école, le temps par jour
 *   (`daily_minutes`, que l'app relit pour doser les cartes neuves) et la semaine de révision
 *   (`weekly_minutes`, zéro les jours de repos) ;
 * - **le cookie `micabo.learner`** : ce que l'iPhone garde sur l'appareil - le palier exact, la
 *   filière et l'année, les deux moyennes, ce qui bloque. `generate-lesson` en tire le registre,
 *   la classe, les exemples et la façon d'expliquer (`lessonAudience`) ;
 * - **une ligne `exams`** quand une date d'examen a été donnée.
 *
 * **`learning_goals` reste vide**, et c'est voulu : la question des objectifs ne change ni la
 * leçon ni le plan, et le parcours ne pose plus de question qui ne mène nulle part.
 */

export interface OnboardingPayload {
  country?: string;
  /** Le registre (`StudyLevel`), ce que `profiles.study_level` porte. */
  studyLevel?: string;
  /** Le palier exact (`EducationStage.id`) : il reste sur l'appareil, comme sur l'iPhone. */
  stageId?: string;
  /** La filière et l'année (`SchoolTrack.id`, `SchoolYear.id`), pour les pays décrits en détail. */
  trackId?: string;
  yearId?: string;
  subjects?: string[];
  /** Ce qui bloque (`StudyWorry.rawValue`). */
  worries?: string[];
  /** Le temps par jour : 5, 10, 15 ou 30 minutes. */
  dailyMinutes?: number;
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
    // Le profil distant gagne, mais les moyennes répondues ici ne sont nulle part ailleurs :
    // elles restent sur cet appareil, comme sur l'iPhone. Le palier, lui, suivrait un registre
    // qui n'est peut-être plus le sien : il n'est pas gardé.
    await rememberLearner(user.id, payload, null, null);
    return { status: "saved" };
  }

  const profile: Record<string, unknown> = {
    id: user.id,
    onboarding_completed_at: new Date().toISOString(),
  };

  // **Le registre, pas le palier** : `study_level` porte `StudyLevel` (`lycee`, `prepa`…), le
  // vocabulaire que l'iPhone relit. Le palier exact, lui, reste sur l'appareil (le cookie, plus
  // bas), comme `micabo.onboarding.stage` sur l'iPhone.
  const country = COUNTRIES.some((entry) => entry.code === payload.country) ? (payload.country as CountryCode) : null;
  // La filière, quand le pays en a : c'est elle qui dit le palier, comme
  // `country.resolvedStage(id: nil, tier: track.tier, level: track.level)` sur l'iPhone.
  const track = country ? trackById(payload.trackId, country) : null;
  const stage = track && country ? stageOfTrack(country, track) : stageAnswer(payload.stageId, payload.country);
  const studyLevel = track?.level ?? stage?.level ?? (isStudyLevel(payload.studyLevel) ? payload.studyLevel : null);
  if (payload.country && COUNTRIES.some((entry) => entry.code === payload.country)) profile.country_code = payload.country;
  if (studyLevel) profile.study_level = studyLevel;
  if (payload.subjects?.length) profile.subjects = payload.subjects;
  if (payload.institutionId) profile.institution_id = payload.institutionId;
  if (payload.institutionName) profile.institution_name = payload.institutionName;
  if (isDailyMinutes(payload.dailyMinutes)) profile.daily_minutes = payload.dailyMinutes;

  /**
   * Les jours de repos deviennent une semaine de minutes, lundi en premier.
   *
   * La colonne existait et attendait exactement ça : sept valeurs, zéro pour un jour sans
   * révision. C'est ce qui rend la question du parcours autre chose qu'un décor - le plan lit
   * cette semaine et ne pose rien sur les zéros. Les autres jours reprennent le rythme
   * quotidien du profil, qui est aussi ce qu'ils valaient sans cette ligne.
   */
  if (payload.restDays?.length) {
    const daily = isDailyMinutes(payload.dailyMinutes) ? payload.dailyMinutes : await dailyMinutesOf(supabase, user.id);
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
  await rememberLearner(user.id, payload, stage, track);

  // **La leçon de démonstration**, pour qui arrive sans rien : le cycle de l'eau, prête, dans
  // la langue du parcours. Elle attend dans « Reprendre » sur Home. Qui a déjà une leçon n'en
  // reçoit pas une de plus.
  const { t, locale } = await getTranslator();
  await installDemoLesson(user.id, t, locale).catch(() => false);

  // **La date d'examen devient une vraie ligne `exams`** : c'est elle que le mode examen
  // compte à rebours et que le plan vise, avec la moyenne visée comme objectif.
  //
  // `is_planned` reste **faux**. Planifier veut dire déplacer les échéances de tout un jeu de
  // cartes, et il n'y a pas encore une seule carte : un plan posé sur rien n'est pas un plan.
  // Il se posera au premier import.
  let examCreated = false;
  if (isExamDate(payload.examDate)) {
    const target = payload.targetScore;
    const { error: examError } = await supabase.from("exams").insert({
      id: crypto.randomUUID(),
      user_id: user.id,
      name: payload.examName?.trim().slice(0, 80) || t("onboarding.examDefaultName"),
      exam_date: payload.examDate,
      intensity: "standard",
      target_score: typeof target === "number" && Number.isInteger(target) && target >= TARGET_SCORE_MIN && target <= 20 ? target : 15,
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


/**
 * **Ce que l'iPhone garde sur l'appareil**, gardé ici dans le cookie `micabo.learner` : le
 * palier exact et sa marche, la filière et l'année, les deux moyennes, ce qui bloque.
 * `generate-lesson` en tire le registre, la classe, le volume, le niveau des exemples et la
 * façon d'expliquer (`lessonAudience`). Sans lui, ces questions ne serviraient qu'à être posées.
 */
async function rememberLearner(
  userId: string,
  payload: OnboardingPayload,
  stage: EducationStage | null,
  track: SchoolTrack | null,
): Promise<void> {
  const score = (value: number | undefined) =>
    typeof value === "number" && Number.isInteger(value) && value >= TARGET_SCORE_MIN - 1 && value <= 20 ? value : undefined;
  const year = yearById(payload.yearId, track);
  const worries = cleanWorries(payload.worries);
  await updateLocalLearner(userId, {
    ...(stage ? { stageId: stage.id, tier: stage.tier } : {}),
    // Un palier choisi sans filière efface celle d'avant : elle dirait une autre classe.
    ...(track ? { trackId: track.id, yearId: year?.id ?? null } : stage ? { trackId: null, yearId: null } : {}),
    currentScore: score(payload.currentScore),
    targetScore: score(payload.targetScore),
    ...(worries.length > 0 ? { worries } : {}),
  }).catch(() => undefined);
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
