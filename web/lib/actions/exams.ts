"use server";

import { revalidatePath } from "next/cache";

import {
  addDays,
  planExam,
  type CardState,
  type ExamIntensity,
} from "@micabo/core";

import { createClient } from "@/lib/supabase/server";

/**
 * Écrire un examen, et poser son plan sur les cartes.
 *
 * Même règle qu'iOS : une replanification est **réversible**. On photographie les échéances
 * avant d'écrire, et on les rend si on défait l'examen. Sans ça, supprimer un contrôle
 * laisserait les cartes revenir tous les deux jours pour une date qui n'existe plus.
 */

export interface ExamWriteResult {
  status: "ok" | "error";
  message?: string;
  examId?: string;
}

interface BackupEntry {
  card: string;
  dueDate: string;
  intervalDays: number;
  state: string;
}

interface PlanCard {
  id: string;
  course_id: string | null;
  state: CardState;
  interval_days: number;
  due_date: string;
  is_suspended: boolean;
}

export async function saveExam(input: {
  id?: string;
  name: string;
  examDate: string;
  intensity: ExamIntensity;
  courseIds: string[];
}): Promise<ExamWriteResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  const name = input.name.trim() || "Examen";
  const examDate = input.examDate;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(examDate)) {
    return { status: "error", message: "Date inconnue." };
  }
  if (input.courseIds.length === 0) {
    return { status: "error", message: "Choisis au moins un cours." };
  }
  const intensity = asIntensity(input.intensity);

  const now = new Date();
  const today = new Date(now);
  today.setHours(0, 0, 0, 0);
  const day = new Date(`${examDate}T12:00:00`);
  day.setHours(0, 0, 0, 0);
  if (day.getTime() < today.getTime()) {
    return { status: "error", message: "On ne planifie pas un examen déjà passé." };
  }

  if (input.id) {
    const { data: existing } = await supabase
      .from("exams")
      .select("id, is_planned, schedule_backup")
      .eq("user_id", user.id)
      .eq("id", input.id)
      .is("deleted_at", null)
      .maybeSingle();

    if (!existing) return { status: "error", message: "Examen introuvable." };

    if (existing.is_planned) {
      await restoreBackup(
        supabase,
        user.id,
        existing.schedule_backup as { entries?: BackupEntry[] } | null,
      );
    }
  }

  const examId = input.id ?? crypto.randomUUID();
  const { data: cards } = await supabase
    .from("flashcards")
    .select("id, course_id, state, interval_days, due_date, is_suspended")
    .eq("user_id", user.id)
    .in("course_id", input.courseIds)
    .is("deleted_at", null);

  const usable = ((cards as PlanCard[] | null) ?? []).filter((card) => !card.is_suspended);

  let backup: { entries: BackupEntry[] } | null = null;
  let planned = false;

  if (usable.length > 0) {
    backup = {
      entries: usable.map((card) => ({
        card: card.id,
        dueDate: card.due_date,
        intervalDays: card.interval_days,
        state: card.state,
      })),
    };

    const plan = planExam(
      usable.map((card) => ({
        id: card.id,
        state: card.state,
        intervalDays: card.interval_days,
        dueDate: new Date(card.due_date),
      })),
      day,
      { now, intensity },
    );

    for (const card of usable) {
      const offset = plan.days.get(card.id)?.[0];
      if (offset === undefined) continue;
      const due = addDays(plan.firstDay, offset);
      await supabase
        .from("flashcards")
        .update({
          due_date: due.toISOString(),
          interval_days: card.state === "review" ? Math.max(1, offset) : card.interval_days,
        })
        .eq("user_id", user.id)
        .eq("id", card.id);
    }

    planned = true;
  }

  const row = {
    id: examId,
    user_id: user.id,
    name,
    exam_date: examDate,
    intensity,
    course_ids: input.courseIds,
    is_planned: planned,
    planned_at: planned ? now.toISOString() : null,
    schedule_backup: backup,
    updated_at: now.toISOString(),
    deleted_at: null,
  };

  const { error } = input.id
    ? await supabase.from("exams").update(row).eq("user_id", user.id).eq("id", examId)
    : await supabase.from("exams").insert({ ...row, created_at: now.toISOString() });

  if (error) return { status: "error", message: error.message };

  revalidateExams();
  return { status: "ok", examId };
}

export async function deleteExam(examId: string): Promise<ExamWriteResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  const { data: existing } = await supabase
    .from("exams")
    .select("id, is_planned, schedule_backup")
    .eq("user_id", user.id)
    .eq("id", examId)
    .is("deleted_at", null)
    .maybeSingle();

  if (!existing) return { status: "error", message: "Examen introuvable." };

  if (existing.is_planned) {
    await restoreBackup(
      supabase,
      user.id,
      existing.schedule_backup as { entries?: BackupEntry[] } | null,
    );
  }

  const { error } = await supabase
    .from("exams")
    .update({
      deleted_at: new Date().toISOString(),
      is_planned: false,
      planned_at: null,
      schedule_backup: null,
    })
    .eq("user_id", user.id)
    .eq("id", examId);

  if (error) return { status: "error", message: error.message };

  revalidateExams();
  return { status: "ok", examId };
}

async function restoreBackup(
  supabase: Awaited<ReturnType<typeof createClient>>,
  userId: string,
  backup: { entries?: BackupEntry[] } | null,
) {
  for (const entry of backup?.entries ?? []) {
    await supabase
      .from("flashcards")
      .update({
        due_date: entry.dueDate,
        interval_days: entry.intervalDays,
        state: entry.state,
      })
      .eq("user_id", userId)
      .eq("id", entry.card);
  }
}

function asIntensity(value: string): ExamIntensity {
  return value === "light" || value === "intense" || value === "standard" ? value : "standard";
}

function revalidateExams() {
  revalidatePath("/app");
  revalidatePath("/app/examens");
  revalidatePath("/app/reviser");
}
