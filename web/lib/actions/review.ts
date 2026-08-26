"use server";

import { revalidatePath } from "next/cache";

import {
  DETERMINISTIC_CONFIG,
  ReviewRating,
  schedule,
  type CardSnapshot,
  type ReviewRating as Rating,
} from "@micabo/core";

import { createClient } from "@/lib/supabase/server";

/**
 * Ce qu'une note écrit.
 *
 * **Le calcul est refait ici, côté serveur, et pas confié au navigateur.** Le client sait déjà
 * afficher les intervalles sous les quatre boutons — c'est le même code — mais l'état qui part en
 * base est calculé là où personne ne peut le réécrire. Un onglet ouvert dans une console pourrait
 * sinon s'attribuer des intervalles de dix ans, et la répétition espacée ne veut plus rien dire.
 *
 * Deux écritures, et elles ne disent pas la même chose. `flashcards` porte **l'état**, qui se
 * corrige à chaque passage ; `review_logs` porte **le fait**, daté, qui ne se corrige jamais. C'est
 * lui qui portera les statistiques et la mesure de ce qui marche.
 *
 * Une révision faite ici compte sur le téléphone, et réciproquement : c'est tout l'intérêt d'avoir
 * porté SM-2 au lieu de l'approcher.
 */

export interface GradeResult {
  status: "ok" | "error";
  message?: string;
  /** L'état écrit, pour que le client puisse suivre sans recharger. */
  dueDate?: string;
  intervalDays?: number;
  state?: string;
}

export async function gradeCard(input: {
  cardId: string;
  rating: number;
  snapshot: CardSnapshot;
}): Promise<GradeResult> {
  const rating = asRating(input.rating);
  if (!rating) return { status: "error", message: "Note inconnue." };

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Session expirée." };

  const now = new Date();

  // La configuration déterministe : la dispersion d'Anki évite que des paquets entiers retombent
  // le même jour, mais elle n'a pas sa place dans une écriture dont le client connaît déjà
  // l'aperçu. Un bouton qui annonce « 25 j » et une base qui écrit 22 se contredisent à l'écran
  // suivant.
  const outcome = schedule(input.snapshot, rating, { now, config: DETERMINISTIC_CONFIG });

  const { error } = await supabase
    .from("flashcards")
    .update({
      state: outcome.state,
      due_date: outcome.dueDate.toISOString(),
      interval_days: outcome.intervalDays,
      ease_factor: outcome.easeFactor,
      repetitions: outcome.repetitions,
      lapses: outcome.lapses,
      step_index: outcome.stepIndex,
      last_reviewed_at: now.toISOString(),
    })
    .eq("user_id", user.id)
    .eq("id", input.cardId);

  if (error) return { status: "error", message: error.message };

  // L'historique est en ajout seul, et son échec ne doit pas défaire la révision : perdre une
  // ligne de statistiques est moins grave que faire repasser une carte qu'on vient de noter.
  await supabase.from("review_logs").insert({
    id: crypto.randomUUID(),
    user_id: user.id,
    card_id: input.cardId,
    reviewed_at: now.toISOString(),
    rating,
    state_before: input.snapshot.state,
    previous_interval_days: input.snapshot.intervalDays,
    new_interval_days: outcome.intervalDays,
    ease_after: outcome.easeFactor,
  });

  // **Aucune revalidation ici, et c'est le correctif.** `revalidatePath("/app/reviser")`
  // faisait re-rendre la page pendant la session : le serveur reconstruisait la file avec
  // les cartes dues **à cet instant**, n'en trouvait aucune — elles venaient toutes d'être
  // repoussées d'une minute — et remplaçait la session par « Tout est à jour », file en
  // mémoire comprise. La session s'évaporait au milieu d'un paquet.
  //
  // Rien n'est perdu : ces écrans lisent le cookie de session, donc ils sont rendus à
  // chaque requête et n'ont aucun cache à invalider.

  return {
    status: "ok",
    dueDate: outcome.dueDate.toISOString(),
    intervalDays: outcome.intervalDays,
    state: outcome.state,
  };
}

/** Mettre une carte de côté : elle sort de la file sans être notée. */
export async function suspendCard(cardId: string): Promise<{ status: "ok" | "error" }> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error" };

  const { error } = await supabase
    .from("flashcards")
    .update({ is_suspended: true })
    .eq("user_id", user.id)
    .eq("id", cardId);

  revalidatePath("/app/reviser");
  return { status: error ? "error" : "ok" };
}

function asRating(value: number): Rating | null {
  return value === ReviewRating.again ||
    value === ReviewRating.hard ||
    value === ReviewRating.good ||
    value === ReviewRating.easy
    ? (value as Rating)
    : null;
}
