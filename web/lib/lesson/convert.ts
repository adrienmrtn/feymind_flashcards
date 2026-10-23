import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import {
  normalizeIcon,
  readLessonPath,
  sheetToPlainText,
  stableTone,
  themeGroups,
  type LessonPath,
  type SheetBlock,
} from "@micabo/core";
import { normalizeSheet } from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { lessonAudience } from "@/lib/lesson/audience";
import { readableFunctionError } from "@/lib/lesson/errors";
import { guessIcon } from "@/lib/lesson/guess-icon";
import { actionT } from "@/lib/i18n/action";
import { splitChapters } from "@/lib/sheet/chapters";
import { createClient } from "@/lib/supabase/server";

/**
 * **Un ancien cours devient une leçon**, à sa première ouverture (`docs/refonte-parcours.md`
 * § 0, « Anciens cours »). Ses chapitres deviennent les étapes Notes, tels quels ; le modèle
 * ajoute ce qui manque : icônes, intro, conclusion, noms de paliers, questions, et des
 * flashcards aux chapitres qui en ont moins de trois. Rien de ce que l'élève a déjà n'est
 * réécrit. Jumeau de `LessonBuilder.convert` côté Swift.
 *
 * Le premier client qui ouvre le cours écrit le chemin ; l'autre le lit à la synchro suivante.
 * `begin_lesson` compte la conversion à part : elle ne touche pas la leçon offerte.
 *
 * **Sans le modèle** (`convertOffline`), les chapitres deviennent les étapes, les paliers se
 * calculent, les icônes se devinent. Pas de questions : les Checkpoints se passent, les cartes
 * du cours font les flashcards. L'élève n'est jamais bloqué devant son propre cours.
 */

export interface ConvertResult {
  status: "ok" | "error";
  message?: string;
  code?: string;
}

interface CourseForConversion {
  id: string;
  title: string;
  subject: string | null;
  language: string | null;
  context_text: string;
  sheet: unknown;
  path: unknown;
  icon: string | null;
  tone: string | null;
}

interface ChapterForConversion {
  id: string;
  position: number;
  title: string;
  sheet: unknown;
  icon: string | null;
}

const CHAPTER_TEXT = 3_000;

async function loadCourse(supabase: SupabaseClient, userId: string, lessonId: string) {
  const { data } = await supabase
    .from("courses")
    .select("id, title, subject, language, context_text, sheet, path, icon, tone")
    .eq("user_id", userId)
    .eq("id", lessonId)
    .is("deleted_at", null)
    .maybeSingle();
  return (data as CourseForConversion | null) ?? null;
}

/**
 * Les chapitres d'un ancien cours : ceux qu'il a, sinon ceux de sa fiche découpée à chaque
 * titre de partie, sinon un seul qui porte tout le cours (un paquet de cartes sans fiche).
 * Jumeau de `LessonBuilder.prepareChapters`.
 */
async function prepareChapters(
  supabase: SupabaseClient,
  userId: string,
  course: CourseForConversion,
): Promise<ChapterForConversion[]> {
  const { data: existing } = await supabase
    .from("chapters")
    .select("id, position, title, sheet, icon")
    .eq("user_id", userId)
    .eq("course_id", course.id)
    .is("deleted_at", null)
    .order("position", { ascending: true });
  const rows = (existing as ChapterForConversion[] | null) ?? [];
  if (rows.length > 0) return rows;

  const blocks: SheetBlock[] = course.sheet ? normalizeSheet(course.sheet) : [];
  const parts = splitChapters(blocks).filter((chapter) => chapter.blocks.length > 0);
  const chapters: ChapterForConversion[] =
    parts.length > 0
      ? parts.map((chapter, index) => ({
          id: crypto.randomUUID(),
          position: index,
          title: chapter.title ?? course.title,
          sheet: { blocks: chapter.blocks },
          icon: null,
        }))
      : [{ id: crypto.randomUUID(), position: 0, title: course.title, sheet: blocks.length > 0 ? { blocks } : null, icon: null }];

  const { error } = await supabase.from("chapters").insert(
    chapters.map((chapter) => ({
      id: chapter.id,
      user_id: userId,
      course_id: course.id,
      position: chapter.position,
      title: chapter.title,
      sheet: chapter.sheet,
      status: "ready",
    })),
  );
  if (error) throw new Error(error.message);

  // Les cartes sans chapitre rejoignent le seul chapitre : c'est ce qui fait leur Flashcards.
  if (chapters.length === 1) {
    await supabase
      .from("flashcards")
      .update({ chapter_id: chapters[0]!.id })
      .eq("user_id", userId)
      .eq("course_id", course.id)
      .is("chapter_id", null)
      .is("deleted_at", null);
  }
  return chapters;
}

function chapterText(chapter: ChapterForConversion): string {
  const blocks = chapter.sheet ? normalizeSheet(chapter.sheet) : [];
  return sheetToPlainText(blocks).trim();
}

/** Ce que le modèle lit d'un chapitre : son texte, sinon ses cartes, sinon le cours. */
function conversionText(
  chapter: ChapterForConversion,
  cards: readonly { front: string; back: string }[],
  course: CourseForConversion,
): string {
  const own = chapterText(chapter);
  if (own) return own.slice(0, CHAPTER_TEXT);
  const fromCards = cards
    .slice(0, 30)
    .map((card) => `${card.front} : ${card.back}`)
    .join("\n")
    .trim();
  if (fromCards) return fromCards.slice(0, CHAPTER_TEXT);
  return `${course.title}\n${course.context_text ?? ""}`.slice(0, CHAPTER_TEXT);
}

interface Conversion {
  icon: string;
  intro: { lines: string[]; minutes: number };
  takeaways: string[];
  groups: { name: string; themes: number[] }[];
  chapters: {
    icon: string;
    questions: { kind?: string; prompt: string; choices: string[]; answer: number; why: string; difficulty?: number; matches?: string[] }[];
    flashcards: { kind?: string; front: string; back: string }[];
  }[];
}

/** La conversion sans le modèle. Jumeau de `LessonBuilder.offlineConversion`. */
function offlineConversion(course: CourseForConversion, chapters: readonly ChapterForConversion[]): Conversion {
  const icon = course.icon || guessIcon(course.subject, course.title);
  const words = chapters.reduce((sum, chapter) => sum + chapterText(chapter).split(/\s+/).filter(Boolean).length, 0);
  return {
    icon,
    intro: { lines: [], minutes: Math.max(5, Math.floor(words / 180) + chapters.length * 3) },
    takeaways: [],
    groups: themeGroups(chapters.length).map((themes) => ({ name: "", themes })),
    chapters: chapters.map((chapter) => ({
      icon: chapter.icon || guessIcon(course.subject, chapter.title),
      questions: [],
      flashcards: [],
    })),
  };
}

/** Écrit la conversion : le plan sur le cours, l'icône et les questions sur chaque thème. */
async function apply(
  supabase: SupabaseClient,
  userId: string,
  course: CourseForConversion,
  chapters: readonly ChapterForConversion[],
  conversion: Conversion,
  cardCounts: ReadonlyMap<string, number>,
): Promise<void> {
  const now = new Date().toISOString();
  for (const [index, chapter] of chapters.entries()) {
    const converted = conversion.chapters[index];
    if (!converted) continue;
    const questions = converted.questions.map((question, number) => ({
      id: `${chapter.id.toUpperCase()}:${number}`,
      kind: question.kind ?? "choice",
      prompt: question.prompt,
      choices: question.choices,
      answer: question.answer,
      why: question.why,
      matches: question.matches ?? [],
      difficulty: question.difficulty ?? 2,
    }));
    const { error } = await supabase
      .from("chapters")
      .update({
        icon: normalizeIcon(converted.icon),
        quiz: { questions },
        status: "ready",
        updated_at: now,
      })
      .eq("user_id", userId)
      .eq("id", chapter.id);
    if (error) throw new Error(error.message);

    if (converted.flashcards.length > 0) {
      const start = cardCounts.get(chapter.id) ?? 0;
      const { error: cardsError } = await supabase.from("flashcards").insert(
        converted.flashcards.map((card, offset) => ({
          id: crypto.randomUUID(),
          user_id: userId,
          course_id: course.id,
          chapter_id: chapter.id,
          front: card.front,
          back: card.back,
          position: start + offset,
          kind: card.kind === "cloze" ? "cloze" : "basic",
          state: "new",
          due_date: now,
        })),
      );
      if (cardsError) throw new Error(cardsError.message);
    }
  }

  const path: LessonPath = {
    version: 1,
    icon: normalizeIcon(conversion.icon),
    intro: conversion.intro,
    takeaways: conversion.takeaways,
    groups: conversion.groups,
    shortened: false,
    singleQuiz: false,
    status: "ready",
  };
  const { error } = await supabase
    .from("courses")
    .update({
      path,
      icon: course.icon || path.icon,
      tone: course.tone || stableTone(course.id),
      updated_at: now,
    })
    .eq("user_id", userId)
    .eq("id", course.id);
  if (error) throw new Error(error.message);
}

async function cardsByChapter(supabase: SupabaseClient, userId: string, courseId: string) {
  const { data } = await supabase
    .from("flashcards")
    .select("chapter_id, front, back")
    .eq("user_id", userId)
    .eq("course_id", courseId)
    .is("deleted_at", null)
    .order("position", { ascending: true });
  const byChapter = new Map<string, { front: string; back: string }[]>();
  const loose: { front: string; back: string }[] = [];
  for (const row of (data as { chapter_id: string | null; front: string; back: string }[] | null) ?? []) {
    if (!row.chapter_id) {
      loose.push(row);
      continue;
    }
    const list = byChapter.get(row.chapter_id) ?? [];
    list.push(row);
    byChapter.set(row.chapter_id, list);
  }
  return { byChapter, loose };
}

/** La conversion par le modèle. */
export async function convertLesson(lessonId: string): Promise<ConvertResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const course = await loadCourse(supabase, user.id, lessonId);
  if (!course) return { status: "error", message: await actionT("app.errors.courseMissing") };
  if (readLessonPath(course.path)) return { status: "ok" };

  let chapters: ChapterForConversion[];
  try {
    chapters = await prepareChapters(supabase, user.id, course);
  } catch (error) {
    return { status: "error", message: error instanceof Error ? error.message : String(error) };
  }
  const { byChapter, loose } = await cardsByChapter(supabase, user.id, course.id);
  const cardCounts = new Map<string, number>();
  for (const chapter of chapters) {
    cardCounts.set(chapter.id, (byChapter.get(chapter.id)?.length ?? 0) + (chapters.length === 1 ? loose.length : 0));
  }

  const audience = await lessonAudience({ language: course.language });
  const { data, error } = await supabase.functions.invoke("generate-lesson", {
    body: {
      stage: "convert",
      lessonId: course.id,
      title: course.title,
      subject: course.subject ?? undefined,
      chapters: chapters.map((chapter) => ({
        title: chapter.title,
        text: conversionText(chapter, [...(byChapter.get(chapter.id) ?? []), ...(chapters.length === 1 ? loose : [])], course),
        needsCards: (cardCounts.get(chapter.id) ?? 0) < 3,
      })),
      ...audience,
    },
  });

  if (error) {
    const readable = await readableFunctionError(error);
    return { status: "error", message: readable.message, code: readable.code };
  }
  const conversion = (data as { conversion?: Conversion } | null)?.conversion;
  if (!conversion || !Array.isArray(conversion.chapters)) {
    return { status: "error", message: await actionT("lesson.convert.failed") };
  }

  try {
    await apply(supabase, user.id, course, chapters, conversion, cardCounts);
  } catch (applyError) {
    return { status: "error", message: applyError instanceof Error ? applyError.message : String(applyError) };
  }
  revalidateUserData(user.id, "courses");
  revalidateUserData(user.id, "cards");
  return { status: "ok" };
}

/** La conversion sans le modèle : « Ouvrir sans attendre ». */
export async function convertLessonOffline(lessonId: string): Promise<ConvertResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const course = await loadCourse(supabase, user.id, lessonId);
  if (!course) return { status: "error", message: await actionT("app.errors.courseMissing") };
  if (readLessonPath(course.path)) return { status: "ok" };

  try {
    const chapters = await prepareChapters(supabase, user.id, course);
    const { byChapter, loose } = await cardsByChapter(supabase, user.id, course.id);
    const cardCounts = new Map<string, number>();
    for (const chapter of chapters) {
      cardCounts.set(chapter.id, (byChapter.get(chapter.id)?.length ?? 0) + (chapters.length === 1 ? loose.length : 0));
    }
    await apply(supabase, user.id, course, chapters, offlineConversion(course, chapters), cardCounts);
  } catch (error) {
    return { status: "error", message: error instanceof Error ? error.message : String(error) };
  }
  revalidateUserData(user.id, "courses");
  revalidateUserData(user.id, "cards");
  return { status: "ok" };
}
