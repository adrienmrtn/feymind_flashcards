import "server-only";

import { examQuestionCount, normalizeSheet, notesPlainText, readExamResponse, readThemeNotes, sheetToPlainText, type ExamPaper, type ExamPaperLesson } from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { actionT } from "@/lib/i18n/action";
import { lessonAudience } from "@/lib/lesson/audience";
import { examLine } from "@/lib/lesson/create";
import { readableFunctionError } from "@/lib/lesson/errors";
import { createClient } from "@/lib/supabase/server";

/**
 * **Une copie d'examen blanc** sur ces leçons, écrite par Mika au format de l'examen visé
 * (`generate-lesson`, stage `exam`). La copie est gardée en base (`mock_sessions`, `kind`
 * `lesson_exam`) : elle survit à un rechargement au milieu de l'épreuve, et son résultat
 * fait l'historique. Jumeau de `LessonBuilder.examPaper`.
 *
 * Un gratuit, puis Pro : la porte est tenue par le serveur (`begin_extra`), et son refus
 * revient avec son code.
 */
export const LESSON_EXAM_KIND = "lesson_exam";
const MAX_LESSONS = 8;
const MAX_THEMES = 14;

export interface ExamPaperOutcome {
  status: "ok" | "error";
  paper?: ExamPaper;
  message?: string;
  code?: string;
}

interface LessonRowForExam {
  id: string;
  title: string;
  subject: string | null;
  language: string | null;
}

interface ChapterRowForExam {
  id: string;
  course_id: string;
  position: number;
  title: string;
  notes: unknown;
  sheet: unknown;
}

/** Les notes d'un thème, mises à plat pour le modèle. */
export function flatNotes(chapter: Pick<ChapterRowForExam, "notes" | "sheet">): string {
  const notes = readThemeNotes(chapter.notes);
  if (notes) return notesPlainText(notes);
  return chapter.sheet ? sheetToPlainText(normalizeSheet(chapter.sheet)) : "";
}

export async function writeExamPaper(input: { title: string; examId: string | null; lessonIds: string[]; minutes: number }): Promise<ExamPaperOutcome> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const wanted = [...new Set(input.lessonIds.filter((id) => typeof id === "string"))].slice(0, MAX_LESSONS);
  if (wanted.length === 0) return { status: "error", message: await actionT("lesson.exam.noLessons") };
  const minutes = Math.min(120, Math.max(10, Math.round(input.minutes || 30)));

  const [{ data: lessonRows }, { data: chapterRows }, examRow] = await Promise.all([
    supabase.from("courses").select("id, title, subject, language").eq("user_id", user.id).in("id", wanted).is("deleted_at", null),
    supabase.from("chapters").select("id, course_id, position, title, notes, sheet").eq("user_id", user.id).in("course_id", wanted).is("deleted_at", null).order("position", { ascending: true }),
    input.examId
      ? supabase.from("exams").select("name, exam_date").eq("user_id", user.id).eq("id", input.examId).is("deleted_at", null).maybeSingle()
      : Promise.resolve({ data: null }),
  ]);
  const byId = new Map(((lessonRows ?? []) as LessonRowForExam[]).map((row) => [row.id, row]));
  const lessons = wanted.map((id) => byId.get(id)).filter((row): row is LessonRowForExam => row !== undefined);
  if (lessons.length === 0) return { status: "error", message: await actionT("lesson.exam.noLessons") };
  const chapters = (chapterRows ?? []) as ChapterRowForExam[];
  const chaptersOf = (lessonId: string) => chapters.filter((chapter) => chapter.course_id === lessonId).slice(0, MAX_THEMES);

  const exam = (examRow as { data?: { name: string; exam_date: string } | null } | null)?.data ?? null;
  const audience = await lessonAudience({ language: lessons[0]!.language, exam: exam ? examLine(exam.name, exam.exam_date) : undefined });
  const paperId = crypto.randomUUID();
  const paperLessons: ExamPaperLesson[] = lessons.map((lesson) => ({ courseId: lesson.id, title: lesson.title, chapterIds: chaptersOf(lesson.id).map((chapter) => chapter.id) }));

  const { data, error } = await supabase.functions.invoke("generate-lesson", {
    body: {
      stage: "exam",
      lessonId: paperId,
      examTitle: input.title,
      minutes,
      count: examQuestionCount(minutes),
      lessons: lessons.map((lesson) => ({
        title: lesson.title,
        subject: lesson.subject ?? undefined,
        themes: chaptersOf(lesson.id).map((chapter) => ({ title: chapter.title, notes: flatNotes(chapter) })),
      })),
      ...audience,
    },
  });
  if (error) {
    const refusal = await readableFunctionError(error);
    return { status: "error", message: refusal.message, ...(refusal.code ? { code: refusal.code } : {}) };
  }
  const paper = readExamResponse(data, { paperId, examId: input.examId, title: input.title, minutes, lessons: paperLessons });
  if (!paper) return { status: "error", message: await actionT("lesson.exam.failed") };

  const { error: insertError } = await supabase.from("mock_sessions").insert({
    id: paperId,
    user_id: user.id,
    exam_id: input.examId,
    kind: LESSON_EXAM_KIND,
    minutes,
    question_count: paper.items.length,
    correct_count: 0,
    questions: paper,
    answers: [],
    started_at: paper.createdAt,
  });
  if (insertError) return { status: "error", message: insertError.message };
  revalidateUserData(user.id, "exams");
  return { status: "ok", paper };
}
