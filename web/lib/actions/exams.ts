"use server";

import { revalidatePath } from "next/cache";

import {
  addDays,
  asExamKind,
  asStartingPoint,
  intensityFor,
  clampTargetScore,
  dayDifference,
  intensityFromTargetScore,
  planExam,
  startOfDay,
  targetScoreFromIntensity,
  type CardState,
  type ExamIntensity,
  type ExamKind,
  type StartingPoint,
} from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { actionT } from "@/lib/i18n/action";
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
  last_reviewed_at: string | null;
}

export async function saveExam(input: {
  id?: string;
  name: string;
  examDate: string;
  intensity?: ExamIntensity;
  targetScore?: number;
  courseIds: string[];
  kind?: string;
  formats?: string[];
  chapterIds?: string[];
  startingPoint?: string;
}): Promise<ExamWriteResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const name = input.name.trim() || "Examen";
  const examDate = input.examDate;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(examDate)) {
    return { status: "error", message: await actionT("app.errors.unknownDate") };
  }
  if (input.courseIds.length === 0) {
    return { status: "error", message: await actionT("app.errors.pickACourse") };
  }
  const targetScore = clampTargetScore(
    input.targetScore ?? targetScoreFromIntensity(asIntensity(input.intensity ?? "standard")),
  );
  const intensity = intensityFromTargetScore(targetScore);

  const now = new Date();
  const today = new Date(now);
  today.setHours(0, 0, 0, 0);
  // Ce que l'épreuve demandait déjà, quand on la modifie sans passer par sa fiche.
  let kept: {
    kind: ExamKind;
    formats: string[];
    chapterIds: string[];
    startingPoint: StartingPoint;
  } = {
    kind: "exam",
    formats: [],
    chapterIds: [],
    startingPoint: "seen",
  };
  const day = new Date(`${examDate}T12:00:00`);
  day.setHours(0, 0, 0, 0);
  if (day.getTime() < today.getTime()) {
    return { status: "error", message: await actionT("app.errors.examInPast") };
  }

  if (input.id) {
    const { data: existing } = await supabase
      .from("exams")
      .select("id, is_planned, schedule_backup, kind, formats, chapter_ids, starting_point")
      .eq("user_id", user.id)
      .eq("id", input.id)
      .is("deleted_at", null)
      .maybeSingle();

    if (!existing) return { status: "error", message: await actionT("app.errors.examMissing") };

    kept = {
      kind: asExamKind((existing as { kind?: string }).kind),
      formats: (existing as { formats?: string[] }).formats ?? [],
      chapterIds: (existing as { chapter_ids?: string[] }).chapter_ids ?? [],
      startingPoint: asStartingPoint((existing as { starting_point?: string }).starting_point),
    };

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
    .select("id, course_id, state, interval_days, due_date, is_suspended, last_reviewed_at")
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
      {
        now,
        // Le même décalage que `planTerm` : découvrir un programme demande un passage de
        // plus par carte. Sans ça, la replanification initiale et le plan de la période se
        // contrediraient dès la création.
        intensity: intensityFor(
          intensity,
          asStartingPoint(input.startingPoint ?? kept.startingPoint),
        ),
      },
    );

    for (const card of usable) {
      if (!shouldMoveForExam(card, now)) continue;
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
    target_score: targetScore,
    course_ids: input.courseIds,
    kind: input.kind ? asExamKind(input.kind) : kept.kind,
    formats: input.formats ?? kept.formats,
    chapter_ids: input.chapterIds ?? kept.chapterIds,
    starting_point: input.startingPoint
      ? asStartingPoint(input.startingPoint)
      : kept.startingPoint,
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

  revalidateExams(user.id);
  return { status: "ok", examId };
}

export async function deleteExam(examId: string): Promise<ExamWriteResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const { data: existing } = await supabase
    .from("exams")
    .select("id, is_planned, schedule_backup")
    .eq("user_id", user.id)
    .eq("id", examId)
    .is("deleted_at", null)
    .maybeSingle();

  if (!existing) return { status: "error", message: await actionT("app.errors.examMissing") };

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

  revalidateExams(user.id);
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

/**
 * Un second examen sur le même cours ne doit pas ramener dans la file du jour
 * une carte qu'on vient de noter, ni interrompre un palier d'apprentissage.
 * Les cartes en révision lointaine, elles, restent le cas d'usage du plan.
 */
function shouldMoveForExam(card: PlanCard, now: Date): boolean {
  if (card.state === "learning" || card.state === "relearning") return false;
  if (!card.last_reviewed_at) return true;
  return startOfDay(new Date(card.last_reviewed_at)).getTime() !== startOfDay(now).getTime();
}

function asIntensity(value: string): ExamIntensity {
  return value === "light" || value === "intense" || value === "standard" ? value : "standard";
}

function revalidateExams(userId: string) {
  revalidateUserData(userId, "exams");
  revalidateUserData(userId, "cards");
  revalidatePath("/app");
  revalidatePath("/app/plan");
  revalidatePath("/app/reviser");
}

/**
 * Enregistrer ce que l'épreuve demande, sans repasser par les trois questions.
 *
 * La feuille de création reste à trois gestes - jour, cours, note visée - et tout le reste
 * vit sur la fiche de l'épreuve : type, formats d'entraînement, chapitres au programme.
 * Chacun de ces réglages change ce que le plan pose, donc chacun **refait le plan** : garder
 * des échéances calculées pour un autre programme donnerait un planning qui ne correspond
 * plus à rien, exactement comme un déplacement de date.
 */
export async function saveExamDetails(input: {
  id: string;
  kind?: string;
  formats?: string[];
  chapterIds?: string[];
  startingPoint?: string;
}): Promise<ExamWriteResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const { data: existing } = await supabase
    .from("exams")
    .select("id, name, exam_date, target_score, intensity, course_ids")
    .eq("user_id", user.id)
    .eq("id", input.id)
    .is("deleted_at", null)
    .maybeSingle();

  if (!existing) return { status: "error", message: await actionT("app.errors.examMissing") };

  const row = existing as {
    name: string;
    exam_date: string;
    target_score: number | null;
    intensity: string;
    course_ids: string[] | null;
  };

  return saveExam({
    id: input.id,
    name: row.name,
    examDate: row.exam_date,
    targetScore: row.target_score ?? undefined,
    intensity: asIntensity(row.intensity),
    courseIds: row.course_ids ?? [],
    kind: input.kind,
    formats: input.formats,
    chapterIds: input.chapterIds,
  });
}

