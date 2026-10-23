import "server-only";

import { readExamPaper, type ExamLessonScore, type ExamPaperResult } from "@micabo/core";

import { cachedRead, dataClient, examsTag, userTag, rowsOrThrow } from "@/lib/data/cache";
import { currentAccessToken, currentUserId } from "@/lib/data/user";
import { LESSON_EXAM_KIND } from "@/lib/lesson/exam";

/**
 * **L'historique des examens blancs** de la refonte : les copies rendues (`mock_sessions`,
 * `kind` `lesson_exam`), lues comme des résultats. Les trente dernières suffisent à voir où
 * l'on en est, comme sur l'iPhone (`ExamHistory`).
 */
export const EXAM_HISTORY_LIMIT = 30;

interface Row {
  id: string;
  exam_id: string | null;
  minutes: number;
  question_count: number;
  correct_count: number;
  questions: unknown;
  debrief: unknown;
  finished_at: string | null;
}

export async function listLessonExamResults(): Promise<ExamPaperResult[]> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return [];

  const rows = await cachedRead(userId, "lesson-exams", [userTag(userId), examsTag(userId)], async () => {
    const data = rowsOrThrow(
      await dataClient(token)
        .from("mock_sessions")
        .select("id, exam_id, minutes, question_count, correct_count, questions, debrief, finished_at")
        .eq("user_id", userId)
        .eq("kind", LESSON_EXAM_KIND)
        .not("finished_at", "is", null)
        .order("finished_at", { ascending: false })
        .limit(EXAM_HISTORY_LIMIT),
      "lesson-exams",
    );
    return (data as Row[] | null) ?? [];
  });

  return rows.map((row) => {
    const paper = readExamPaper(row.questions);
    const debrief = (row.debrief ?? {}) as { title?: string; lessons?: ExamLessonScore[]; seconds?: number };
    return {
      id: row.id,
      examId: row.exam_id,
      title: debrief.title ?? paper?.title ?? "",
      date: row.finished_at ?? paper?.createdAt ?? new Date(0).toISOString(),
      correct: row.correct_count,
      total: row.question_count,
      seconds: typeof debrief.seconds === "number" ? debrief.seconds : 0,
      minutes: row.minutes,
      lessons: Array.isArray(debrief.lessons) ? debrief.lessons : [],
    };
  });
}
