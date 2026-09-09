"use server";

import { revalidatePath } from "next/cache";

import { asExamKind, asStartingPoint, clampTargetScore } from "@micabo/core";

import { actionT } from "@/lib/i18n/action";
import { createClient } from "@/lib/supabase/server";

import { saveExam } from "./exams";

/**
 * Créer un plan, d'un seul geste.
 *
 * Le parcours pose une suite de questions dont deux ne concernent pas l'épreuve mais
 * **l'étudiant** : ses jours off et son point de départ. Les écrire une par une laisserait un
 * compte à moitié réglé si l'une échoue, et ferait recalculer le plan deux fois pour rien.
 *
 * L'ordre compte, et `saveExam` le tient : les jours off **avant** la replanification. Il pose
 * les échéances sur les jours ouverts ; les écrire après poserait le plan sur des jours qu'on
 * s'apprête à fermer, et le premier dimanche de pause le déferait.
 */

export interface CreatePlanResult {
  status: "ok" | "error";
  message?: string;
  examId?: string;
}

export async function createPlan(input: {
  courseIds: string[];
  examDate: string;
  kind: string;
  startingPoint: string;
  targetScore: number;
  formats: string[];
  name: string;
  /** Les jours où l'étudiant a dit qu'il ne réviserait pas, en dates ISO. */
  offDays?: readonly string[];
}): Promise<CreatePlanResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  if (input.courseIds.length === 0) {
    return { status: "error", message: await actionT("app.errors.pickACourse") };
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(input.examDate)) {
    return { status: "error", message: await actionT("app.errors.unknownDate") };
  }

  const saved = await saveExam({
    name: input.name.trim() || (await actionT("app.exams.defaultName")),
    examDate: input.examDate,
    targetScore: clampTargetScore(input.targetScore),
    courseIds: input.courseIds,
    kind: asExamKind(input.kind),
    formats: input.formats,
    startingPoint: asStartingPoint(input.startingPoint),
    offDays: input.offDays,
  });

  if (saved.status === "error") {
    return { status: "error", message: saved.message };
  }

  revalidatePath("/app");
  revalidatePath("/app/plan");
  return { status: "ok", examId: saved.examId };
}
