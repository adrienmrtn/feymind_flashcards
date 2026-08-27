"use server";

import { revalidatePath } from "next/cache";

import {
  clampBlocks,
  isSheetLength,
  isVisibility,
  lengthContaining,
  nearestStep,
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
 * colonnes — `daily_minutes`, `sheet_length` — et l'app fait l'inverse. Un réglage gardé dans
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

  if (Object.keys(patch).length === 0) return { status: "ok" };

  const { error } = await supabase
    .from("profiles")
    .upsert({ id: user.id, ...patch }, { onConflict: "id" });

  if (error) return { status: "error", message: error.message };

  revalidateUserData(user.id, "profile");
  revalidatePath("/app/profil");
  revalidatePath("/app/importer");
  return { status: "ok" };
}

/**
 * La visibilité d'un cours, changée après coup.
 *
 * Elle se décide à l'import, et elle doit pouvoir se refermer : c'est ce qui rend le défaut public
 * acceptable. On ne demande pas à quelqu'un d'ouvrir ses cours sans lui donner le moyen d'en
 * refermer un.
 */
export async function setCourseVisibility(
  courseId: string,
  visibility: CourseVisibility,
): Promise<SavedSettings> {
  if (!isVisibility(visibility)) return { status: "error", message: "Réglage inconnu." };

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
