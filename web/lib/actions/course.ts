"use server";

import { revalidatePath } from "next/cache";

import {
  DEFAULT_QUOTA,
  clampBlocks,
  clampQuota,
  countryFor,
  isSheetLength,
  isVisibility,
  lengthContaining,
  normalizeSheet,
  resolveEmoji,
  sheetToPlainText,
  type CourseVisibility,
  type QuestionQuota,
  type SheetBlock,
  type SheetLength,
} from "@micabo/core";

import { createClient } from "@/lib/supabase/server";

/**
 * L'import, et la production des cartes.
 *
 * **Les appels au modèle partent du serveur**, jamais du navigateur, et c'est le point le plus
 * important du fichier. `supabase.functions.invoke` emporte le jeton de l'utilisateur lu dans le
 * cookie : la fonction sait donc qui appelle, elle décompte, et rien de tout ça ne dépend de ce
 * que le navigateur veut bien envoyer. La clé publiable ne sert plus d'autorisation à quoi que ce
 * soit de coûteux.
 *
 * **L'identifiant est créé ici**, et c'est la règle du schéma depuis le premier jour : l'app crée
 * un UUID au moment de l'import, bien avant de savoir s'il y a un compte, et c'est ce même
 * identifiant qui devient la clé primaire. Sans ça il faudrait une table de correspondance, et deux
 * appareils qui remontent le même cours créeraient deux lignes.
 */

export interface ImportResult {
  status: "ok" | "error";
  courseId?: string;
  message?: string;
}

interface GeneratedCourse {
  title?: string;
  subject?: string;
  emoji?: string;
  summary?: string;
  sheet?: { blocks?: unknown };
  contextText?: string;
}

/** Le texte le plus court qui mérite qu'on dépense un appel. La fonction refuse en dessous. */
const MINIMUM_TEXT = 40;
const MAXIMUM_TEXT = 60_000;

export async function importFromText(input: {
  text: string;
  hintTitle?: string;
  sourceName?: string;
  source?: "text" | "pdf" | "docx" | "youtube";
  visibility?: CourseVisibility;
  /** Le volume demandé, en blocs. C'est la source de vérité ; le format n'en est que le nom. */
  blocks?: number;
  length?: SheetLength;
}): Promise<ImportResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi pour importer un cours." };

  const text = input.text.trim().slice(0, MAXIMUM_TEXT);
  if (text.length < MINIMUM_TEXT) {
    return { status: "error", message: "Ce texte est trop court pour en faire une fiche." };
  }

  // Le profil décide de **la façon dont le modèle écrit** : le stade d'étude commande le registre,
  // et le pays commande à la fois le système scolaire de référence et la langue. Les envoyer
  // n'est pas une option, c'est ce qui distingue une fiche de lycée d'une fiche de master.
  const { data: profile } = await supabase
    .from("profiles")
    .select("study_level, country_code, sheet_length")
    .eq("id", user.id)
    .maybeSingle();

  const country = countryFor(profile?.country_code);

  // Le réglage de l'écran gagne sur celui du profil, et le profil sert de défaut : c'est ce que
  // fait l'app, où le curseur de l'import part de la préférence enregistrée. `blocks` commande, et
  // `length` reste envoyé parce que la fonction Edge le comprend depuis toujours.
  const stored = isSheetLength(profile?.sheet_length) ? profile.sheet_length : "standard";
  const wantedBlocks = input.blocks ? clampBlocks(input.blocks) : undefined;
  const length = wantedBlocks ? lengthContaining(wantedBlocks) : (input.length ?? stored);

  const { data, error } = await supabase.functions.invoke("generate-course", {
    body: {
      text,
      hintTitle: input.hintTitle,
      sourceName: input.sourceName,
      level: profile?.study_level ?? undefined,
      country: country.code,
      language: country.language,
      length,
      blocks: wantedBlocks,
      source: input.source ?? "text",
    },
  });

  if (error) return { status: "error", message: await readableError(error) };

  const course = (data as { course?: GeneratedCourse } | null)?.course;
  if (!course) return { status: "error", message: "La fiche n'a pas pu être écrite." };

  // La fiche est renormalisée avec **le même code que le serveur** : c'est la copie surveillée du
  // module de fiche, donc les plafonds appliqués ici sont exactement ceux d'en face.
  const blocks: SheetBlock[] = normalizeSheet(course.sheet ?? { blocks: [] });
  if (blocks.length === 0) {
    return { status: "error", message: "La fiche rendue n'était pas exploitable." };
  }

  const title = (course.title ?? input.hintTitle ?? "Cours sans titre").trim();
  const id = crypto.randomUUID();

  const { error: insertError } = await supabase.from("courses").insert({
    id,
    user_id: user.id,
    title,
    subject: course.subject ?? null,
    summary: course.summary ?? "",
    emoji: resolveEmoji(course.emoji, course.subject, title),
    source: input.source ?? "text",
    source_file_name: input.sourceName ?? null,
    // L'empreinte reconnaît un chapitre déjà importé. Elle est calculée sur le texte lu, pas sur
    // la fiche : deux générations du même document donnent deux fiches et un seul cours.
    fingerprint: await fingerprint(text),
    raw_text: text,
    sheet: { blocks },
    context_text: course.contextText ?? sheetToPlainText(blocks),
    // Le choix se fait à l'import et pas après : un cours qui part public le temps qu'on y pense
    // est un cours qui a été visible, et le refermer ensuite ne rattrape pas la minute passée.
    visibility: isVisibility(input.visibility) ? input.visibility : "public",
  });

  if (insertError) return { status: "error", message: insertError.message };

  revalidatePath("/app");
  revalidatePath("/app/cours");
  return { status: "ok", courseId: id };
}

/** L'aperçu d'une vidéo, avant de dépenser quoi que ce soit. */
export async function youtubePreview(url: string) {
  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("youtube-transcript", {
    body: { url, metadataOnly: true },
  });

  if (error) return { status: "error" as const, message: await readableError(error) };
  return { status: "ok" as const, video: (data as { video?: unknown })?.video };
}

/** Les sous-titres, puis la fiche — en deux temps, parce que le premier est gratuit. */
export async function importFromYouTube(
  url: string,
  options?: { blocks?: number; length?: SheetLength; visibility?: CourseVisibility },
): Promise<ImportResult> {
  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("youtube-transcript", { body: { url } });

  if (error) return { status: "error", message: await readableError(error) };

  const payload = data as
    | { transcript?: { text?: string }; video?: { title?: string } }
    | null;
  const text = payload?.transcript?.text ?? "";

  if (text.length < MINIMUM_TEXT) {
    return { status: "error", message: "Cette vidéo n'a pas assez de sous-titres exploitables." };
  }

  return importFromText({
    text,
    hintTitle: payload?.video?.title,
    sourceName: payload?.video?.title,
    source: "youtube",
    blocks: options?.blocks,
    length: options?.length,
    visibility: options?.visibility,
  });
}

/**
 * Les cartes d'un cours.
 *
 * Le contexte envoyé est le `context_text` **enregistré en base**, écrit par le serveur au moment
 * de la fiche. Le recalculer ici donnerait une seconde version du même texte, et deux rédactions du
 * même contenu finissent par se contredire.
 */
export async function generateCards(courseId: string, requested?: QuestionQuota) {
  // Le quota est borné **ici** et pas seulement dans l'écran : une action serveur est un point
  // d'entrée public, et un quota de mille cartes envoyé à la main coûterait mille cartes.
  const quota = clampQuota(requested ?? DEFAULT_QUOTA);

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error" as const, message: "Connecte-toi." };

  const { data: course } = await supabase
    .from("courses")
    .select("id, title, subject, context_text")
    .eq("user_id", user.id)
    .eq("id", courseId)
    .maybeSingle();

  if (!course) return { status: "error" as const, message: "Cours introuvable." };

  // Les recto des cartes déjà écrites partent avec la demande : sans elles, une seconde passe
  // repose les mêmes questions.
  const { data: existing } = await supabase
    .from("flashcards")
    .select("front, position")
    .eq("user_id", user.id)
    .eq("course_id", courseId)
    .is("deleted_at", null)
    .order("position", { ascending: false });

  const { data, error } = await supabase.functions.invoke("generate-flashcards", {
    body: {
      title: course.title,
      subject: course.subject ?? undefined,
      context: course.context_text,
      existing: (existing ?? []).slice(0, 60).map((row) => row.front),
      quota,
    },
  });

  if (error) return { status: "error" as const, message: await readableError(error) };

  const cards = (data as { cards?: RawCard[] } | null)?.cards ?? [];
  if (cards.length === 0) {
    return { status: "error" as const, message: "Aucune carte n'a pu être écrite." };
  }

  const start = (existing?.[0]?.position ?? -1) + 1;

  const { error: insertError } = await supabase.from("flashcards").insert(
    cards.map((card, index) => ({
      id: crypto.randomUUID(),
      user_id: user.id,
      course_id: courseId,
      front: card.front ?? "",
      back: card.back ?? "",
      hint: card.hint ?? null,
      position: start + index,
      kind: card.kind ?? "basic",
      choices: card.kind === "choice" ? (card.choices ?? []) : [],
      correct_choice_index: card.answerIndex ?? 0,
      // Une carte neuve part due tout de suite : c'est la file d'étude qui décide combien on en
      // introduit par jour, pas la date d'échéance.
      state: "new",
      due_date: new Date().toISOString(),
    })),
  );

  if (insertError) return { status: "error" as const, message: insertError.message };

  revalidatePath(`/app/c/${courseId}/cartes`);
  revalidatePath("/app");
  revalidatePath("/app/cours");
  return { status: "ok" as const, count: cards.length };
}

interface RawCard {
  kind?: "basic" | "cloze" | "choice";
  front?: string;
  back?: string;
  hint?: string;
  choices?: string[];
  answerIndex?: number;
}

/**
 * Le message du serveur, et pas celui du transport.
 *
 * `functions.invoke` rend « Edge Function returned a non-2xx status code », qui ne dit rien à
 * personne. Le refus utile — « le document ne contient pas assez de contenu », « tu as atteint la
 * limite de vingt générations » — est dans le corps de la réponse, et c'est celui-là qu'on montre.
 */
async function readableError(error: unknown): Promise<string> {
  const context = (error as { context?: Response }).context;
  if (context && typeof context.json === "function") {
    try {
      const body = (await context.json()) as { error?: string };
      if (body?.error) return body.error;
    } catch {
      // Un corps illisible : on retombe sur le message du transport, qui vaut mieux que rien.
    }
  }
  return fallbackMessage(error);
}

function fallbackMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Micabo n'a pas pu écrire cette fiche.";
}

/** Empreinte du contenu, pour reconnaître un chapitre déjà importé. */
async function fingerprint(text: string): Promise<string> {
  const normalized = text.toLowerCase().replace(/\s+/g, " ").trim().slice(0, 4_000);
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(normalized));
  return Array.from(new Uint8Array(digest))
    .slice(0, 16)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
