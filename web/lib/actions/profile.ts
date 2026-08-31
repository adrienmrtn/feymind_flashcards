"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  clampBlocks,
  isContentLanguage,
  isSheetLength,
  isChoosableVisibility,
  lengthContaining,
  nearestStep,
  type ContentLanguage,
  type CourseVisibility,
  type SheetLength,
} from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { createClient } from "@/lib/supabase/server";

/**
 * Les réglages du compte, écrits **dans Supabase**.
 *
 * C'est le point de l'affaire : la source de vérité est la table `profiles`, pas un stockage local
 * du navigateur. Ce que le web écrit ici, `CloudSync` le redescend sur l'iPhone, dans les mêmes
 * colonnes - `daily_minutes`, `sheet_length` - et l'app fait l'inverse. Un réglage gardé dans
 * `localStorage` aurait donné deux vérités qui divergent au premier changement d'appareil.
 *
 * Rien n'est accepté sur parole : une action serveur est un point d'entrée public, donc chaque
 * valeur repasse par les bornes du noyau avant d'atteindre la base.
 */

export interface SavedSettings {
  status: "ok" | "error";
  message?: string;
}

export async function updateSettings(input: {
  displayName?: string;
  dailyMinutes?: number;
  sheetLength?: SheetLength;
  sheetBlocks?: number;
  subjects?: string[];
  institutionName?: string | null;
  institutionId?: string | null;
  sheetLanguage?: ContentLanguage;
}): Promise<SavedSettings> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  const patch: Record<string, unknown> = {};

  if (input.displayName !== undefined) {
    const name = input.displayName.trim().slice(0, 60);
    patch.display_name = name.length > 0 ? name : null;
  }

  // Le rythme se cale sur un palier connu : la file d'étude compte les cartes neuves à partir de
  // ces valeurs-là, et une durée arbitraire donnerait un plan que rien ne sait tenir.
  if (input.dailyMinutes !== undefined) {
    patch.daily_minutes = nearestStep(input.dailyMinutes);
  }

  // Le nombre de blocs commande, et le format n'en est que le nom : c'est ce que l'app a tranché en
  // passant de trois boutons à un curseur. La colonne, elle, retient le format.
  if (input.sheetBlocks !== undefined) {
    patch.sheet_length = lengthContaining(clampBlocks(input.sheetBlocks));
  } else if (isSheetLength(input.sheetLength)) {
    patch.sheet_length = input.sheetLength;
  }

  if (input.subjects !== undefined) {
    patch.subjects = Array.from(
      new Set(input.subjects.map((item) => item.trim()).filter(Boolean)),
    ).slice(0, 40);
  }

  if (input.institutionName !== undefined) {
    const name = input.institutionName?.trim() ?? "";
    patch.institution_name = name.length > 0 ? name : null;
  }

  if (input.institutionId !== undefined) {
    const id = input.institutionId?.trim() ?? "";
    patch.institution_id = id.length > 0 ? id : null;
  }

  if (input.sheetLanguage !== undefined) {
    if (!isContentLanguage(input.sheetLanguage)) {
      return { status: "error", message: "Langue inconnue." };
    }
    patch.sheet_language = input.sheetLanguage;
  }

  if (Object.keys(patch).length === 0) return { status: "ok" };

  const { error } = await supabase
    .from("profiles")
    .upsert({ id: user.id, ...patch }, { onConflict: "id" });

  if (error) return { status: "error", message: error.message };

  revalidateUserData(user.id, "profile");
  revalidatePath("/app");
  revalidatePath("/app/profil");
  revalidatePath("/app/reglages");
  revalidatePath("/app/importer");
  return { status: "ok" };
}

/**
 * La visibilité d'un cours, changée après coup.
 *
 * Elle se décide à l'import, et elle doit pouvoir se refermer. On ne propose plus
 * le dépôt public : uniquement les amis, ou soi seul.
 */
export async function setCourseVisibility(
  courseId: string,
  visibility: CourseVisibility,
): Promise<SavedSettings> {
  if (!isChoosableVisibility(visibility)) return { status: "error", message: "Réglage inconnu." };

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  // Le filtre `user_id` est écrit même si le cloisonnement le ferait : une requête qui compte sur
  // la politique pour ne pas toucher les lignes des autres est une requête qu'une politique
  // ajoutée un jour recasse.
  const { error } = await supabase
    .from("courses")
    .update({ visibility, updated_at: new Date().toISOString() })
    .eq("user_id", user.id)
    .eq("id", courseId);

  if (error) return { status: "error", message: error.message };

  revalidateUserData(user.id, "courses");
  revalidatePath(`/app/c/${courseId}`);
  revalidatePath("/app");
  return { status: "ok" };
}

/**
 * Efface le compte Auth. Le reste suit par cascade : cours, cartes, examens, droit.
 *
 * Après ça, la même adresse peut s'inscrire à nouveau. C'est un autre `id`, un
 * profil vide, et le parcours recommence.
 */
export async function deleteAccount(): Promise<SavedSettings> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  const { error } = await supabase.rpc("delete_own_account");
  if (error) return { status: "error", message: error.message };

  await supabase.auth.signOut();
  return { status: "ok" };
}

export interface AccountExport {
  status: "ok" | "error";
  message?: string;
  payload?: Record<string, unknown>;
}

/**
 * Une copie des données du compte, lue sous RLS.
 *
 * Rien n'est écrit, rien n'est gardé : le fichier n'existe que le temps du
 * téléchargement. L'historique est borné pour rester ouvrable.
 */
export async function exportAccountData(): Promise<AccountExport> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  const [
    profile,
    courses,
    cards,
    logs,
    exams,
    right,
    usage,
  ] = await Promise.all([
    supabase.from("profiles").select("*").eq("id", user.id).maybeSingle(),
    supabase.from("courses").select("*").eq("user_id", user.id).is("deleted_at", null),
    supabase
      .from("flashcards")
      .select(
        "id, course_id, front, back, hint, position, kind, state, due_date, created_at, updated_at",
      )
      .eq("user_id", user.id)
      .is("deleted_at", null)
      .limit(20_000),
    supabase
      .from("review_logs")
      .select("id, card_id, reviewed_at, rating, state_before, new_interval_days")
      .eq("user_id", user.id)
      .order("reviewed_at", { ascending: false })
      .limit(10_000),
    supabase.from("exams").select("*").eq("user_id", user.id).is("deleted_at", null),
    supabase.from("entitlements").select("is_pro, store, period_type, expires_at, will_renew").eq(
      "user_id",
      user.id,
    ).maybeSingle(),
    supabase.from("ai_usage").select("day, fn, count").eq("user_id", user.id),
  ]);

  return {
    status: "ok",
    payload: {
      exportedAt: new Date().toISOString(),
      user: { id: user.id, email: user.email ?? null },
      profile: profile.data,
      courses: courses.data ?? [],
      flashcards: cards.data ?? [],
      reviewLogs: logs.data ?? [],
      exams: exams.data ?? [],
      entitlement: right.data,
      aiUsage: usage.data ?? [],
    },
  };
}

/** Ferme la session. Le compte et les cours restent. */
export async function signOut(): Promise<void> {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/");
}
