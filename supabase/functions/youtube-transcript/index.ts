import { authorize, withCors } from "../_shared/caller.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  extractVideoId,
  fetchBestTranscript,
  fetchVideoMetadata,
  YOUTUBE_LIMITS,
  YouTubeError,
} from "../_shared/youtube.ts";

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
 * texte. Découper ainsi permet de refuser une vidéo de trois heures avant de dépenser le
 * moindre appel de génération.
 *
 * L'aperçu ne refuse que ce dont il n'y a rien à montrer : un lien qui n'en est pas, une
 * vidéo inaccessible. L'absence de sous-titres et une durée hors limite sont **renvoyées
 * telles quelles** : l'application préfère afficher la vidéo et dire pourquoi elle ne peut
 * pas la lire, avec sa durée réelle, plutôt qu'une alerte sans contexte. La transcription,
 * elle, applique les deux règles pour de bon.
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

      if (metadata.captions.length === 0) {
        throw new YouTubeError("no_captions", "Cette vidéo n'a pas de piste de sous-titres.");
      }

      // La durée est refusée avant tout téléchargement, et donc avant toute génération.
      if (
        metadata.durationSeconds > 0 &&
        metadata.durationSeconds > YOUTUBE_LIMITS.maxDurationSeconds
      ) {
        throw new YouTubeError(
          "too_long",
          `Cette vidéo dure ${metadata.durationSeconds} secondes, au delà de la limite.`,
          422,
          {
            durationSeconds: metadata.durationSeconds,
            limitSeconds: YOUTUBE_LIMITS.maxDurationSeconds,
          },
        );
      }

      const transcript = await fetchBestTranscript(metadata.captions, languages);
      const text = stripEmDashes(transcript.text).slice(0, YOUTUBE_LIMITS.maxTranscriptCharacters);

      return json({
        video,
        transcript: {
          text,
          languageCode: transcript.languageCode,
          languageName: stripEmDashes(transcript.languageName),
          isAutomatic: transcript.isAutomatic,
        },
      });
    } catch (error) {
      if (error instanceof YouTubeError) {
        return json(
          { error: error.message, code: error.code, ...error.details },
          error.status,
        );
      }
      const message = error instanceof Error ? error.message : "Erreur inconnue.";
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
