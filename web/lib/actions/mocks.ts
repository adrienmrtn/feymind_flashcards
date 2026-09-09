"use server";

import { revalidatePath } from "next/cache";

import {
  asExamKind,
  correctCount,
  gradeClosed,
  isClosedQuestion,
  paperMinutes,
  paperQuota,
  paperScore,
  quotaSize,
  sheetLanguage,
  wantsMock,
  type MockAnswer,
  type MockDebrief,
  type MockGrade,
  type MockQuestion,
} from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { actionT } from "@/lib/i18n/action";
import { createClient } from "@/lib/supabase/server";

/**
 * Ouvrir une copie d'examen blanc, la remettre, la faire corriger.
 *
 * **La copie est écrite côté serveur, à l'ouverture.** Deux raisons, les mêmes qu'avant pour
 * le tirage qu'elle remplace : elle doit survivre à un rechargement au milieu de l'épreuve, et
 * laisser le navigateur composer ses propres questions permettrait de recommencer jusqu'à
 * tomber sur les faciles - ce qui viderait de son sens la seule mesure honnête du produit.
 *
 * **La correction aussi est côté serveur.** Le client envoie ce qu'il a répondu ; il ne dicte
 * pas ce qu'il a eu juste. Les questions fermées se comparent, les explications orales passent
 * au modèle, et le score sort de la somme des deux.
 */

export interface MockResultAction {
  status: "ok" | "error";
  message?: string;
  sessionId?: string;
}

export type { MockAnswer } from "@micabo/core";

/** Ce qu'on lit d'un cours pour composer la copie. */
interface CourseMatter {
  title: string;
  subject: string | null;
  context: string;
}

const MAX_CONTEXT = 40_000;

export async function startMockSession(
  examId: string,
  withAudio = false,
): Promise<MockResultAction> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const { data: examRow } = await supabase
    .from("exams")
    .select("id, name, kind, course_ids")
    .eq("user_id", user.id)
    .eq("id", examId)
    .is("deleted_at", null)
    .maybeSingle();

  const exam = examRow as
    | { name: string | null; kind: string | null; course_ids: string[] | null }
    | null;
  if (!exam) return { status: "error", message: await actionT("app.errors.examMissing") };
  if (!wantsMock(asExamKind(exam.kind))) {
    return { status: "error", message: await actionT("app.errors.mockNotForKind") };
  }

  const courseIds = exam.course_ids ?? [];
  if (courseIds.length === 0) {
    return { status: "error", message: await actionT("app.errors.pickACourse") };
  }

  const [{ data: courseRows }, { data: profile }] = await Promise.all([
    supabase
      .from("courses")
      .select("title, subject, context_text")
      .eq("user_id", user.id)
      .in("id", courseIds)
      .is("deleted_at", null),
    supabase
      .from("profiles")
      .select("country_code, sheet_language")
      .eq("id", user.id)
      .maybeSingle(),
  ]);

  const matter = ((courseRows as CourseMatter[] | null) ?? []).map((course) => ({
    title: course.title,
    subject: course.subject,
    context: (course.context ?? "").trim(),
  }));

  // Le programme part au modèle tel qu'il a été écrit à l'import : c'est le même texte que
  // celui qui a produit les cartes, donc la copie interroge le même cours qu'elles.
  const context = ((courseRows as { context_text?: string }[] | null) ?? [])
    .map((course) => (course.context_text ?? "").trim())
    .filter((text) => text.length > 0)
    .join("\n\n")
    .slice(0, MAX_CONTEXT);

  if (context.length < 200) {
    return { status: "error", message: await actionT("app.errors.mockTooFewCards") };
  }

  const quota = paperQuota(withAudio);
  const { data, error } = await supabase.functions.invoke("generate-mock", {
    body: {
      title: exam.name ?? matter[0]?.title ?? "",
      subject: matter[0]?.subject ?? undefined,
      context,
      quota,
      language: sheetLanguage(profile?.sheet_language, profile?.country_code),
    },
  });

  if (error) return { status: "error", message: await actionT("app.mock.failed") };

  const written = (data as { questions?: unknown[] } | null)?.questions ?? [];
  const questions = numbered(written);
  if (questions.length < 4) {
    return { status: "error", message: await actionT("app.mock.failed") };
  }

  const sessionId = crypto.randomUUID();
  const { error: insertError } = await supabase.from("mock_sessions").insert({
    id: sessionId,
    user_id: user.id,
    exam_id: examId,
    planned_for: new Date().toISOString().slice(0, 10),
    minutes: paperMinutes(questions),
    question_count: questions.length,
    correct_count: 0,
    questions,
    answers: [],
    grades: [],
    with_audio: withAudio && quotaSize(quota) > 0 && questions.some((q) => q.kind === "feynman"),
  });

  if (insertError) return { status: "error", message: insertError.message };

  revalidateUserData(user.id, "exams");
  return { status: "ok", sessionId };
}

/** Une question sans identifiant n'est pas corrigeable : on lui en pose un, stable, à l'écriture. */
function numbered(written: readonly unknown[]): MockQuestion[] {
  const questions: MockQuestion[] = [];
  for (const [index, raw] of written.entries()) {
    if (!raw || typeof raw !== "object") continue;
    const question = { ...(raw as Record<string, unknown>), id: `q${index + 1}` };
    questions.push(question as unknown as MockQuestion);
  }
  return questions;
}

/**
 * Remettre la copie, et la faire corriger.
 *
 * Les questions fermées sont notées ici, à la comparaison : c'est le socle, il est
 * reproductible, et il ne dépend d'aucun modèle. Les explications orales partent à
 * `grade-mock`, qui rend une note par réponse et le débriefing de l'ensemble.
 *
 * Si la correction du modèle échoue, la copie est quand même fermée avec le score des
 * questions fermées : une note incomplète vaut mieux qu'une épreuve passée pour rien.
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
    .select("id, exam_id, questions, question_count, finished_at")
    .eq("user_id", user.id)
    .eq("id", sessionId)
    .maybeSingle();

  const session = sessionRow as
    | { exam_id: string | null; questions: MockQuestion[] | null; finished_at: string | null }
    | null;
  if (!session) return { status: "error", message: await actionT("app.errors.mockMissing") };
  if (session.finished_at) return { status: "ok", sessionId };

  const questions = session.questions ?? [];
  const byId = new Map(answers.map((answer) => [answer.id, answer]));

  const closed = questions.filter(isClosedQuestion);
  const spoken = questions.filter((question) => question.kind === "feynman");

  const grades: MockGrade[] = closed.map((question) => gradeClosed(question, byId.get(question.id)));
  let debrief: MockDebrief | null = null;

  if (closed.length > 0 || spoken.length > 0) {
    const [{ data: exam }, { data: profile }] = await Promise.all([
      session.exam_id
        ? supabase
            .from("exams")
            .select("name")
            .eq("user_id", user.id)
            .eq("id", session.exam_id)
            .maybeSingle()
        : Promise.resolve({ data: null }),
      supabase
        .from("profiles")
        .select("country_code, sheet_language")
        .eq("id", user.id)
        .maybeSingle(),
    ]);

    const { data, error } = await supabase.functions.invoke("grade-mock", {
      body: {
        title: (exam as { name?: string } | null)?.name ?? "",
        language: sheetLanguage(profile?.sheet_language, profile?.country_code),
        closedTotal: closed.length,
        closedCorrect: grades.filter((grade) => grade.score >= 100).length,
        missed: closed
          .filter((question) => (grades.find((grade) => grade.id === question.id)?.score ?? 0) === 0)
          .map((question) => ({ prompt: question.prompt, why: question.why })),
        spoken: spoken.map((question) => ({
          id: question.id,
          prompt: question.prompt,
          expected: question.kind === "feynman" ? question.expected : "",
          said: byId.get(question.id)?.text ?? "",
        })),
      },
    });

    if (!error && data) {
      const payload = data as { grades?: MockGrade[]; debrief?: MockDebrief };
      for (const grade of payload.grades ?? []) {
        if (spoken.some((question) => question.id === grade.id)) grades.push(grade);
      }
      if (payload.debrief) debrief = payload.debrief;
    }

    // Le modèle n'a pas répondu : une explication non notée compte pour zéro plutôt que de
    // disparaître du dénominateur, sinon rater l'oral remonterait la note.
    for (const question of spoken) {
      if (!grades.some((grade) => grade.id === question.id)) {
        grades.push({ id: question.id, score: 0 });
      }
    }
  }

  const { error: updateError } = await supabase
    .from("mock_sessions")
    .update({
      answers,
      grades,
      debrief,
      question_count: grades.length,
      correct_count: correctCount(grades),
      finished_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", user.id)
    .eq("id", sessionId);

  if (updateError) return { status: "error", message: updateError.message };

  revalidateUserData(user.id, "exams");
  revalidatePath("/app/plan");
  revalidatePath("/app");
  return { status: "ok", sessionId };
}

/** Le score d'une copie, pour l'écran qui vient de la remettre. */
export async function readMockScore(sessionId: string): Promise<number> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return 0;

  const { data } = await supabase
    .from("mock_sessions")
    .select("grades")
    .eq("user_id", user.id)
    .eq("id", sessionId)
    .maybeSingle();

  return paperScore(((data as { grades?: MockGrade[] } | null)?.grades ?? []) as MockGrade[]);
}
