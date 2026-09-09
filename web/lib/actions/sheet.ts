"use server";

import { revalidatePath } from "next/cache";

import { normalizeSheet, sheetToPlainText, type SheetBlock } from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { actionT } from "@/lib/i18n/action";
import { createClient } from "@/lib/supabase/server";

/**
 * Enregistrer la fiche telle que l'étudiant l'a réécrite.
 *
 * Trois choses se passent ici, et chacune répare un manque de la fiche figée.
 *
 * **La fiche est renormalisée**, pas écrite telle quelle. Ce qui arrive vient d'un document
 * modifiable, donc d'un endroit où l'on peut coller n'importe quoi ; une action serveur est un
 * point d'entrée public, et le format de la fiche ne se défend pas dans l'écran.
 *
 * **Le texte de référence est refait.** C'est lui qui part au modèle pour écrire les cartes et
 * les examens blancs. Le laisser sur la version d'origine reviendrait à corriger une erreur
 * sur la fiche et à la réviser quand même : la correction serait cosmétique, ce qui est pire
 * que pas de correction du tout.
 *
 * **La part verrouillée est recollée.** Un compte gratuit ne lit qu'une partie de sa fiche,
 * donc n'en modifie qu'une partie ; enregistrer ce qu'il voit effacerait le reste. Le nombre
 * de blocs cachés vient de l'écran, et il est **vérifié** contre la fiche en base : un client
 * qui l'annonce à zéro ne fait pas disparaître la suite.
 */

export interface SheetWriteResult {
  status: "ok" | "error";
  message?: string;
  blocks?: number;
}

export async function saveSheet(
  courseId: string,
  blocks: SheetBlock[],
  lockedCount = 0,
): Promise<SheetWriteResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const { data: course } = await supabase
    .from("courses")
    .select("id, sheet")
    .eq("user_id", user.id)
    .eq("id", courseId)
    .is("deleted_at", null)
    .maybeSingle();

  if (!course) return { status: "error", message: await actionT("app.errors.courseMissing") };

  const written = normalizeSheet(blocks);
  if (written.length === 0) {
    return { status: "error", message: await actionT("app.errors.emptySheet") };
  }

  const existing = normalizeSheet((course as { sheet?: unknown }).sheet);
  // Le compte annoncé ne peut que retirer de la fin, jamais inventer des blocs à garder.
  const kept = lockedCount > 0 ? existing.slice(Math.max(0, existing.length - lockedCount)) : [];
  const full = [...written, ...kept];

  const contextText = sheetToPlainText(full);

  const { error } = await supabase
    .from("courses")
    .update({
      // La fiche vit dans la colonne `sheet`, sous la forme `{ blocks }` : c'est ce que le
      // serveur y écrit à la génération, et ce que la lecture renormalise.
      sheet: { blocks: full },
      context_text: contextText,
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", user.id)
    .eq("id", courseId);

  if (error) return { status: "error", message: error.message };

  revalidateUserData(user.id, "courses");
  revalidatePath(`/app/c/${courseId}`);
  revalidatePath("/app/cours");
  return { status: "ok", blocks: full.length };
}
