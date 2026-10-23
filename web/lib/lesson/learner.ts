import {
  COUNTRIES,
  FALLBACK_COUNTRY,
  QUIZ_KINDS,
  countryFor,
  desiredGradeLabel,
  isContentLanguage,
  isStudyLevel,
  languageFor,
  resolveStage,
  stagesFor,
  type CountryCode,
  type EducationStage,
  type EducationTier,
  type StudyLevel,
} from "@micabo/core";

import { BELOW_SCORE, gradeChoices } from "@/lib/onboarding/grades";
import { cleanWorries } from "@/lib/onboarding/questions";
import { trackById, trackTier, yearById } from "@/lib/onboarding/school-system";

/**
 * **Pour qui on écrit, calculé comme l'iPhone le calcule** (`LessonAudience.current`, dans
 * `Micabo/Services/Lesson/LessonService.swift`).
 *
 * Le serveur (`supabase/functions/_shared/learner.ts`) règle le registre, le volume et la
 * profondeur des notes sur la **marche** (`tier`) et la classe ; il pose les exemples sur la
 * moyenne et l'objectif. Le site n'envoyait que le registre et le pays, avec la langue de
 * l'interface : un collégien de 4e recevait des notes de lycéen, et un Allemand qui lit le site
 * en anglais des fiches en anglais. Ce module rend la même charge que l'app, champ par champ.
 *
 * Tout est pur : la lecture du profil et du cookie se fait dans `audience.ts`, et ce qui se
 * décide ici se teste sans base (`learner.test.ts`).
 */

/** Ce que l'iPhone garde sur l'appareil et que `profiles` ne transporte pas. */
export interface LocalLearner {
  /** Le compte qui a répondu : un autre compte ouvert dans le même navigateur ne l'hérite pas. */
  userId?: string;
  /** Le palier exact (`fr.lycee`, `us.middle`), quand il a été choisi sur ce navigateur. */
  stageId?: string;
  tier?: EducationTier;
  /** La filière (`fr.lyceeGeneral`) et l'année (`fr.terminale`), pour les pays décrits en détail. */
  trackId?: string;
  yearId?: string;
  /** La moyenne d'aujourd'hui et celle qu'on vise, sur l'échelle 10-20 du produit (9 : en dessous). */
  currentScore?: number;
  targetScore?: number;
  /** Ce qui l'inquiète (`StudyWorry.rawValue`), demandé par le parcours (`/commencer/freins`). */
  worries?: string[];
}

/** Les colonnes de `profiles` que l'audience lit. */
export interface AudienceProfile {
  study_level: string | null;
  country_code: string | null;
  sheet_language: string | null;
}

/** Ce qui part à `generate-lesson`, avec les mêmes clés que `LessonAudience.payload`. */
export interface LessonAudience {
  level: string;
  country: string;
  schoolStage: string;
  language: string;
  kinds: string[];
  tier?: string;
  track?: string;
  year?: string;
  exam?: string;
  currentScore?: number;
  targetScore?: number;
  scoreLabel?: string;
  targetLabel?: string;
  worries?: string[];
}

const TIERS: readonly EducationTier[] = [
  "lowerSecondary",
  "upperSecondary",
  "preUniversity",
  "undergraduate",
  "graduate",
  "health",
  "competitive",
  "other",
];

export function isEducationTier(value: unknown): value is EducationTier {
  return typeof value === "string" && TIERS.includes(value as EducationTier);
}

/**
 * Le registre d'une marche, **la table d'Android** (`LessonRepository.levelOf`) : Android écrit
 * la marche dans `study_level`, et il faut la relire comme le registre qu'elle désigne.
 */
const LEVEL_OF_TIER: Record<EducationTier, StudyLevel> = {
  lowerSecondary: "lycee",
  upperSecondary: "lycee",
  preUniversity: "prepa",
  undergraduate: "licence",
  graduate: "master",
  health: "sante",
  competitive: "concours",
  other: "other",
};

/** Un palier, d'où qu'il vienne : son identifiant porte son pays (`us.middle`). */
export function stageById(id: string | null | undefined): EducationStage | null {
  if (!id) return null;
  for (const country of COUNTRIES) {
    const found = stagesFor(country.code).find((stage) => stage.id === id);
    if (found) return found;
  }
  return null;
}

/**
 * **`profiles.study_level`, quelle que soit la main qui l'a écrit.**
 *
 * La colonne est le registre (`StudyLevel` : `lycee`, `prepa`…), c'est ce que l'iPhone écrit et
 * relit. Deux autres écritures y traînent, et elles ne doivent pas faire écrire une leçon pour
 * « un apprenant dont le niveau n'est pas connu » :
 *
 * - **la marche**, écrite par Android (`upperSecondary`) ;
 * - **l'identifiant du palier**, écrit par l'ancien réglage du site (`fr.lycee`).
 */
export function readStudyLevel(raw: string | null | undefined): {
  level: StudyLevel | null;
  tier: EducationTier | null;
  stageId: string | null;
} {
  const value = raw?.trim() ?? "";
  if (!value) return { level: null, tier: null, stageId: null };
  if (isStudyLevel(value)) return { level: value, tier: null, stageId: null };
  if (isEducationTier(value)) return { level: LEVEL_OF_TIER[value], tier: value, stageId: null };
  const stage = stageById(value);
  if (stage) return { level: stage.level, tier: stage.tier, stageId: stage.id };
  return { level: null, tier: null, stageId: null };
}

/** Le pays du profil, ou la France quand il n'a rien dit — le repli de `SchoolingCountry`. */
export function audienceCountry(code: string | null | undefined): CountryCode {
  return COUNTRIES.some((country) => country.code === code) ? (code as CountryCode) : FALLBACK_COUNTRY;
}

/**
 * **Le palier, résolu comme `OnboardingPreferences.educationStage`** : l'identifiant choisi ici
 * d'abord, puis la marche, puis le registre seul.
 *
 * Le palier local ne vaut que s'il dit encore le registre du profil. C'est la règle de
 * `ProfileRecord.applyToLocalPreferences` : un registre changé ailleurs efface le palier de
 * l'appareil, sinon un « Middle school » d'hier l'emporterait sur le « master » d'aujourd'hui.
 */
export function learnerStage(
  profile: Pick<AudienceProfile, "study_level" | "country_code"> | null,
  local: LocalLearner | null,
): { stage: EducationStage | null; tier: EducationTier | null; level: StudyLevel | null } {
  const country = audienceCountry(profile?.country_code);
  const stored = readStudyLevel(profile?.study_level);
  const localStage = stageById(local?.stageId);
  const trusted = localStage && stored.level && localStage.level === stored.level ? localStage : null;
  const localTier = trusted ? trusted.tier : null;
  const tier = localTier ?? stored.tier;
  const stage = resolveStage(country, {
    id: trusted?.id ?? stored.stageId,
    tier,
    level: stored.level,
  });
  return { stage, tier, level: stored.level };
}

/**
 * La langue des notes : **la langue des fiches choisie, sinon celle du pays.** C'est
 * `OnboardingPreferences.contentLanguage`. La langue de l'interface n'entre en jeu que sans
 * profil du tout : un Allemand qui lit le site en anglais reçoit ses fiches en allemand, comme
 * sur son téléphone.
 */
export function audienceLanguage(profile: Pick<AudienceProfile, "sheet_language" | "country_code"> | null, uiLocale: string): string {
  if (!profile) return uiLocale;
  if (isContentLanguage(profile.sheet_language)) return profile.sheet_language;
  return languageFor(audienceCountry(profile.country_code));
}

/**
 * Le libellé d'une note dans le barème du pays (`LessonAudience.gradeLabel`). Le cran hors
 * barème s'écrit « < 10/20 » : le serveur le lit dans toutes les langues.
 */
export function audienceGradeLabel(score: number, country: string): string {
  if (score <= BELOW_SCORE) return `< ${gradeChoices(country)[0]?.label ?? ""}`;
  return desiredGradeLabel(score, country);
}

function readScore(value: unknown): number | undefined {
  return typeof value === "number" && Number.isInteger(value) && value >= BELOW_SCORE && value <= 20 ? value : undefined;
}

/**
 * **La charge envoyée au serveur**, clé pour clé comme `LessonAudience.payload` : les champs
 * vides ne partent pas, et `kinds` dit les cinq formes de question que le site sait afficher.
 *
 * **La filière et l'année** partent quand le parcours les a demandées (France, Turquie,
 * Allemagne, Espagne), et seulement si elles disent encore le registre du profil : la même règle
 * que pour le palier. Leur marche l'emporte sur celle du palier - un collégien reste un collégien
 * même là où le pays n'a que « Lycée » comme palier (`LessonAudience.tier(track:year:)`).
 *
 * **Les notes partent sur l'échelle 10-20 du produit**, comme l'iPhone les envoie, avec leur
 * libellé dans le barème du pays. Le serveur les lit sur cent (`readScore`) : voir le rapport —
 * c'est l'écart d'un seul endroit, côté serveur, et le site ne le corrige pas dans son coin pour
 * ne pas écrire des leçons différentes de celles de l'app.
 */
export function buildAudience(input: {
  profile: AudienceProfile | null;
  local: LocalLearner | null;
  uiLocale: string;
  exam?: string | null;
}): LessonAudience {
  const { profile } = input;
  const local = input.local;
  const country = audienceCountry(profile?.country_code);
  const { stage, tier, level } = learnerStage(profile, local);

  const audience: LessonAudience = {
    level: level ?? "",
    country,
    schoolStage: stage?.title ?? "",
    language: audienceLanguage(profile, input.uiLocale),
    kinds: [...QUIZ_KINDS],
  };
  const track = trackById(local?.trackId, country);
  const trustedTrack = track && level && track.level === level ? track : null;
  const year = yearById(local?.yearId, trustedTrack);
  const marche = trustedTrack ? trackTier(trustedTrack, year) : tier;
  if (marche) audience.tier = marche;
  if (trustedTrack) audience.track = trustedTrack.title;
  if (year) audience.year = year.title;
  if (input.exam) audience.exam = input.exam;

  const current = readScore(local?.currentScore);
  const target = readScore(local?.targetScore);
  if (current !== undefined) {
    audience.currentScore = current;
    audience.scoreLabel = audienceGradeLabel(current, country);
  }
  if (target !== undefined) {
    audience.targetScore = target;
    audience.targetLabel = audienceGradeLabel(target, country);
  }
  const worries = cleanWorries(local?.worries);
  if (worries.length > 0) audience.worries = worries;
  return audience;
}

// MARK: - Le cookie

/**
 * Le nom du cookie qui tient ce que l'iPhone garde dans `UserDefaults` : le palier exact, la
 * marche, la filière et l'année, les deux moyennes, les freins. Un cookie et pas une colonne : `profiles` ne transporte que le
 * registre, et ajouter une colonne demande une migration qu'aucun client ne lirait encore.
 */
export const LEARNER_COOKIE = "micabo.learner";

/** Le cookie relu, sans rien croire : une valeur hors forme est ignorée champ par champ. */
export function readLearnerCookie(raw: string | null | undefined, userId: string | null): LocalLearner | null {
  if (!raw) return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== "object") return null;
  const source = parsed as Record<string, unknown>;
  if (typeof source.u === "string" && userId && source.u !== userId) return null;
  const out: LocalLearner = {};
  if (typeof source.u === "string") out.userId = source.u;
  if (typeof source.s === "string" && stageById(source.s)) out.stageId = source.s;
  if (isEducationTier(source.t)) out.tier = source.t;
  if (typeof source.k === "string" && /^[a-z]{2}\.[A-Za-z0-9]{1,32}$/.test(source.k)) out.trackId = source.k;
  if (typeof source.y === "string" && /^[a-z]{2}\.[A-Za-z0-9.]{1,40}$/.test(source.y)) out.yearId = source.y;
  const current = readScore(source.c);
  const target = readScore(source.g);
  if (current !== undefined) out.currentScore = current;
  if (target !== undefined) out.targetScore = target;
  if (Array.isArray(source.w)) out.worries = source.w.filter((item): item is string => typeof item === "string").slice(0, 6);
  return out;
}

/** Le cookie écrit : des clés d'une lettre, il voyage avec chaque requête. */
export function writeLearnerCookie(learner: LocalLearner): string {
  const out: Record<string, unknown> = {};
  if (learner.userId) out.u = learner.userId;
  if (learner.stageId) out.s = learner.stageId;
  if (learner.tier) out.t = learner.tier;
  if (learner.trackId) out.k = learner.trackId;
  if (learner.yearId) out.y = learner.yearId;
  if (learner.currentScore !== undefined) out.c = learner.currentScore;
  if (learner.targetScore !== undefined) out.g = learner.targetScore;
  if (learner.worries?.length) out.w = learner.worries;
  return JSON.stringify(out);
}

/** Le palier choisi dans les réglages ou le parcours, avec ce que la colonne en garde. */
export function stageAnswer(stageId: string | null | undefined, country: string | null | undefined): EducationStage | null {
  const stage = stageById(stageId);
  if (!stage) return null;
  // Un palier d'un autre pays que celui du profil ne se garde pas : « us.middle » pour un
  // profil français serait relu comme un collège américain.
  const code = countryFor(country).code;
  return stage.id.startsWith(`${code}.`) || stagesFor(code).some((candidate) => candidate.id === stage.id) ? stage : null;
}
