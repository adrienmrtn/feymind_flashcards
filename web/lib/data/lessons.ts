import "server-only";

import { cache } from "react";

import {
  readLessonPath,
  readLessonProgress,
  readThemeNotes,
  readThemeQuiz,
  readThemeStatus,
  type LessonPath,
  type LessonProgress,
  type ThemeNotes,
  type ThemeQuiz,
  type ThemeStatus,
} from "@micabo/core";

import { cachedRead, coursesTag, dataClient, userTag } from "@/lib/data/cache";
import { type CourseRow } from "@/lib/data/courses";
import { currentAccessToken, currentUserId } from "@/lib/data/user";

/**
 * **Les leçons, lues comme l'iPhone les lit.**
 *
 * Mêmes tables, mêmes colonnes : `courses` porte le plan, la progression, le ton, l'icône
 * et la dernière ouverture (`docs/refonte-parcours.md` § 8.2) ; `chapters` porte les thèmes,
 * chacun avec son icône, ses notes, ses questions et l'état de sa génération. Un cours d'avant
 * la refonte a un plan nul : c'est un ancien cours, qui se convertit à l'ouverture.
 *
 * Les mêmes règles que `courses.ts` : chaque requête porte son filtre `user_id`, chaque
 * lecture exclut `deleted_at`, et les listes stables passent par le cache de Next, tagué par
 * étudiant. Les JSON sont **lus par le noyau** (`readLessonPath`, `readThemeNotes`…) au moment
 * de la lecture : l'écran ne voit jamais un JSON brut.
 */

export interface LessonRow extends CourseRow {
  language: string | null;
  /** Le plan, ou `null` pour un ancien cours pas encore converti. */
  path: LessonPath | null;
  progress: LessonProgress;
  tone: string | null;
  icon: string | null;
  last_opened_at: string | null;
}

export interface ThemeRow {
  id: string;
  course_id: string;
  position: number;
  title: string;
  icon: string | null;
  /** Les notes au nouveau format, ou `null` pour un ancien chapitre qui garde sa fiche. */
  notes: ThemeNotes | null;
  quiz: ThemeQuiz | null;
  status: ThemeStatus;
  /** L'ancien format, `{"blocks": [...]}` : lu tel quel, affiché avec la même typographie. */
  sheet: unknown;
  updated_at: string;
}

const LESSON_COLUMNS =
  "id, title, subject, summary, emoji, accent_hex, source, visibility, is_from_library, view_count, adopt_count, created_at, updated_at, folder_id, language, path, progress, tone, icon, last_opened_at";

const THEME_COLUMNS = "id, course_id, position, title, icon, notes, quiz, status, sheet, updated_at";

interface RawLesson extends Omit<LessonRow, "path" | "progress"> {
  path: unknown;
  progress: unknown;
}

interface RawTheme extends Omit<ThemeRow, "notes" | "quiz" | "status"> {
  notes: unknown;
  quiz: unknown;
  status: unknown;
}

function readLesson(row: RawLesson): LessonRow {
  return { ...row, path: readLessonPath(row.path), progress: readLessonProgress(row.progress) };
}

function readTheme(row: RawTheme): ThemeRow {
  return {
    ...row,
    notes: readThemeNotes(row.notes),
    quiz: readThemeQuiz(row.quiz),
    status: readThemeStatus(row.status),
  };
}

async function reader(): Promise<{ userId: string; token: string } | null> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return null;
  return { userId, token };
}

/** Toutes les leçons, les plus récentes d'abord : l'onglet Leçons, Home, « Reprendre ». */
export async function listLessons(): Promise<LessonRow[]> {
  const auth = await reader();
  if (!auth) return [];

  return cachedRead(auth.userId, "lessons", [userTag(auth.userId), coursesTag(auth.userId)], async () => {
    const { data } = await dataClient(auth.token)
      .from("courses")
      .select(LESSON_COLUMNS)
      .eq("user_id", auth.userId)
      .is("deleted_at", null)
      .order("updated_at", { ascending: false });
    return ((data as unknown as RawLesson[] | null) ?? []).map(readLesson);
  });
}

/**
 * Une leçon, avec son plan et sa progression.
 *
 * **Pas de cache inter-requêtes**, mémoïsée par requête seulement : sa progression bouge à
 * chaque étape cochée, son plan arrive pendant qu'on la regarde (conversion, thèmes qui
 * s'écrivent), et un cache ici referait voir l'étape d'avant en revenant sur le chemin. C'est
 * la règle déjà posée pour la file de révision. Les listes, elles, restent en cache.
 */
export const getLesson = cache(async (id: string): Promise<LessonRow | null> => {
  const auth = await reader();
  if (!auth) return null;

  const { data } = await dataClient(auth.token)
    .from("courses")
    .select(LESSON_COLUMNS)
    .eq("user_id", auth.userId)
    .eq("id", id)
    .is("deleted_at", null)
    .maybeSingle();
  return data ? readLesson(data as unknown as RawLesson) : null;
});

/** Les thèmes d'une leçon, dans l'ordre du chemin. Même règle : lus frais. */
export const listThemes = cache(async (courseId: string): Promise<ThemeRow[]> => {
  const auth = await reader();
  if (!auth) return [];

  const { data } = await dataClient(auth.token)
    .from("chapters")
    .select(THEME_COLUMNS)
    .eq("user_id", auth.userId)
    .eq("course_id", courseId)
    .is("deleted_at", null)
    .order("position", { ascending: true });
  return ((data as unknown as RawTheme[] | null) ?? []).map(readTheme);
});
