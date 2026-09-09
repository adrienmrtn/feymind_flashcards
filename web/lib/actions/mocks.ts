"use server";

import { revalidatePath } from "next/cache";

import {
  asExamKind,
  drawMock,
  mockMinutes,
  mockQuestionCount,
  wantsMock,
} from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { actionT } from "@/lib/i18n/action";
import { createClient } from "@/lib/supabase/server";

/**
 * Ouvrir, remplir et fermer un examen blanc.
 *
 * Une session est **créée côté serveur avec son tirage**, et pas côté navigateur. Deux raisons :
 * le tirage doit survivre à un rechargement au milieu de l'épreuve, et laisser le client
 * choisir ses questions permettrait de retirer jusqu'à tomber sur les faciles - ce qui viderait
 * de son sens la seule mesure honnête du produit.
 *
 * Le score se calcule à la fermeture, sur ce qui a été répondu. Une session abandonnée reste
 * ouverte et ne compte pas : elle ne mesure rien.
 */

export interface MockResultAction {
  status: "ok" | "error";
  message?: string;
  sessionId?: string;
}

/** Une réponse enregistrée pendant la passation. */
export interface MockAnswer {
  card: string;
  correct: boolean;
}

export async function startMockSession(examId: string): Promise<MockResultAction> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const { data: examRow } = await supabase
    .from("exams")
    .select("id, kind, course_ids")
    .eq("user_id", user.id)
    .eq("id", examId)
    .is("deleted_at", null)
    .maybeSingle();

  const exam = examRow as { kind: string | null; course_ids: string[] | null } | null;
  if (!exam) return { status: "error", message: await actionT("app.errors.examMissing") };
  if (!wantsMock(asExamKind(exam.kind))) {
    return { status: "error", message: await actionT("app.errors.mockNotForKind") };
  }

  const courseIds = exam.course_ids ?? [];
  if (courseIds.length === 0) {
    return { status: "error", message: await actionT("app.errors.pickACourse") };
  }

  const { data: cardRows } = await supabase
    .from("flashcards")
    .select("id, course_id, kind, is_suspended")
    .eq("user_id", user.id)
    .in("course_id", courseIds)
    .is("deleted_at", null);

  const cards =
    (cardRows as { id: string; course_id: string | null; kind: string; is_suspended: boolean }[] | null) ??
    [];
  const usable = cards.filter((card) => !card.is_suspended);

  const questionCount = mockQuestionCount(usable.length);
  if (questionCount === 0) {
    return { status: "error", message: await actionT("app.errors.mockTooFewCards") };
  }

  const sessionId = crypto.randomUUID();
  const drawn = drawMock(
    usable.map((card) => ({
      id: card.id,
      courseId: card.course_id,
      kind: card.kind,
      isSuspended: card.is_suspended,
    })),
    courseIds,
    questionCount,
    sessionId,
  );

  const { error } = await supabase.from("mock_sessions").insert({
    id: sessionId,
    user_id: user.id,
    exam_id: examId,
    planned_for: new Date().toISOString().slice(0, 10),
    minutes: mockMinutes(drawn.length),
    question_count: drawn.length,
    correct_count: 0,
    // Le tirage est posé dès l'ouverture, sans réponse : c'est lui qui doit survivre au
    // rechargement, pas seulement le compte.
    answers: drawn.map((card) => ({ card, correct: false })),
  });

  if (error) return { status: "error", message: error.message };

  revalidateUserData(user.id, "exams");
  return { status: "ok", sessionId };
}

/**
 * Fermer la session et poser le score.
 *
 * On recompte côté serveur sur le tirage enregistré : le client envoie ce qu'il a répondu, il
 * ne dicte pas combien il a eu juste. Une réponse à une carte qui n'était pas au tirage est
 * ignorée.
 */
export async function finishMockSession(
  sessionId: string,
  answers: MockAnswer[],
): Promise<MockResultAction> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const { data: sessionRow } = await supabase
    .from("mock_sessions")
    .select("id, answers, question_count, finished_at")
    .eq("user_id", user.id)
    .eq("id", sessionId)
    .maybeSingle();

  const session = sessionRow as
    | { answers: { card: string }[]; question_count: number; finished_at: string | null }
    | null;
  if (!session) return { status: "error", message: await actionT("app.errors.mockMissing") };
  if (session.finished_at) return { status: "ok", sessionId };

  const drawn = new Set((session.answers ?? []).map((entry) => entry.card));
  const graded = (session.answers ?? []).map((entry) => ({
    card: entry.card,
    correct: answers.some(
      (answer) => answer.card === entry.card && answer.correct && drawn.has(answer.card),
    ),
  }));
  const correct = graded.filter((entry) => entry.correct).length;

  const { error } = await supabase
    .from("mock_sessions")
    .update({
      answers: graded,
      correct_count: correct,
      finished_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", user.id)
    .eq("id", sessionId);

  if (error) return { status: "error", message: error.message };

  revalidateUserData(user.id, "exams");
  revalidatePath("/app/plan");
  revalidatePath("/app");
  return { status: "ok", sessionId };
}
