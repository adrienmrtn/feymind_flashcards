"use server";

import { revalidatePath } from "next/cache";

import { clampMinutes } from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { actionT } from "@/lib/i18n/action";
import { createClient } from "@/lib/supabase/server";

/**
 * Écrire le temps disponible.
 *
 * Deux gestes, deux écritures. La **semaine type** est un réglage : sept entiers sur le
 * profil, remplacés en bloc. Un **jour off** est une exception datée : une ligne posée ou
 * retirée, sans toucher au reste.
 *
 * Les deux invalident le profil, parce que c'est lui qui porte la semaine et que le plan est
 * recalculé à chaque rendu - il n'y a pas de plan stocké à reconstruire.
 */

export interface AvailabilityResult {
  status: "ok" | "error";
  message?: string;
}

export async function saveWeeklyMinutes(minutes: number[]): Promise<AvailabilityResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  if (!Array.isArray(minutes) || minutes.length !== 7) {
    return { status: "error", message: await actionT("app.errors.badWeek") };
  }

  const { error } = await supabase
    .from("profiles")
    .update({ weekly_minutes: minutes.map(clampMinutes) })
    .eq("id", user.id);

  if (error) return { status: "error", message: await actionT("app.errors.saveFailed") };

  revalidateUserData(user.id, "profile");
  revalidatePath("/app/plan");
  revalidatePath("/app");
  return { status: "ok" };
}

/**
 * Poser ou lever une exception sur un jour.
 *
 * `minutes` à `null` retire l'exception : le jour retombe sur la semaine type. C'est ce que
 * fait le second appui sur un jour déjà marqué, et c'est pour ça que l'action est une bascule
 * plutôt que deux.
 */
export async function setDayAvailability(
  day: string,
  minutes: number | null,
): Promise<AvailabilityResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) {
    return { status: "error", message: await actionT("app.errors.unknownDate") };
  }

  if (minutes == null) {
    const { error } = await supabase
      .from("availability_exceptions")
      .delete()
      .eq("user_id", user.id)
      .eq("day", day);
    if (error) return { status: "error", message: await actionT("app.errors.saveFailed") };
  } else {
    const { error } = await supabase
      .from("availability_exceptions")
      .upsert(
        { user_id: user.id, day, minutes: clampMinutes(minutes) },
        { onConflict: "user_id,day" },
      );
    if (error) return { status: "error", message: await actionT("app.errors.saveFailed") };
  }

  revalidateUserData(user.id, "profile");
  revalidatePath("/app/plan");
  revalidatePath("/app");
  return { status: "ok" };
}

/**
 * Ouvrir du temps sur chaque jour déjà ouvert de la semaine type.
 *
 * C'est le levier « ajoute N minutes » du verdict : il ne touche pas aux jours à zéro, parce
 * qu'un jour déclaré indisponible l'a été pour une raison, et qu'un plan n'a pas à décider
 * qu'on travaillera le dimanche.
 */
export async function addWeeklyMinutes(extra: number): Promise<AvailabilityResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const { data } = await supabase
    .from("profiles")
    .select("daily_minutes, weekly_minutes")
    .eq("id", user.id)
    .maybeSingle();

  const row = data as { daily_minutes: number | null; weekly_minutes: number[] | null } | null;
  const base =
    row?.weekly_minutes && row.weekly_minutes.length === 7
      ? row.weekly_minutes
      : new Array<number>(7).fill(row?.daily_minutes ?? 15);

  const next = base.map((value) => (value > 0 ? clampMinutes(value + extra) : 0));
  return saveWeeklyMinutes(next);
}
