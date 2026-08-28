"use server";

import { revalidatePath } from "next/cache";

import { sheetLanguage } from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { createClient } from "@/lib/supabase/server";

/**
 * Écrire une carte à la main, la corriger, la supprimer.
 *
 * **Une carte écrite par un modèle doit pouvoir être corrigée.** C'est ce qui manquait le plus :
 * on lisait quatorze cartes sans pouvoir toucher celle dont la réponse était fausse, et une carte
 * fausse révisée vingt fois installe l'erreur au lieu du cours. C'est aussi l'écran où le web bat
 * le téléphone - on corrige vingt cartes à la suite au clavier.
 *
 * La suppression est **douce** (`deleted_at`), comme partout ailleurs : un appareil hors ligne
 * depuis trois jours doit apprendre qu'une carte a disparu, et une ligne effacée ne se raconte pas.
 *
 * Chaque écriture porte son filtre `user_id`, alors que le cloisonnement suffirait - c'est la leçon
 * déjà payée côté iOS, et une requête qui s'en remet à la politique est une requête qu'une
 * politique ajoutée un jour recasse.
 */

export interface CardResult {
  status: "ok" | "error";
  message?: string;
  cardId?: string;
}

const MAX_SIDE = 2_000;

export async function updateCard(input: {
  cardId: string;
  courseId: string;
  front: string;
  back: string;
  hint?: string | null;
  choices?: string[];
  correctChoiceIndex?: number;
}): Promise<CardResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  const front = input.front.trim().slice(0, MAX_SIDE);
  const back = input.back.trim().slice(0, MAX_SIDE);
  if (front.length === 0 || back.length === 0) {
    return { status: "error", message: "Une carte a besoin des deux faces." };
  }

  const patch: Record<string, unknown> = {
    front,
    back,
    hint: input.hint?.trim() || null,
    updated_at: new Date().toISOString(),
  };

  // Les propositions ne sont touchées que si l'écran en a envoyé : une carte recto verso n'a pas à
  // se voir vider un tableau qu'elle n'utilise pas.
  if (input.choices) {
    const choices = input.choices.map((choice) => choice.trim()).filter(Boolean).slice(0, 6);
    patch.choices = choices;
    patch.correct_choice_index = Math.min(
      Math.max(input.correctChoiceIndex ?? 0, 0),
      Math.max(0, choices.length - 1),
    );
  }

  const { error } = await supabase
    .from("flashcards")
    .update(patch)
    .eq("user_id", user.id)
    .eq("id", input.cardId);

  if (error) return { status: "error", message: error.message };

  revalidateUserData(user.id, "cards");
  revalidatePath(`/app/c/${input.courseId}/cartes`);
  return { status: "ok" };
}

export async function createCard(input: {
  courseId: string;
  front: string;
  back: string;
  kind?: "basic" | "cloze" | "choice";
  choices?: string[];
  correctChoiceIndex?: number;
}): Promise<CardResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  const front = input.front.trim().slice(0, MAX_SIDE);
  const back = input.back.trim().slice(0, MAX_SIDE);
  if (front.length === 0 || back.length === 0) {
    return { status: "error", message: "Une carte a besoin des deux faces." };
  }

  // La position se prend derrière la dernière : les cartes gardent l'ordre dans lequel elles sont
  // arrivées, et une carte ajoutée à la main ne s'insère pas au milieu d'un paquet déjà révisé.
  const { data: last } = await supabase
    .from("flashcards")
    .select("position")
    .eq("user_id", user.id)
    .eq("course_id", input.courseId)
    .is("deleted_at", null)
    .order("position", { ascending: false })
    .limit(1)
    .maybeSingle();

  const choices = (input.choices ?? []).map((choice) => choice.trim()).filter(Boolean).slice(0, 6);
  const id = crypto.randomUUID();

  const { error } = await supabase.from("flashcards").insert({
    id,
    user_id: user.id,
    course_id: input.courseId,
    front,
    back,
    hint: null,
    position: (last?.position ?? -1) + 1,
    kind: input.kind ?? (choices.length > 0 ? "choice" : "basic"),
    choices,
    correct_choice_index: choices.length > 0 ? (input.correctChoiceIndex ?? 0) : 0,
    // Une carte neuve part due tout de suite : c'est la file d'étude qui décide combien on en
    // introduit par jour, pas la date d'échéance.
    state: "new",
    due_date: new Date().toISOString(),
  });

  if (error) return { status: "error", message: error.message };

  revalidateUserData(user.id, "cards");
  revalidatePath(`/app/c/${input.courseId}/cartes`);
  revalidatePath("/app");
  revalidatePath("/app/cours");
  return { status: "ok", cardId: id };
}

export async function createOcclusionCards(input: {
  courseId: string;
  image: string;
  zones: { x: number; y: number; width: number; height: number; label: string }[];
}): Promise<CardResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  if (!input.image.startsWith("data:image/")) {
    return { status: "error", message: "L'image n'a pas pu être lue." };
  }
  if (input.image.length > 1_800_000) {
    return { status: "error", message: "Cette image est trop lourde. Choisis-en une plus petite." };
  }

  const zones = input.zones.filter(
    (zone) =>
      zone.label.trim().length > 0 && zone.width > 0.02 && zone.height > 0.02,
  );
  if (zones.length === 0) {
    return { status: "error", message: "Trace au moins une zone et nomme-la." };
  }

  const { data: last } = await supabase
    .from("flashcards")
    .select("position")
    .eq("user_id", user.id)
    .eq("course_id", input.courseId)
    .is("deleted_at", null)
    .order("position", { ascending: false })
    .limit(1)
    .maybeSingle();

  const group = crypto.randomUUID();
  const now = new Date().toISOString();
  const rows = zones.map((zone, index) => ({
    id: crypto.randomUUID(),
    user_id: user.id,
    course_id: input.courseId,
    front: "Quelle zone est masquée ?",
    back: zone.label.trim().slice(0, MAX_SIDE),
    hint: null,
    position: (last?.position ?? -1) + 1 + index,
    kind: "occlusion",
    choices: [],
    correct_choice_index: 0,
    mask_x: zone.x,
    mask_y: zone.y,
    mask_width: zone.width,
    mask_height: zone.height,
    group_id: group,
    image_path: input.image,
    state: "new",
    due_date: now,
  }));

  const { error } = await supabase.from("flashcards").insert(rows);
  if (error) return { status: "error", message: error.message };

  revalidateUserData(user.id, "cards");
  revalidatePath(`/app/c/${input.courseId}/cartes`);
  revalidatePath("/app");
  revalidatePath("/app/cours");
  revalidatePath("/app/reviser");
  return { status: "ok", cardId: rows[0]?.id };
}

export async function deleteCard(cardId: string, courseId: string): Promise<CardResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  const { error } = await supabase
    .from("flashcards")
    .update({ deleted_at: new Date().toISOString(), updated_at: new Date().toISOString() })
    .eq("user_id", user.id)
    .eq("id", cardId);

  if (error) return { status: "error", message: error.message };

  revalidateUserData(user.id, "cards");
  revalidatePath(`/app/c/${courseId}/cartes`);
  revalidatePath("/app");
  revalidatePath("/app/cours");
  return { status: "ok" };
}

/**
 * Expliquer un passage de la fiche.
 *
 * C'est la fonction `explain-selection`, déjà déployée et déjà protégée par le jeton de
 * l'utilisateur : l'appel part **du serveur**, donc la fonction sait qui demande et décompte. Un
 * appel depuis le navigateur aurait laissé la clé publiable autoriser une dépense.
 */
export interface Explanation {
  headline: string;
  body: string;
  example?: string;
  watchOut?: string;
  /** La carte que la fonction propose au passage : elle sait déjà quoi demander sur ce point. */
  card?: { front: string; back: string };
}

export async function explainSelection(input: {
  selection: string;
  courseId: string;
}): Promise<{ status: "ok" | "error"; explanation?: Explanation; message?: string }> {
  const selection = input.selection.trim().slice(0, 1_200);
  if (selection.length < 2) {
    return { status: "error", message: "Sélectionne un passage à expliquer." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  const [{ data: course }, { data: profile }] = await Promise.all([
    supabase
      .from("courses")
      .select("title, subject, context_text")
      .eq("user_id", user.id)
      .eq("id", input.courseId)
      .maybeSingle(),
    supabase.from("profiles").select("country_code, sheet_language").eq("id", user.id).maybeSingle(),
  ]);

  if (!course) return { status: "error", message: "Cours introuvable." };

  const { data, error } = await supabase.functions.invoke("explain-selection", {
    body: {
      selection,
      // Le contexte est celui **enregistré** avec la fiche : le recalculer donnerait une seconde
      // version du même texte, et deux rédactions du même contenu finissent par se contredire.
      context: course.context_text?.slice(0, 12_000),
      title: course.title,
      subject: course.subject ?? undefined,
      // L'explication se lit dans la langue de la fiche : un cours écrit en polonais expliqué en
      // français fait deux langues sur le même écran.
      language: sheetLanguage(profile?.sheet_language, profile?.country_code),
    },
  });

  if (error) {
    const context = (error as { context?: Response }).context;
    if (context && typeof context.json === "function") {
      try {
        const body = (await context.json()) as { error?: string };
        if (body?.error) return { status: "error", message: body.error };
      } catch {
        // Un corps illisible : on retombe sur le message du transport.
      }
    }
    return { status: "error", message: "L'explication n'a pas pu être écrite." };
  }

  const explanation = (data as { explanation?: Explanation } | null)?.explanation;
  if (!explanation?.headline) return { status: "error", message: "Rien n'est revenu." };

  return { status: "ok", explanation };
}
