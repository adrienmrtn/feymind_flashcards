import { authorize, withCors } from "../_shared/caller.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  extractVideoId,
  fetchVideoMetadata,
  YOUTUBE_LIMITS,
  YouTubeError,
} from "../_shared/youtube.ts";
import { readTranscript } from "../_shared/youtube-video.ts";

interface RequestBody {
  url?: string;
  /** Langues de l'utilisateur, par ordre de préférence. */
  languages?: string[];
  /** Vrai pour l'aperçu : on ne va pas chercher la transcription. */
  metadataOnly?: boolean;
}

/**
 * Lit une vidéo YouTube par ses sous-titres.
 *
 * La fonction sert deux moments du parcours. L'**aperçu** (`metadataOnly`) rend le titre,
 * la chaîne, la durée, la vignette et les langues de sous-titres disponibles. La
 * **transcription** vient après confirmation, et c'est le seul moment où l'on télécharge du
 * texte. Découper ainsi permet de montrer la vidéo avant de lancer la génération,
 * et de ne télécharger les sous-titres qu'après confirmation.
 *
 * L'aperçu ne refuse que ce dont il n'y a rien à montrer : un lien qui n'en est pas, une
 * vidéo inaccessible. L'absence de sous-titres est renvoyée telle quelle. Un cours trop
 * long n'est plus un refus : on lit le début, jusqu'à `YOUTUBE_LIMITS.maxDurationSeconds`.
 *
 * **Une absence de sous-titres n'est plus un refus non plus.** Depuis une Edge Function,
 * YouTube ferme l'accès aux pistes : le 8 septembre 2026, les 19 transcriptions demandées
 * ont toutes été refusées en 422 alors que les 9 aperçus passaient. `youtube-video.ts`
 * documente la mesure et le chemin qui reste ouvert — Gemini lit la vidéo chez Google.
 * Les sous-titres restent essayés d'abord : quand ils répondent, ils sont exacts et gratuits.
 */
Deno.serve((request: Request) =>
  withCors(request, async () => {
    try {
      // Cette fonction n'appelle aucun modèle, mais elle va chercher n'importe quelle URL :
      // laissée ouverte, c'est un relais anonyme. Elle passe donc le même contrôle, sans quota.
      // Pas de quota modèle : cette fonction ne parle pas à fal.ai. Le contrôle
      // d'identité reste, pour que ça ne serve pas de relais anonyme.
      await authorize(request, "youtube-transcript", { meter: false });
      const body = (await request.json()) as RequestBody;

      const videoId = extractVideoId(body.url);
      if (!videoId) {
        throw new YouTubeError("invalid_url", "Ce lien n'est pas une vidéo YouTube.", 400);
      }

      const languages = (Array.isArray(body.languages) ? body.languages : [])
        .filter((language): language is string =>
          typeof language === "string" && language.length > 0
        )
        .slice(0, 6);
      const primary = languages[0] ?? "fr";

      const metadata = await fetchVideoMetadata(videoId, primary);

      const video = {
        id: metadata.id,
        title: stripEmDashes(metadata.title),
        author: stripEmDashes(metadata.author),
        durationSeconds: metadata.durationSeconds,
        thumbnailUrl: metadata.thumbnailUrl,
        limitSeconds: YOUTUBE_LIMITS.maxDurationSeconds,
        captionLanguages: metadata.captions.map((track) => ({
          code: track.languageCode,
          name: stripEmDashes(track.languageName),
          isAutomatic: track.isAutomatic,
        })),
      };

      if (body.metadataOnly === true) {
        return json({ video });
      }

      const transcript = await readTranscript(videoId, metadata.captions, languages);
      const text = stripEmDashes(transcript.text).slice(0, YOUTUBE_LIMITS.maxTranscriptCharacters);

      return json({
        video,
        transcript: {
          text,
          languageCode: transcript.languageCode,
          languageName: stripEmDashes(transcript.languageName),
          isAutomatic: transcript.isAutomatic,
          source: transcript.source,
        },
      });
    } catch (error) {
      if (error instanceof YouTubeError) {
        // Un refus sans trace ne se corrige pas : les 19 refus du 8 septembre
        // n'ont laissé dans les journaux que leur statut, et il a fallu rejouer
        // la fonction à la main pour apprendre que les pistes manquaient.
        console.error(JSON.stringify({ youtube: "refus", code: error.code, ...error.details }));
        return json(
          { error: error.message, code: error.code, ...error.details },
          error.status,
        );
      }
      const message = error instanceof Error ? error.message : "Erreur inconnue.";
      console.error(JSON.stringify({ youtube: "erreur", message: message.slice(0, 200) }));
      return json({ error: message }, 500);
    }
  })
);

function stripEmDashes(value: string): string {
  return value.replace(/\s+[—–―]\s+/g, ", ").replace(/[—–―]/g, "-");
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
