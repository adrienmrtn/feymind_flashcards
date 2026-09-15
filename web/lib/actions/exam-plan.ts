"use server";

import { revalidatePath } from "next/cache";

import { startOfDay, type AgendaKind } from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { actionT } from "@/lib/i18n/action";
import { createClient } from "@/lib/supabase/server";

/**
 * **Déplacer un rendez-vous de mesure, ou le remettre là où le plan l'avait posé.**
 *
 * L'agenda ne s'écrit pas : les blancs se déduisent de leurs décalages, les parcours de leur
 * cadence, et les deux se recalculent depuis la date de l'épreuve à chaque lecture. Ce qui se
 * persiste est **l'exception** - la date que l'étudiant a choisie lui-même.
 *
 * Une surcharge désigne son rendez-vous par son **rang dans sa série**, jamais par sa date :
 * la date est précisément ce qu'on change. Le rang se compte depuis l'épreuve, donc il ne
 * bouge pas quand les jours passent, et un déplacement survit à la nuit.
 *
 * C'est la même table que l'app lit et écrit, à la même clé : déplacer un test depuis le site
 * le déplace sur le téléphone.
 */

export interface MoveMeasureResult {
  status: "ok" | "error";
  message?: string;
}

/** Le rang le plus haut qu'une série puisse porter, et ce que la contrainte SQL accepte. */
const MAX_SLOT = 31;

const DAY = /^\d{4}-\d{2}-\d{2}$/;

export async function moveMeasure(input: {
  examId: string;
  kind: AgendaKind;
  slot: number;
  /** La date choisie, ou `null` pour rendre le rendez-vous à la dérivation. */
  date: string | null;
}): Promise<MoveMeasureResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  if (input.kind !== "mock" && input.kind !== "parcours") {
    return { status: "error", message: await actionT("app.errors.unknownDate") };
  }
  if (!Number.isInteger(input.slot) || input.slot < 0 || input.slot > MAX_SLOT) {
    return { status: "error", message: await actionT("app.errors.unknownDate") };
  }

  // L'épreuve est relue plutôt que reçue : une action serveur s'appelle sans passer par
  // l'écran qui la déclenche, et c'est la date de l'épreuve qui borne le déplacement.
  const { data: examRow } = await supabase
    .from("exams")
    .select("id, exam_date")
    .eq("user_id", user.id)
    .eq("id", input.examId)
    .is("deleted_at", null)
    .maybeSingle();

  const exam = examRow as { exam_date: string } | null;
  if (!exam) return { status: "error", message: await actionT("app.errors.examMissing") };

  const table = supabase.from("exam_plan_overrides");

  if (input.date === null) {
    const { error } = await table
      .delete()
      .eq("user_id", user.id)
      .eq("exam_id", input.examId)
      .eq("kind", input.kind)
      .eq("slot", input.slot);
    if (error) return { status: "error", message: error.message };
    return settle(user.id, input.examId);
  }

  if (!DAY.test(input.date)) {
    return { status: "error", message: await actionT("app.errors.unknownDate") };
  }

  /**
   * Les deux bornes, tenues ici et pas seulement dans le sélecteur.
   *
   * **Pas dans le passé** : un rendez-vous qu'on ne peut plus honorer naîtrait manqué. **Pas
   * le jour de l'épreuve ni après** : une mesure y révélerait une lacune qu'il n'y a plus le
   * temps de corriger, ce qui est tout ce qu'elle sert à faire.
   */
  const chosen = startOfDay(new Date(`${input.date}T12:00:00`));
  const today = startOfDay(new Date());
  const examDay = startOfDay(new Date(`${exam.exam_date}T12:00:00`));

  if (chosen.getTime() < today.getTime() || chosen.getTime() >= examDay.getTime()) {
    return { status: "error", message: await actionT("app.agenda.outOfRange") };
  }

  // La clé est (utilisateur, épreuve, sorte, rang) : déplacer deux fois le même rendez-vous
  // écrase, ce qui est exactement le comportement voulu.
  const { error } = await table.upsert(
    {
      user_id: user.id,
      exam_id: input.examId,
      kind: input.kind,
      slot: input.slot,
      scheduled_for: input.date,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "user_id,exam_id,kind,slot" },
  );

  if (error) return { status: "error", message: error.message };
  return settle(user.id, input.examId);
}

/** Le plan du jour et celui de l'épreuve vivent tous deux de l'agenda : les deux sont relus. */
async function settle(userId: string, examId: string): Promise<MoveMeasureResult> {
  revalidateUserData(userId, "exams");
  revalidatePath(`/app/plan/${examId}`);
  revalidatePath("/app/plan");
  revalidatePath("/app");
  return { status: "ok" };
}
