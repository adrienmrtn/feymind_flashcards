"use client";

import { createClient } from "@/lib/supabase/client";
import { loadXpState, saveXpState } from "@/lib/xp/client";
import { isMissingXpColumn, mergeRemote, type RemoteXp } from "@/lib/xp/state";

/**
 * **L'XP qui monte dans `profiles`** (`docs/refonte-knowunity.md` § 2) : `xp_total`, `xp_week` et
 * `xp_week_start`, sur la ligne de l'élève, depuis le navigateur (le cloisonnement « Profil : le
 * sien » le permet). La synchro ne casse jamais à cause de l'XP :
 *
 * - **les colonnes peuvent ne pas exister encore** (migration `20261110120000_xp_league.sql` pas
 *   déployée) : la lecture ou l'écriture échoue sur une colonne `xp_*`, on n'envoie rien de plus
 *   le temps de la page, et ce qui restait à monter attend la prochaine visite ;
 * - toute autre erreur est muette, et le reste à monter attend aussi.
 */
let unavailable = false;
let running: Promise<void> | null = null;

export function syncXp(userId: string | null): Promise<void> {
  if (!userId || unavailable) return Promise.resolve();
  if (running) return running;
  running = push(userId).finally(() => {
    running = null;
  });
  return running;
}

async function push(userId: string): Promise<void> {
  const now = new Date();
  const state = loadXpState(now);
  if (state.pending.total <= 0) return;
  try {
    const supabase = createClient();
    const read = await supabase.from("profiles").select("xp_total, xp_week, xp_week_start").eq("id", userId).maybeSingle();
    if (read.error) {
      if (isMissingXpColumn(read.error)) unavailable = true;
      return;
    }
    const next = mergeRemote((read.data as RemoteXp | null) ?? null, state, now);
    const write = await supabase.from("profiles").update(next).eq("id", userId);
    if (write.error) {
      if (isMissingXpColumn(write.error)) unavailable = true;
      return;
    }
    // Ce qui a été gagné pendant l'aller-retour reste à monter : on ne retire que ce qui est parti.
    const latest = loadXpState(new Date());
    const sent = state.pending;
    saveXpState({
      ...latest,
      pending: {
        total: Math.max(0, latest.pending.total - sent.total),
        week: latest.pending.weekStart === sent.weekStart ? Math.max(0, latest.pending.week - sent.week) : latest.pending.week,
        weekStart: latest.pending.weekStart,
      },
    });
  } catch {
    // Hors ligne, ou le client refuse : on réessaiera.
  }
}
