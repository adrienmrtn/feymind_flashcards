import "server-only";

import { lessonCircles, lessonTone, migratedDone, normalizeSheet, type LessonTone, type PathCircle, type SheetBlock } from "@micabo/core";

import type { StepTheme } from "@/components/lesson/NotesCircle";
import { getLesson, listThemes, type LessonRow, type ThemeRow } from "@/lib/data/lessons";
import { getTranslator } from "@/lib/i18n/server";

/**
 * **Une leçon ouverte, lue d'un coup** : la leçon, ses thèmes, son chemin et sa progression,
 * dans la langue de l'élève. Ce que la page du chemin, celle d'une étape et les trois écrans
 * de la barre lisent tous pareil.
 */
export interface LessonContext {
  lesson: LessonRow & { path: NonNullable<LessonRow["path"]> };
  themes: ThemeRow[];
  circles: PathCircle[];
  /** Les étapes faites, anciennes progressions comprises. */
  done: string[];
  tone: LessonTone;
  t: Awaited<ReturnType<typeof getTranslator>>["t"];
  locale: Awaited<ReturnType<typeof getTranslator>>["locale"];
}

export async function loadLessonContext(id: string): Promise<LessonContext | null> {
  const [{ t, locale }, lesson] = await Promise.all([getTranslator(), getLesson(id)]);
  if (!lesson?.path) return null;
  const themes = await listThemes(lesson.id);
  const circles = lessonCircles(
    lesson.path,
    themes.map((theme) => ({ title: theme.title, icon: theme.icon })),
    { intro: t("lesson.circle.intro"), checkpoint: t("lesson.circle.checkpoint"), final: t("lesson.circle.final") },
  );
  const done = migratedDone(lesson.progress.done, circles, lesson.progress.finishedAt !== null);
  return { lesson: lesson as LessonContext["lesson"], themes, circles, done, tone: lessonTone(lesson.id, lesson.tone), t, locale };
}

/** Un thème, tel qu'une étape ou le lecteur des notes l'affiche. */
export function stepTheme(theme: ThemeRow): StepTheme {
  const sheet: SheetBlock[] = theme.notes || !theme.sheet ? [] : normalizeSheet(theme.sheet);
  return { id: theme.id, title: theme.title, icon: theme.icon, notes: theme.notes, sheet, status: theme.status, quiz: theme.quiz };
}

/** Les phrases de la leçon, sinon celles des thèmes. */
export function lessonTakeaways(context: LessonContext): string[] {
  if (context.lesson.path.takeaways.length > 0) return context.lesson.path.takeaways;
  return context.themes.map((theme) => theme.notes?.takeaways[0]).filter((line): line is string => Boolean(line)).slice(0, 5);
}
