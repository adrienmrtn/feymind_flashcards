"use server";

import { revalidatePath } from "next/cache";

import {
  emptyProgress,
  readLessonProgress,
  resetProgress,
  type LessonProgress,
} from "@micabo/core";

import { deleteCourse } from "@/lib/actions/course";
import { revalidateUserData } from "@/lib/data/cache";
import { actionT } from "@/lib/i18n/action";
import { convertLessonOffline } from "@/lib/lesson/convert";
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
