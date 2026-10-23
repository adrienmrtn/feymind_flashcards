import "server-only";

import { progressive, questionIsValid, readLessonProgress, readQuizQuestion, readThemeQuiz, themeOfQuestion, type QuizQuestion, type ThemeQuiz } from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { actionT } from "@/lib/i18n/action";
import { lessonAudience } from "@/lib/lesson/audience";
import { examLineFor } from "@/lib/lesson/create";
import { readableFunctionError } from "@/lib/lesson/errors";
import { flatNotes } from "@/lib/lesson/exam";
import { createClient } from "@/lib/supabase/server";

/**
 * **Un lot de nouvelles questions d'entraînement**, écrit par Mika loin de celles déjà
 * posées et surtout sur les thèmes ratés (`generate-lesson`, stage `practice`). Les questions
 * rejoignent la réserve de leur thème : les quiz suivants les tirent aussi. Rend celles du
 * lot, à jouer tout de suite. Jumeau de `LessonBuilder.practice`.
 *
 * Un lot gratuit, puis Pro : la porte est tenue par le serveur (`begin_extra`).
 */
export interface PracticeOutcome {
  status: "ok" | "error";
  questions?: QuizQuestion[];
  message?: string;
  code?: string;
}

const PRACTICE_COUNT = 10;
const AVOID = 80;
const AVOID_CHARS = 200;
const NOTES_CHARS = 2_000;

export async function writePractice(lessonId: string): Promise<PracticeOutcome> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const [{ data: course }, { data: rows }] = await Promise.all([
    supabase.from("courses").select("id, title, subject, language, progress").eq("user_id", user.id).eq("id", lessonId).is("deleted_at", null).maybeSingle(),
    supabase.from("chapters").select("id, position, title, notes, sheet, quiz").eq("user_id", user.id).eq("course_id", lessonId).is("deleted_at", null).order("position", { ascending: true }),
  ]);
  const lesson = course as { id: string; title: string; subject: string | null; language: string | null; progress: unknown } | null;
  const chapters = (rows ?? []) as { id: string; position: number; title: string; notes: unknown; sheet: unknown; quiz: unknown }[];
  if (!lesson || chapters.length === 0) return { status: "error", message: await actionT("app.errors.courseMissing") };

  const quizzes: (ThemeQuiz | null)[] = chapters.map((chapter) => readThemeQuiz(chapter.quiz));
  const progress = readLessonProgress(lesson.progress);
  const themeIds = chapters.map((chapter) => chapter.id);
  const focus = [...new Set(progress.missed.map((id) => themeOfQuestion(id, themeIds)).filter((index) => index >= 0))].sort((a, b) => a - b);
  // Les mêmes coupes que `SupabaseLessonService.practice` : les quatre-vingts dernières
  // questions, deux cents caractères chacune, et deux mille caractères de notes par thème.
  const avoid = quizzes
    .flatMap((quiz) => quiz?.questions.map((question) => question.prompt) ?? [])
    .slice(-AVOID)
    .map((prompt) => prompt.slice(0, AVOID_CHARS));
  // L'examen à venir qui porte sur cette leçon, comme `LessonBuilder.practice` le passe.
  const audience = await lessonAudience({ exam: await examLineFor(supabase, user.id, lessonId) });

  const { data, error } = await supabase.functions.invoke("generate-lesson", {
    body: {
      ...audience,
      stage: "practice",
      lessonId,
      lessonTitle: lesson.title,
      subject: lesson.subject ?? "",
      practiceThemes: chapters.map((chapter) => ({ title: chapter.title, notes: flatNotes(chapter).slice(0, NOTES_CHARS) })),
      focus,
      avoid,
      count: PRACTICE_COUNT,
    },
  });
  if (error) {
    const refusal = await readableFunctionError(error);
    return { status: "error", message: refusal.message, ...(refusal.code ? { code: refusal.code } : {}) };
  }

  const stamp = (Math.floor(Date.now() / 1000) % 1_000_000).toString(36);
  const generated = (Array.isArray((data as { questions?: unknown } | null)?.questions) ? (data as { questions: unknown[] }).questions : []) as Record<string, unknown>[];
  const added: QuizQuestion[] = [];
  const updates = new Map<number, ThemeQuiz>();
  generated.forEach((item, number) => {
    const index = typeof item.theme === "number" && item.theme >= 0 && item.theme < chapters.length ? item.theme : 0;
    const chapter = chapters[index]!;
    const question = readQuizQuestion({ ...item, id: `${chapter.id}:p${stamp}${number}` });
    if (!question || !questionIsValid(question)) return;
    const quiz = updates.get(index) ?? { questions: [...(quizzes[index]?.questions ?? [])] };
    quiz.questions.push(question);
    updates.set(index, quiz);
    added.push(question);
  });
  if (added.length === 0) return { status: "error", message: await actionT("lesson.practice.failed") };

  const now = new Date().toISOString();
  for (const [index, quiz] of updates) {
    await supabase.from("chapters").update({ quiz, updated_at: now }).eq("user_id", user.id).eq("id", chapters[index]!.id);
  }
  await supabase.from("courses").update({ updated_at: now }).eq("user_id", user.id).eq("id", lessonId);
  revalidateUserData(user.id, "courses");
  return { status: "ok", questions: progressive(added) };
}
