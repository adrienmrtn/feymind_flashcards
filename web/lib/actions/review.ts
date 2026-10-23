"use server";

import { revalidatePath } from "next/cache";

import {
  DEFAULT_CONFIG,
  ReviewRating,
  activeDeadlines,
  clampedToDeadline,
  entitlement,
  schedule,
  type CardSnapshot,
  type ReviewRating as Rating,
} from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { readEntitlement } from "@/lib/data/entitlement";
import { actionT } from "@/lib/i18n/action";
import { createClient } from "@/lib/supabase/server";

/**
 * Ce qu'une note écrit.
 *
 * **Le calcul est refait ici, côté serveur, et pas confié au navigateur.** Le client sait déjà
 * afficher les intervalles sous les quatre boutons - c'est le même code - mais l'état qui part en
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
  status: "ok" | "error" | "paywall";
  message?: string;
  /** L'état écrit, pour que le client puisse suivre sans recharger. */
  dueDate?: string;
  intervalDays?: number;
  state?: CardSnapshot["state"];
  /** L'état complet écrit en base : le client remplace sa copie par celle-ci. */
  snapshot?: CardSnapshot;
}

/**
 * Ce que le navigateur envoie : **quelle carte, quelle note**. Rien de son état.
 *
 * Le navigateur envoyait aussi son instantané de la carte, et c'est lui qui servait de point de
 * départ à SM-2. Un instantané a l'âge de la page : noter deux fois la même carte sans recharger
 * (la révision relancée depuis le même écran), ou la noter ici après l'iPhone, repartait d'un
 * état périmé et **écrasait** la progression faite entre-temps. Le serveur relit la ligne.
 * `snapshot` reste accepté pour ne pas casser une page déjà ouverte, et il est ignoré.
 */
export interface GradeInput {
  cardId: string;
  rating: number;
  /** @deprecated Ignoré : l'état de départ est relu en base. */
  snapshot?: CardSnapshot;
}

export async function gradeCard(input: GradeInput): Promise<GradeResult> {
  const rating = asRating(input.rating);
  if (!rating) return { status: "error", message: await actionT("app.errors.unknownRating") };

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.sessionExpired") };

  const right = await readEntitlement();
  if (!right.isPro) {
    const windowStart = new Date(Date.now() - 30 * 60 * 1000).toISOString();
    const { count } = await supabase
      .from("review_logs")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .gte("reviewed_at", windowStart);
    if (
      entitlement.hasReachedSessionLimit(
        right,
        count ?? 0,
        entitlement.WEB_FREE_TIER.cardsPerSession,
      )
    ) {
      return { status: "paywall" };
    }
  }

  return writeGrade(supabase, user.id, input, rating);
}

/**
 * **Une note posée depuis une leçon** : Encore, Bien, Facile. Le même calcul, le même journal,
 * sans le plafond de la session : les flashcards d'une leçon se révisent à leur rythme
 * (`docs/refonte-parcours.md` § 7, « les anciennes portes disparaissent »).
 */
export async function gradeLessonCard(input: GradeInput): Promise<GradeResult> {
  const rating = asRating(input.rating);
  if (!rating) return { status: "error", message: await actionT("app.errors.unknownRating") };

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.sessionExpired") };
  return writeGrade(supabase, user.id, input, rating);
}

async function writeGrade(
  supabase: Awaited<ReturnType<typeof createClient>>,
  userId: string,
  input: { cardId: string },
  rating: Rating,
): Promise<GradeResult> {
  const now = new Date();

  const [{ data: card, error: cardError }, { data: exams }] = await Promise.all([
    supabase
      .from("flashcards")
      .select(
        "id, course_id, is_suspended, state, interval_days, ease_factor, repetitions, lapses, step_index, due_date",
      )
      .eq("user_id", userId)
      .eq("id", input.cardId)
      .is("deleted_at", null)
      .maybeSingle(),
    supabase
      .from("exams")
      .select("exam_date, is_planned, course_ids")
      .eq("user_id", userId)
      .is("deleted_at", null),
  ]);

  if (cardError) return { status: "error", message: cardError.message };
  if (!card) return { status: "error", message: await actionT("app.errors.cardMissing") };

  // L'état de départ, **tel qu'il est en base** à cet instant - pas tel que la page l'a vu.
  const before: CardSnapshot = {
    state: card.state as CardSnapshot["state"],
    intervalDays: card.interval_days,
    easeFactor: card.ease_factor,
    repetitions: card.repetitions,
    lapses: card.lapses,
    stepIndex: card.step_index,
    dueDate: card.due_date,
  };

  const deadline = activeDeadlines(
    (exams ?? []).map((exam) => ({
      date: new Date(`${exam.exam_date}T12:00:00`),
      isPlanned: exam.is_planned,
      courseIds: exam.course_ids ?? [],
    })),
    [
      {
        id: card.id,
        courseId: card.course_id,
        isSuspended: card.is_suspended,
      },
    ],
    now,
  ).get(card.id);

  // SM-2 d'Anki (dispersion comprise), puis le plafond d'examen. L'aperçu
  // sous les boutons reste déterministe.
  const outcome = clampedToDeadline(
    schedule(before, rating, {
      now,
      config: DEFAULT_CONFIG,
      dueDate: before.dueDate,
    }),
    deadline,
    now,
  );

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
    .eq("user_id", userId)
    .eq("id", input.cardId);

  if (error) return { status: "error", message: error.message };

  const after: CardSnapshot = {
    state: outcome.state,
    intervalDays: outcome.intervalDays,
    easeFactor: outcome.easeFactor,
    repetitions: outcome.repetitions,
    lapses: outcome.lapses,
    stepIndex: outcome.stepIndex,
    dueDate: outcome.dueDate.toISOString(),
  };

  revalidateUserData(userId, "cards");
  // L'accueil doit se recaler sans rechargement dur. On ne touche pas à
  // `/app/reviser` : ça reconstruirait la file en pleine session.
  revalidatePath("/app");

  // L'historique est en ajout seul, et son échec ne doit pas défaire la révision : perdre une
  // ligne de statistiques est moins grave que faire repasser une carte qu'on vient de noter.
  await supabase.from("review_logs").insert({
    id: crypto.randomUUID(),
    user_id: userId,
    card_id: input.cardId,
    reviewed_at: now.toISOString(),
    rating,
    state_before: before.state,
    previous_interval_days: before.intervalDays,
    new_interval_days: outcome.intervalDays,
    ease_after: outcome.easeFactor,
  });

  // **Aucune revalidation ici, et c'est le correctif.** `revalidatePath("/app/reviser")`
  // faisait re-rendre la page pendant la session : le serveur reconstruisait la file avec
  // les cartes dues **à cet instant**, n'en trouvait aucune - elles venaient toutes d'être
  // repoussées d'une minute - et remplaçait la session par « Tout est à jour », file en
  // mémoire comprise. La session s'évaporait au milieu d'un paquet.
  //
  // Rien n'est perdu : ces écrans lisent le cookie de session, donc ils sont rendus à
  // chaque requête et n'ont aucun cache à invalider.

  return {
    status: "ok",
    dueDate: outcome.dueDate.toISOString(),
    intervalDays: outcome.intervalDays,
    state: outcome.state,
    snapshot: after,
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

  // Une carte mise de côté sort des compteurs, et ces compteurs sont maintenant lus depuis le
  // cache des cartes : sans ce mot, l'écran d'avant continuerait à l'annoncer comme due.
  revalidateUserData(user.id, "cards");
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
