"use server";

import { actionT } from "@/lib/i18n/action";
import { createClient } from "@/lib/supabase/server";

/**
 * **Les sous-titres d'une vidéo YouTube**, lus par la fonction `youtube-transcript` avec le
 * jeton de l'utilisateur. C'est le repli de la barre de Home quand l'onglet n'a pas pu lire
 * la vidéo lui-même (`lib/lesson/read-support.ts`).
 */
const MINIMUM_TEXT = 40;

export async function youtubeTranscript(url: string, languages?: string[]) {
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
  return error instanceof Error ? error.message : await actionT("app.errors.sheetWriteFailed");
}
