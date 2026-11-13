/**
 * **La porte du gratuit, côté client** (`docs/refonte-parcours.md` § 7) : une leçon offerte, à
 * vie, depuis un sujet tapé ou un texte collé ; les imports sont Pro. Le serveur tient la même
 * porte (`begin_lesson`) : celle-ci évite seulement un appel qui serait refusé, et le refus
 * tombe sur l'envoi, jamais au milieu d'un chemin. Jumeau de `LessonAllowance` côté Swift.
 */

/** D'où vient une leçon. La valeur brute part au serveur, qui en tire la porte du gratuit. */
export const LESSON_SOURCES = ["topic", "text", "pdf", "photo", "audio", "youtube", "docx", "mixed"] as const;
export type LessonSource = (typeof LESSON_SOURCES)[number];

/** Le gratuit écrit une leçon depuis un sujet ou un texte collé, et c'est tout. */
export function isImportSource(source: LessonSource): boolean {
  return source !== "topic" && source !== "text";
}

/** Le `courses.source` que prend une leçon selon ce qui l'a nourrie, comme `CourseSource`. */
export function courseSourceFor(source: LessonSource): string {
  switch (source) {
    case "pdf":
      return "pdf";
    case "photo":
      return "photo";
    case "youtube":
      return "youtube";
    case "docx":
      return "docx";
    default:
      return "text";
  }
}

/** Ce dont la porte a besoin de savoir d'un cours existant. */
export interface CountedLesson {
  source: string;
  isFromLibrary: boolean;
}

/**
 * Vrai quand l'élève a déjà un cours à lui : une leçon créée, un ancien cours importé ou
 * généré. Les cours de démonstration, de la bibliothèque et les paquets faits à la main ne
 * comptent pas, comme côté serveur (`begin_lesson`).
 */
export function hasUsedFreeLesson(courses: readonly CountedLesson[]): boolean {
  return courses.some((course) => !course.isFromLibrary && !["sample", "library", "deck"].includes(course.source));
}

export type LessonGateVerdict = "import_pro" | "free_limit";

/** Le paywall à ouvrir avant d'envoyer, ou `null` si la demande peut partir. */
export function lessonGate(options: {
  isPro: boolean;
  source: LessonSource;
  courses: readonly CountedLesson[];
}): LessonGateVerdict | null {
  if (options.isPro) return null;
  if (isImportSource(options.source)) return "import_pro";
  return hasUsedFreeLesson(options.courses) ? "free_limit" : null;
}

/**
 * **La porte de la barre de Home, avec la leçon offerte depuis un import**
 * (`docs/refonte-knowunity.md` § 7). Le serveur accepte déjà qu'une leçon offerte vienne d'un
 * PDF, de photos ou de YouTube quand la demande porte `onboarding: true`
 * (`begin_lesson(p_onboarding)`). Tant que la leçon offerte n'a pas servi, un élève qui n'est
 * pas Pro peut donc la créer depuis un import, et cette demande-là porte `onboarding: true` ;
 * une fois la leçon offerte utilisée, un import ouvre le paywall comme avant.
 *
 * `lessonGate` reste la porte d'avant ce lot, celle que relit le test de parité avec le Swift.
 */
export interface ComposerGate {
  /** Le paywall à ouvrir avant d'envoyer, ou `null` si la demande peut partir. */
  verdict: LessonGateVerdict | null;
  /** Vrai quand la demande doit porter `onboarding: true` : la leçon offerte, depuis un import. */
  onboarding: boolean;
}

export function composerGate(options: { isPro: boolean; source: LessonSource; hasUsedFreeLesson: boolean }): ComposerGate {
  if (options.isPro) return { verdict: null, onboarding: false };
  if (isImportSource(options.source)) {
    return options.hasUsedFreeLesson ? { verdict: "import_pro", onboarding: false } : { verdict: null, onboarding: true };
  }
  return { verdict: options.hasUsedFreeLesson ? "free_limit" : null, onboarding: false };
}

/**
 * Vrai quand une pastille d'import (PDF, Photo, Audio, YouTube) ouvre le paywall au lieu de sa
 * feuille, et porte la couronne : pour qui n'est pas Pro **et** a déjà utilisé sa leçon offerte.
 */
export function importLocked(options: { isPro: boolean; hasUsedFreeLesson: boolean }): boolean {
  return !options.isPro && options.hasUsedFreeLesson;
}

/** Ce que Mika laisse demander : une question offerte, puis un plafond par jour pour Pro. */
export const MIKA_ALLOWANCE = { freeQuestions: 1, proMessagesPerDay: 30 } as const;

/**
 * Les suppléments d'une leçon, tenus par `begin_extra` : un lot de nouvelles questions et un
 * examen blanc offerts, puis un plafond par jour pour Pro (migration `lesson_extras`).
 */
export const EXTRA_ALLOWANCE = {
  freePractice: 1,
  freeExams: 1,
  proPracticePerDay: 40,
  proExamsPerDay: 10,
} as const;
