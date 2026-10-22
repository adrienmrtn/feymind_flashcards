"use server";

import { revalidatePath } from "next/cache";

import { examResult, isCardOfQuestion, missedCardDraft, readExamPaper, tomorrowStart, type ExamPaperResult } from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { actionT } from "@/lib/i18n/action";
import { LESSON_EXAM_KIND } from "@/lib/lesson/exam";
import { createClient } from "@/lib/supabase/server";

/**
 * **Rendre une copie d'examen blanc**, et ce qui suit : le résultat, leçon par leçon, gardé
 * dans la ligne de la copie ; les erreurs qui deviennent des flashcards de leur leçon, dans
 * le bon thème, à revoir dès demain.
 */

export interface ExamAnswerInput {
  id: string;
  right: boolean;
  picked: number | null;
}

export interface FinishExamOutcome {
  status: "ok" | "error";
  result?: ExamPaperResult;
  message?: string;
}

async function session() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return { supabase, user };
}

async function readPaper(supabase: Awaited<ReturnType<typeof createClient>>, userId: string, paperId: string) {
  const { data } = await supabase
    .from("mock_sessions")
    .select("id, questions, answers, finished_at")
    .eq("user_id", userId)
    .eq("id", paperId)
    .eq("kind", LESSON_EXAM_KIND)
    .maybeSingle();
  const row = data as { id: string; questions: unknown; answers: unknown; finished_at: string | null } | null;
  if (!row) return null;
  const paper = readExamPaper(row.questions);
  return paper ? { row, paper } : null;
}

export async function finishExamPaper(paperId: string, rawAnswers: ExamAnswerInput[], seconds: number): Promise<FinishExamOutcome> {
  const { supabase, user } = await session();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };
  const found = await readPaper(supabase, user.id, paperId);
  if (!found) return { status: "error", message: await actionT("app.errors.examMissing") };

  const answers: ExamAnswerInput[] = (Array.isArray(rawAnswers) ? rawAnswers : [])
    .filter((answer) => answer && typeof answer.id === "string" && typeof answer.right === "boolean")
    .map((answer) => ({ id: answer.id, right: answer.right, picked: typeof answer.picked === "number" ? answer.picked : null }));
  const byId: Record<string, { right: boolean }> = {};
  for (const answer of answers) byId[answer.id] = { right: answer.right };
  const result = examResult(found.paper, byId, Math.min(found.paper.minutes * 60, Math.max(0, seconds)));

  const { error } = await supabase
    .from("mock_sessions")
    .update({
      answers,
      correct_count: result.correct,
      question_count: result.total,
      debrief: { title: result.title, lessons: result.lessons, seconds: result.seconds },
      finished_at: result.date,
      updated_at: result.date,
    })
    .eq("user_id", user.id)
    .eq("id", paperId);
  if (error) return { status: "error", message: error.message };
  revalidateUserData(user.id, "exams");
  revalidatePath("/app/examen");
  return { status: "ok", result };
}

/** Chaque question ratée devient une flashcard de sa leçon, dans le bon thème, à revoir dès demain. */
export async function addExamMissedCards(paperId: string): Promise<{ status: "ok" | "error"; added?: number; message?: string }> {
  const { supabase, user } = await session();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };
  const found = await readPaper(supabase, user.id, paperId);
  if (!found) return { status: "error", message: await actionT("app.errors.examMissing") };

  const answers = (Array.isArray(found.row.answers) ? found.row.answers : []) as ExamAnswerInput[];
  const right = new Set(answers.filter((answer) => answer.right).map((answer) => answer.id));
  const missed = found.paper.items.filter((item) => !right.has(item.question.id));
  if (missed.length === 0) return { status: "ok", added: 0 };

  const lessonIds = [...new Set(missed.map((item) => found.paper.lessons[item.lesson]?.courseId).filter((id): id is string => Boolean(id)))];
  const { data: cardRows } = await supabase
    .from("flashcards")
    .select("id, course_id, front, kind, due_date")
    .eq("user_id", user.id)
    .in("course_id", lessonIds)
    .is("deleted_at", null);
  const cards = ((cardRows ?? []) as { id: string; course_id: string; front: string; kind: string; due_date: string }[]).slice();
  const now = new Date();
  const tomorrow = tomorrowStart(now).toISOString();
  const inserts: Record<string, unknown>[] = [];
  const counts = new Map<string, number>();
  for (const card of cards) counts.set(card.course_id, (counts.get(card.course_id) ?? 0) + 1);

  for (const item of missed) {
    const lesson = found.paper.lessons[item.lesson];
    if (!lesson) continue;
    const existing = cards.find((card) => card.course_id === lesson.courseId && isCardOfQuestion(card, item.question));
    if (existing) {
      if (new Date(existing.due_date).getTime() > new Date(tomorrow).getTime()) {
        await supabase.from("flashcards").update({ due_date: tomorrow, updated_at: now.toISOString() }).eq("user_id", user.id).eq("id", existing.id);
      }
      continue;
    }
    const draft = missedCardDraft(item.question);
    const position = counts.get(lesson.courseId) ?? 0;
    counts.set(lesson.courseId, position + 1);
    const row = {
      id: crypto.randomUUID(),
      user_id: user.id,
      course_id: lesson.courseId,
      chapter_id: lesson.chapterIds[item.theme] ?? null,
      front: draft.front,
      back: draft.back,
      position,
      kind: draft.kind,
      choices: draft.choices,
      correct_choice_index: draft.correctChoiceIndex,
      state: "learning",
      due_date: tomorrow,
    };
    inserts.push(row);
    cards.push({ id: row.id, course_id: lesson.courseId, front: draft.front, kind: draft.kind, due_date: tomorrow });
  }
  if (inserts.length > 0) {
    const { error } = await supabase.from("flashcards").insert(inserts);
    if (error) return { status: "error", message: error.message };
  }
  revalidateUserData(user.id, "cards");
  return { status: "ok", added: inserts.length };
}
