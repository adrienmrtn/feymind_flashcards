"use server";

import { revalidatePath } from "next/cache";

import {
  addTime,
  emptyProgress,
  isCardOfQuestion,
  markDone,
  mikaTurns,
  missedCardDraft,
  noteMissed,
  noteRight,
  readLessonProgress,
  readQuizQuestion,
  recordQuiz,
  resetProgress,
  tomorrowStart,
  type LessonActivity,
  type LessonProgress,
  type MikaTurn,
} from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { actionT } from "@/lib/i18n/action";
import { readUiLocale } from "@/lib/i18n/server";
import { convertLessonOffline } from "@/lib/lesson/convert";
import { readableFunctionError } from "@/lib/lesson/errors";
import { lessonAttachment } from "@/lib/lesson/mika-attachment";
import { createClient } from "@/lib/supabase/server";

/**
 * **Ce qu'une leçon écrit sur elle-même**, depuis le chemin.
 *
 * La progression est un JSON entier, relu puis réécrit : deux appareils qui la modifient en
 * même temps se résolvent par `updated_at`, que `touch_updated_at` pose à chaque écriture.
 * C'est le choix de l'app, et le site ne le rediscute pas. Chaque écriture porte son filtre
 * `user_id`, comme toutes les autres.
 */

export interface LessonActionResult {
  status: "ok" | "error";
  message?: string;
}

const MAX_TITLE = 120;

async function session() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return { supabase, user };
}

function refresh(userId: string, lessonId: string): void {
  revalidateUserData(userId, "courses");
  revalidatePath(`/app/lecons/${lessonId}`);
  revalidatePath("/app");
}

/** La leçon vient de s'ouvrir : « Reprendre » sur Home la retrouvera. */
export async function openLesson(lessonId: string): Promise<LessonActionResult> {
  const { supabase, user } = await session();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };
  const { error } = await supabase
    .from("courses")
    .update({ last_opened_at: new Date().toISOString() })
    .eq("user_id", user.id)
    .eq("id", lessonId)
    .is("deleted_at", null);
  if (error) return { status: "error", message: error.message };
  revalidateUserData(user.id, "courses");
  return { status: "ok" };
}

/** Relit la progression en base, la transforme, la réécrit. */
export async function updateProgress(
  lessonId: string,
  change: (progress: LessonProgress) => LessonProgress,
): Promise<LessonActionResult & { progress?: LessonProgress }> {
  const { supabase, user } = await session();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const { data } = await supabase
    .from("courses")
    .select("progress")
    .eq("user_id", user.id)
    .eq("id", lessonId)
    .is("deleted_at", null)
    .maybeSingle();
  if (!data) return { status: "error", message: await actionT("app.errors.courseMissing") };

  const next = change(readLessonProgress((data as { progress: unknown }).progress) ?? emptyProgress());
  const { error } = await supabase
    .from("courses")
    .update({ progress: next, updated_at: new Date().toISOString() })
    .eq("user_id", user.id)
    .eq("id", lessonId);
  if (error) return { status: "error", message: error.message };
  refresh(user.id, lessonId);
  return { status: "ok", progress: next };
}

/** **Recommencer la leçon** : le chemin repart de l'Intro, le temps passé reste compté. */
export async function restartLesson(lessonId: string): Promise<LessonActionResult> {
  return updateProgress(lessonId, resetProgress);
}

export async function renameLesson(lessonId: string, title: string): Promise<LessonActionResult> {
  const { supabase, user } = await session();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };
  const clean = title.replace(/\s+/g, " ").trim().slice(0, MAX_TITLE);
  if (!clean) return { status: "error", message: await actionT("lesson.menu.renamePlaceholder") };
  const { error } = await supabase
    .from("courses")
    .update({ title: clean, updated_at: new Date().toISOString() })
    .eq("user_id", user.id)
    .eq("id", lessonId)
    .is("deleted_at", null);
  if (error) return { status: "error", message: error.message };
  refresh(user.id, lessonId);
  return { status: "ok" };
}

/** Supprimer une leçon : ses notes, ses quiz et ses flashcards partent avec elle. */
export async function deleteLesson(lessonId: string): Promise<LessonActionResult> {
  const result = await deleteCourse(lessonId);
  revalidatePath(`/app/lecons/${lessonId}`);
  return result;
}

/** « Ouvrir sans attendre » : la conversion sans le modèle. */
export async function openLessonOffline(lessonId: string): Promise<LessonActionResult> {
  const result = await convertLessonOffline(lessonId);
  const { user } = await session();
  if (user) refresh(user.id, lessonId);
  return result;
}

// MARK: - Les étapes

/**
 * **Coche une étape.** Le Quiz final coche aussi la leçon : elle passe en « apprise »
 * (`finishedAt`). L'anneau de l'étape en cours repart de zéro.
 */
export async function completeCircle(lessonId: string, circleId: string, isFinal: boolean) {
  return updateProgress(lessonId, (progress) => {
    const next = { ...markDone(progress, circleId), inCircle: 0 };
    if (isFinal && !next.finishedAt) next.finishedAt = new Date().toISOString();
    return next;
  });
}

/** Où on en est dans l'étape en cours : l'anneau autour d'elle. */
export async function setInCircle(lessonId: string, value: number): Promise<LessonActionResult> {
  const clamped = Math.min(1, Math.max(0, Number.isFinite(value) ? value : 0));
  return updateProgress(lessonId, (progress) => (Math.abs(clamped - progress.inCircle) < 0.05 ? progress : { ...progress, inCircle: clamped }));
}

/** Le temps passé dans une activité, en secondes, ajouté à la leçon. */
export async function addStudyTime(lessonId: string, seconds: number, activity: LessonActivity): Promise<LessonActionResult> {
  const amount = Math.min(4 * 3600, Math.max(0, Number.isFinite(seconds) ? seconds : 0));
  if (amount < 1) return { status: "ok" };
  return updateProgress(lessonId, (progress) => addTime(progress, amount, activity));
}

export async function recordQuizScore(lessonId: string, circleId: string, right: number, total: number) {
  return updateProgress(lessonId, (progress) => recordQuiz(progress, circleId, Math.max(0, right), Math.max(0, total)));
}

/**
 * **Une réponse à une question.** Ratée, la question entre dans `missed` et devient une
 * flashcard à revoir demain : une carte QCM rattachée au thème de la question ; ratée une
 * seconde fois, la même carte revient demain au lieu d'en créer une autre. Jumeau de
 * `LessonSession.answered` et `LessonReview.cardForMissed`.
 */
export async function answerQuestion(lessonId: string, rawQuestion: unknown, right: boolean): Promise<LessonActionResult> {
  const question = readQuizQuestion(rawQuestion);
  if (!question) return { status: "error", message: await actionT("app.common.errorGeneric") };

  const result = await updateProgress(lessonId, (progress) => (right ? noteRight(progress, question.id) : noteMissed(progress, question.id)));
  if (result.status === "error" || right) return result;

  const { supabase, user } = await session();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const now = new Date();
  const tomorrow = tomorrowStart(now).toISOString();
  const { data: cards } = await supabase
    .from("flashcards")
    .select("id, front, kind, due_date")
    .eq("user_id", user.id)
    .eq("course_id", lessonId)
    .is("deleted_at", null);
  const rows = (cards ?? []) as { id: string; front: string; kind: string; due_date: string }[];
  const existing = rows.find((card) => isCardOfQuestion(card, question));

  if (existing) {
    const dueAt = new Date(existing.due_date).getTime();
    if (dueAt > new Date(tomorrow).getTime()) {
      await supabase.from("flashcards").update({ due_date: tomorrow, updated_at: now.toISOString() }).eq("user_id", user.id).eq("id", existing.id);
    }
  } else {
    // Le thème de la question : le préfixe de son identifiant, s'il est bien un thème de la leçon.
    const prefix = question.id.split(":")[0] ?? "";
    const { data: chapter } = prefix
      ? await supabase.from("chapters").select("id").eq("user_id", user.id).eq("course_id", lessonId).eq("id", prefix).maybeSingle()
      : { data: null };
    const draft = missedCardDraft(question);
    const { error } = await supabase.from("flashcards").insert({
      id: crypto.randomUUID(),
      user_id: user.id,
      course_id: lessonId,
      chapter_id: (chapter as { id: string } | null)?.id ?? null,
      front: draft.front,
      back: draft.back,
      position: rows.length,
      kind: draft.kind,
      choices: draft.choices,
      correct_choice_index: draft.correctChoiceIndex,
      // Ratée dans un quiz, la carte est déjà « en cours » : elle compte dans « à réviser »
      // dès demain, au lieu d'attendre sa première séance comme une carte neuve.
      state: "learning",
      due_date: tomorrow,
    });
    if (error) return { status: "error", message: error.message };
  }
  revalidateUserData(user.id, "cards");
  return { status: "ok" };
}

/** La carte que Mika propose, rangée dans la leçon. */
export async function addMikaCard(lessonId: string, front: string, back: string): Promise<LessonActionResult> {
  const { supabase, user } = await session();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };
  const cleanFront = front.trim().slice(0, 600);
  const cleanBack = back.trim().slice(0, 2000);
  if (!cleanFront || !cleanBack) return { status: "error", message: await actionT("app.common.errorGeneric") };

  const { count } = await supabase
    .from("flashcards")
    .select("id", { count: "exact", head: true })
    .eq("user_id", user.id)
    .eq("course_id", lessonId)
    .is("deleted_at", null);
  const { error } = await supabase.from("flashcards").insert({
    id: crypto.randomUUID(),
    user_id: user.id,
    course_id: lessonId,
    front: cleanFront,
    back: cleanBack,
    position: count ?? 0,
    kind: "basic",
    state: "new",
    due_date: new Date().toISOString(),
  });
  if (error) return { status: "error", message: error.message };
  await supabase.from("courses").update({ updated_at: new Date().toISOString() }).eq("user_id", user.id).eq("id", lessonId);
  revalidateUserData(user.id, "cards");
  revalidateUserData(user.id, "courses");
  return { status: "ok" };
}

// MARK: - Mika

export interface MikaAnswer {
  status: "ok" | "error";
  reply?: string;
  card?: { front: string; back: string };
  message?: string;
  code?: string;
}

/**
 * **Mika répond**, la leçon jointe d'office. L'appel part du serveur : la fonction sait qui
 * demande et décompte, et les notes ne voyagent pas depuis le navigateur. Les huit derniers
 * tours partent, bornés ; la pièce jointe est le texte à plat des thèmes.
 */
export async function askMika(lessonId: string, rawTurns: MikaTurn[]): Promise<MikaAnswer> {
  const { supabase, user } = await session();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const turns = mikaTurns(
    (Array.isArray(rawTurns) ? rawTurns : [])
      .filter((turn) => turn && (turn.role === "user" || turn.role === "mika") && typeof turn.text === "string")
      .map((turn) => ({ role: turn.role, text: turn.text.trim() }))
      .filter((turn) => turn.text.length > 0),
  );
  if (turns.length === 0 || turns[turns.length - 1]!.role !== "user") {
    return { status: "error", message: await actionT("app.common.errorGeneric") };
  }

  const attachment = await lessonAttachment(supabase, user.id, lessonId);
  if (!attachment) return { status: "error", message: await actionT("app.errors.courseMissing") };

  const [{ data: profile }, locale] = await Promise.all([
    supabase.from("profiles").select("study_level").eq("id", user.id).maybeSingle(),
    readUiLocale(),
  ]);

  const { data, error } = await supabase.functions.invoke("mika-chat", {
    body: {
      messages: turns,
      attachment: { title: attachment.title, text: attachment.text },
      language: attachment.language ?? locale,
      level: (profile as { study_level?: string | null } | null)?.study_level ?? undefined,
    },
  });
  if (error) {
    const refusal = await readableFunctionError(error);
    return { status: "error", message: refusal.message, ...(refusal.code ? { code: refusal.code } : {}) };
  }
  const answer = (data as { answer?: { reply?: unknown; card?: { front?: unknown; back?: unknown } } } | null)?.answer;
  if (!answer || typeof answer.reply !== "string" || !answer.reply.trim()) {
    return { status: "error", message: await actionT("app.common.errorGeneric") };
  }
  const card =
    answer.card && typeof answer.card.front === "string" && typeof answer.card.back === "string" && answer.card.front.trim() && answer.card.back.trim()
      ? { front: answer.card.front.trim(), back: answer.card.back.trim() }
      : undefined;
  return { status: "ok", reply: answer.reply.trim(), ...(card ? { card } : {}) };
}

/**
 * **Supprimer une leçon**, et tout ce qui va avec : ses flashcards, et sa place dans les
 * examens qui l'avaient au programme. Un examen qui n'a plus rien au programme part aussi,
 * parce qu'il resterait à compter les jours pour rien.
 */
async function deleteCourse(courseId: string): Promise<{ status: "ok" | "error"; message?: string }> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const { data: course } = await supabase
    .from("courses")
    .select("id")
    .eq("user_id", user.id)
    .eq("id", courseId)
    .is("deleted_at", null)
    .maybeSingle();

  if (!course) return { status: "error", message: await actionT("app.errors.courseMissing") };

  const now = new Date().toISOString();

  const { error } = await supabase
    .from("courses")
    .update({ deleted_at: now, updated_at: now })
    .eq("user_id", user.id)
    .eq("id", courseId);

  if (error) return { status: "error", message: error.message };

  await supabase
    .from("flashcards")
    .update({ deleted_at: now, updated_at: now })
    .eq("user_id", user.id)
    .eq("course_id", courseId)
    .is("deleted_at", null);

  const { data: exams } = await supabase
    .from("exams")
    .select("id, course_ids")
    .eq("user_id", user.id)
    .is("deleted_at", null)
    .contains("course_ids", [courseId]);

  for (const exam of (exams as { id: string; course_ids: string[] | null }[] | null) ?? []) {
    const remaining = (exam.course_ids ?? []).filter((id) => id !== courseId);
    await supabase
      .from("exams")
      .update(
        remaining.length > 0
          ? { course_ids: remaining }
          : { course_ids: remaining, deleted_at: now, is_planned: false },
      )
      .eq("user_id", user.id)
      .eq("id", exam.id);
  }

  revalidateUserData(user.id, "all");
  revalidatePath("/app");
  revalidatePath("/app/lecons");
  revalidatePath("/app/examen");
  return { status: "ok" };
}
