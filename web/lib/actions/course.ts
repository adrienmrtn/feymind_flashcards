"use server";

import { revalidatePath } from "next/cache";

import {
  DEFAULT_QUOTA,
  clampQuota,
  latexCommandsToUnicode,
  sheetLanguage,
  type CourseVisibility,
  type GenerationLanguage,
  type QuestionQuota,
  type SheetLength,
} from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { createSheetFromImport, type ImportResult } from "@/lib/import/create-sheet";
import { previewYouTubeOnServer, readYouTubeOnServer } from "@/lib/import/youtube-server";
import { actionT } from "@/lib/i18n/action";
import { createClient } from "@/lib/supabase/server";

export type { ImportResult } from "@/lib/import/create-sheet";

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

/** Le texte le plus court qui mérite qu'on dépense un appel. La fonction refuse en dessous. */
const MINIMUM_TEXT = 40;

export async function importFromText(input: {
  text: string;
  hintTitle?: string;
  sourceName?: string;
  source?: "text" | "pdf" | "docx" | "youtube";
  visibility?: CourseVisibility;
  /** Le volume demandé, en blocs. C'est la source de vérité ; le format n'en est que le nom. */
  blocks?: number;
  length?: SheetLength;
  /**
   * Langue de **cette** fiche. `source` reste dans la langue du document.
   * Absent, on fait comme l'écran : on ne force rien.
   */
  language?: GenerationLanguage;
  /** Prompt libre, pris en compte à l'écriture de la fiche. */
  instructions?: string;
  /**
   * Pages JPEG en data URL, pour extraire les schémas. Plafond aligné sur
   * `generate-course` : six images, quatre millions de caractères.
   */
  images?: string[];
}): Promise<ImportResult> {
  // L'écriture réelle n'est **pas** une Server Action : voir `create-sheet`.
  return createSheetFromImport(input);
}

/**
 * Invalide les listes **après** l'ouverture de la fiche. Appelé depuis le
 * voile, une fois le cours dans le DOM : plus de collision de vols.
 */
export async function refreshLibraryAfterImport(): Promise<void> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return;

  revalidateUserData(user.id, "courses");
  revalidatePath("/app", "layout");
  revalidatePath("/app", "page");
  revalidatePath("/app/cours");
  revalidatePath("/app/paquets");
}

/** L'aperçu d'une vidéo, avant de dépenser quoi que ce soit. */
export async function youtubePreview(url: string, languages?: string[]) {
  const local = await previewYouTubeOnServer(url, languages?.[0] ?? "fr");
  if (local.status === "ok") return local;

  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("youtube-transcript", {
    body: { url, metadataOnly: true, languages: languages?.slice(0, 6) },
  });

  if (error) return { status: "error" as const, message: await readableError(error) };
  return { status: "ok" as const, video: (data as { video?: unknown })?.video };
}

/** Les sous-titres seuls, sans écrire la fiche : le repli quand l'onglet n'a pas pu lire. */
export async function youtubeTranscript(url: string, languages?: string[]) {
  const local = await readYouTubeOnServer(url, languages ?? ["fr", "en"]);
  if (local.status === "ok") return local;

  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("youtube-transcript", {
    body: { url, languages: languages?.slice(0, 6) },
  });

  if (error) return { status: "error" as const, message: await readableError(error) };

  const payload = data as
    | { transcript?: { text?: string }; video?: { title?: string } }
    | null;
  const text = payload?.transcript?.text ?? "";

  if (text.length < MINIMUM_TEXT) {
    return {
      status: "error" as const,
      message: await actionT("app.errors.videoNoCaptions"),
    };
  }

  return {
    status: "ok" as const,
    text,
    title: payload?.video?.title ?? "Vidéo YouTube",
  };
}

/** Les sous-titres, puis la fiche - en deux temps, parce que le premier est gratuit. */
export async function importFromYouTube(
  url: string,
  options?: {
    blocks?: number;
    length?: SheetLength;
    visibility?: CourseVisibility;
    language?: GenerationLanguage;
    instructions?: string;
  },
): Promise<ImportResult> {
  const remote = await youtubeTranscript(url);
  if (remote.status !== "ok") return remote;

  return importFromText({
    text: remote.text,
    hintTitle: remote.title,
    sourceName: remote.title,
    source: "youtube",
    blocks: options?.blocks,
    length: options?.length,
    visibility: options?.visibility,
    language: options?.language,
    instructions: options?.instructions,
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
  if (!user) return { status: "error" as const, message: await actionT("app.errors.signIn") };

  const [{ data: course }, { data: profile }] = await Promise.all([
    supabase
      .from("courses")
      .select("id, title, subject, context_text, source")
      .eq("user_id", user.id)
      .eq("id", courseId)
      .maybeSingle(),
    supabase
      .from("profiles")
      .select("country_code, sheet_language")
      .eq("id", user.id)
      .maybeSingle(),
  ]);

  if (!course) return { status: "error" as const, message: await actionT("app.errors.courseMissing") };

  // Un paquet n'a pas de fiche à relire : les cartes s'écrivent à la main,
  // ou on recopie un Anki. La matière ne part pas au modèle.
  if (course.source === "deck") {
    return { status: "error" as const, message: await actionT("app.errors.cardsNeedContext") };
  }

  const context = (course.context_text ?? "").trim();
  if (context.length < 40) {
    return { status: "error" as const, message: await actionT("app.errors.cardsNeedContext") };
  }

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
      context: context,
      existing: (existing ?? []).slice(0, 60).map((row) => row.front),
      quota,
      language: sheetLanguage(profile?.sheet_language, profile?.country_code),
    },
  });

  if (error) return { status: "error" as const, message: await readableError(error) };

  const cards = (data as { cards?: RawCard[] } | null)?.cards ?? [];
  if (cards.length === 0) {
    return { status: "error" as const, message: await actionT("app.errors.noCardsWritten") };
  }

  const start = (existing?.[0]?.position ?? -1) + 1;

  const { error: insertError } = await supabase.from("flashcards").insert(
    cards.map((card, index) => ({
      id: crypto.randomUUID(),
      user_id: user.id,
      course_id: courseId,
      front: latexCommandsToUnicode(card.front ?? ""),
      back: latexCommandsToUnicode(card.back ?? ""),
      hint: card.hint ? latexCommandsToUnicode(card.hint) : null,
      position: start + index,
      kind: card.kind ?? "basic",
      choices:
        card.kind === "choice"
          ? (card.choices ?? []).map((choice) => latexCommandsToUnicode(choice))
          : [],
      correct_choice_index: card.answerIndex ?? 0,
      // Une carte neuve part due tout de suite : c'est la file d'étude qui décide combien on en
      // introduit par jour, pas la date d'échéance.
      state: "new",
      due_date: new Date().toISOString(),
    })),
  );

  if (insertError) return { status: "error" as const, message: insertError.message };

  revalidateUserData(user.id, "cards");
  revalidatePath(`/app/c/${courseId}/cartes`);
  revalidatePath("/app");
  revalidatePath("/app/cours");
  revalidatePath("/app/paquets");
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
 * personne. Le refus utile - « le document ne contient pas assez de contenu »,
 * « trop de générations aujourd'hui » - est dans le corps, et c'est celui-là
 * qu'on montre. Le plafond lui-même ne s'écrit pas.
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
