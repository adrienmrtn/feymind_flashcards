"use server";

import { revalidatePath } from "next/cache";

import {
  DEFAULT_VISIBILITY,
  entitlement,
  isChoosableVisibility,
  latexCommandsToUnicode,
  resolveEmoji,
  type CourseVisibility,
} from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { listCourses } from "@/lib/data/courses";
import { DECK_CHUNK } from "@/lib/deck";
import { readEntitlement } from "@/lib/data/entitlement";
import { actionT } from "@/lib/i18n/action";
import { createClient } from "@/lib/supabase/server";

/**
 * Un **paquet** : des cartes sans cours.
 *
 * Tout partait d'un document, donc d'une fiche, et c'est la moitié de ce qu'on révise qui
 * n'avait pas de porte d'entrée : du vocabulaire, des dates, des formules, des choses qu'on
 * a déjà comprises et qu'il faut retenir. L'iPhone sait en ouvrir un depuis `CreateDeckView`,
 * le web ne savait pas. Ces actions sont l'autre moitié de la même chose.
 *
 * **Un paquet est une ligne de `courses` sans fiche.** C'était déjà prévu au premier jour du
 * schéma - `sheet` est nullable, l'empreinte est vide sur un paquet, `source` a sa valeur
 * `deck` - et ne pas inventer une seconde table est ce qui fait qu'un paquet se révise, se
 * planifie pour un examen et se synchronise avec le téléphone sans une ligne de plus ailleurs.
 *
 * **Le versement des cartes est découpé.** Un paquet Anki de mille cartes ne passe pas dans un
 * corps d'action serveur, et l'écran a besoin d'avancer pendant ce temps. `addDeckCards` est
 * donc appelée plusieurs fois de suite, et elle est écrite pour ça : elle reprend la position
 * là où la dernière l'a laissée.
 */

export interface DeckResult {
  status: "ok" | "error" | "paywall";
  courseId?: string;
  message?: string;
}

const MAX_TITLE = 120;
const MAX_SUBJECT = 80;
const MAX_SIDE = 2_000;

export async function createDeck(input: {
  title: string;
  subject?: string;
  visibility?: CourseVisibility;
}): Promise<DeckResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signInImport") };

  // Un paquet occupe une place de cours, donc il passe la même porte : sans ça, le gratuit
  // s'ouvrirait en grand par un chemin qui ne s'appelle pas « importer ».
  const [right, courses] = await Promise.all([readEntitlement(), listCourses()]);
  if (
    !entitlement.canImportCourse(
      right,
      courses.map((course) => ({ isFromLibrary: course.is_from_library })),
    )
  ) {
    return { status: "paywall", message: await actionT("app.errors.secondCoursePro") };
  }

  const title = input.title.trim().slice(0, MAX_TITLE) || (await actionT("app.deck.untitled"));
  const subject = input.subject?.trim().slice(0, MAX_SUBJECT) || null;
  const id = crypto.randomUUID();

  const { error } = await supabase.from("courses").insert({
    id,
    user_id: user.id,
    title,
    subject,
    summary: "",
    emoji: resolveEmoji(null, subject, title),
    source: "deck",
    // Pas d'empreinte : deux paquets du même nom ne sont pas un doublon, et rien n'a été lu
    // qu'on risquerait de relire deux fois.
    fingerprint: "",
    raw_text: "",
    // Pas de fiche, et pas de contexte pour le modèle : un paquet se remplit à la
    // main, ou on recopie un Anki. La matière range le paquet, elle n'écrit rien.
    sheet: null,
    context_text: "",
    visibility: isChoosableVisibility(input.visibility) ? input.visibility : DEFAULT_VISIBILITY,
  });

  if (error) return { status: "error", message: error.message };

  revalidateUserData(user.id, "courses");
  revalidatePath("/app", "layout");
  revalidatePath("/app/cours");
  revalidatePath("/app/paquets");
  return { status: "ok", courseId: id };
}

export interface DeckCardInput {
  kind?: "basic" | "cloze";
  front: string;
  back: string;
  hint?: string;
}

export async function addDeckCards(input: {
  courseId: string;
  cards: DeckCardInput[];
}): Promise<{ status: "ok" | "error"; count?: number; message?: string }> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  // Le cours est relu avec son `user_id` : une action serveur est un point d'entrée public,
  // et un identifiant deviné ne doit pas pouvoir verser des cartes chez quelqu'un d'autre.
  const { data: course } = await supabase
    .from("courses")
    .select("id")
    .eq("user_id", user.id)
    .eq("id", input.courseId)
    .is("deleted_at", null)
    .maybeSingle();

  if (!course) return { status: "error", message: await actionT("app.errors.courseMissing") };

  const rows = input.cards.slice(0, DECK_CHUNK).flatMap((card) => {
    const front = latexCommandsToUnicode(card.front ?? "").trim().slice(0, MAX_SIDE);
    const back = latexCommandsToUnicode(card.back ?? "").trim().slice(0, MAX_SIDE);
    if (front.length === 0 || back.length === 0) return [];
    return [{ front, back, hint: card.hint?.trim().slice(0, MAX_SIDE) || null, kind: card.kind }];
  });

  if (rows.length === 0) return { status: "ok", count: 0 };

  // La position se prend derrière la dernière : les cartes gardent l'ordre dans lequel elles
  // sont arrivées, et un second versement ne s'insère pas au milieu du premier.
  const { data: last } = await supabase
    .from("flashcards")
    .select("position")
    .eq("user_id", user.id)
    .eq("course_id", input.courseId)
    .is("deleted_at", null)
    .order("position", { ascending: false })
    .limit(1)
    .maybeSingle();

  const start = (last?.position ?? -1) + 1;
  const now = new Date().toISOString();

  const { error } = await supabase.from("flashcards").insert(
    rows.map((row, index) => ({
      id: crypto.randomUUID(),
      user_id: user.id,
      course_id: input.courseId,
      front: row.front,
      back: row.back,
      hint: row.hint,
      position: start + index,
      kind: row.kind === "cloze" ? "cloze" : "basic",
      choices: [],
      correct_choice_index: 0,
      // **L'ordonnancement d'Anki ne suit pas.** Ses intervalles sortent de ses propres
      // options de paquet ; recopiés ici, ils donneraient des échéances que la file d'étude
      // ne sait pas expliquer. Tout repart neuf, et la file décide combien on en voit.
      state: "new",
      due_date: now,
    })),
  );

  if (error) return { status: "error", message: error.message };

  revalidateUserData(user.id, "cards");
  revalidatePath(`/app/c/${input.courseId}/cartes`);
  revalidatePath(`/app/c/${input.courseId}`);
  revalidatePath("/app");
  revalidatePath("/app/cours");
  revalidatePath("/app/paquets");
  revalidatePath(`/app/paquets/${input.courseId}`);
  return { status: "ok", count: rows.length };
}
