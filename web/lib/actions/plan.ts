"use server";

import { revalidatePath } from "next/cache";

import { asExamKind, asStartingPoint, clampMinutes, clampTargetScore } from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { actionT } from "@/lib/i18n/action";
import { createClient } from "@/lib/supabase/server";

import { saveExam } from "./exams";

/**
 * Créer un plan, d'un seul geste.
 *
 * Le parcours pose six questions dont trois ne concernent pas l'épreuve mais **l'étudiant** :
 * son temps, ses pauses, son point de départ. Les écrire une par une laisserait un compte à
 * moitié réglé si l'une échoue, et surtout ferait recalculer le plan trois fois pour rien.
 *
 * L'ordre compte : les disponibilités et les pauses **avant** l'épreuve. `saveExam` replanifie
 * les échéances en lisant la capacité de chaque jour ; l'écrire après poserait le plan sur des
 * disponibilités périmées, et le premier samedi de pause le déferait.
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
  weeklyMinutes: number[];
  offDays: string[];
  formats: string[];
  name: string;
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
  if (input.weeklyMinutes.length !== 7) {
    return { status: "error", message: await actionT("app.errors.badWeek") };
  }

  // 1. Le temps disponible, d'abord : c'est lui que la replanification va lire.
  const { error: weekError } = await supabase
    .from("profiles")
    .update({ weekly_minutes: input.weeklyMinutes.map(clampMinutes) })
    .eq("id", user.id);
  if (weekError) return { status: "error", message: await actionT("app.errors.saveFailed") };

  const pauses = input.offDays.filter((day) => /^\d{4}-\d{2}-\d{2}$/.test(day));
  if (pauses.length > 0) {
    const { error: pauseError } = await supabase.from("availability_exceptions").upsert(
      pauses.map((day) => ({ user_id: user.id, day, minutes: 0 })),
      { onConflict: "user_id,day" },
    );
    if (pauseError) return { status: "error", message: await actionT("app.errors.saveFailed") };
  }

  revalidateUserData(user.id, "profile");

  // 2. L'épreuve ensuite, sur des disponibilités à jour.
  const saved = await saveExam({
    name: input.name.trim() || (await actionT("app.exams.defaultName")),
    examDate: input.examDate,
    targetScore: clampTargetScore(input.targetScore),
    courseIds: input.courseIds,
    kind: asExamKind(input.kind),
    formats: input.formats,
    startingPoint: asStartingPoint(input.startingPoint),
  });

  if (saved.status === "error") {
    return { status: "error", message: saved.message };
  }

  revalidatePath("/app");
  revalidatePath("/app/plan");
  return { status: "ok", examId: saved.examId };
}
