import {
  authorize,
  type Caller,
  CallerError,
  consumeQuota,
  requireAccount,
  withCors,
} from "../_shared/caller.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { freeLessonAvailable, hasPro } from "../_shared/pro.ts";
import {
  extractVideoId,
  fetchVideoMetadata,
  YOUTUBE_LIMITS,
  YouTubeError,
} from "../_shared/youtube.ts";
import {
  canReadVideo,
  readTranscript,
  VIDEO_FREE_CEILING,
  VIDEO_PRO_CEILING,
} from "../_shared/youtube-video.ts";

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
 * La lecture par Gemini, elle, est décomptée (`VIDEO_FREE_CEILING`, `VIDEO_PRO_CEILING`) :
 * c'est l'appel le plus cher de Micabo.
 */
Deno.serve((request: Request) =>
  withCors(request, async () => {
    try {
      // Cette fonction va chercher n'importe quelle URL : laissée ouverte, c'est un relais
      // anonyme. Elle passe donc le même contrôle d'identité. L'aperçu et les sous-titres ne
      // coûtent rien et ne décomptent rien ; seule la lecture par Gemini décompte, plus bas.
      const caller = await authorize(request, "youtube-transcript", { meter: false });
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
        // Sans piste de sous-titres, l'aperçu ne suffit plus à décider : c'est cette
        // clé qui dit si le modèle peut regarder la vidéo. L'écran annonce alors une
        // lecture plus longue au lieu d'un refus.
        canWatch: canReadVideo(),
      };

      if (body.metadataOnly === true) {
        return json({ video });
      }

      const transcript = await readTranscript(
        videoId,
        metadata.captions,
        languages,
        () => admitVideoReading(caller),
      );
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
      // Le plafond des lectures de vidéo : un refus attendu, avec sa phrase, pas une panne.
      if (error instanceof CallerError && error.status === 429) {
        return json({ error: error.message, code: "quota" }, 429);
      }
      if (error instanceof VideoImportProError) {
        return json({ error: error.message, code: "import_pro" }, 402);
      }
      // Un refus d'identité (401) ou une porte muette (503) gardent leur statut : ce ne sont
      // pas des pannes de la fonction.
      if (error instanceof CallerError) {
        return json({ error: error.message }, error.status);
      }
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

/** Un compte gratuit dont la leçon offerte a servi : lire une vidéo par le modèle est Pro. */
class VideoImportProError extends Error {
  constructor() {
    super("Importer une vidéo, c'est avec Micabo Pro.");
  }
}

/**
 * **La porte de la lecture par le modèle**, juste avant l'appel qui coûte.
 *
 * Le décompte seul (`VIDEO_FREE_CEILING`) laissait un compte gratuit lire deux vidéos par
 * jour, tous les jours, alors que l'import est Pro. La règle est maintenant celle de
 * `generate-lesson` : un abonné lit, un compte gratuit lit **tant que sa leçon offerte reste
 * à prendre** — c'est le parcours d'accueil, qui peut partir d'une vidéo avant toute offre —,
 * et la clé publiable ne lit jamais : c'est l'appel le plus cher de Micabo, et le budget
 * commun des versions anciennes ne le couvre pas. Les sous-titres, eux, ne coûtent rien et
 * ne passent pas par ici.
 */
async function admitVideoReading(caller: Caller): Promise<void> {
  requireAccount(caller);
  if (!(await hasPro(caller.userId)) && !(await freeLessonAvailable(caller.userId))) {
    throw new VideoImportProError();
  }
  await consumeQuota(caller, "youtube-video", 1, VIDEO_FREE_CEILING, VIDEO_PRO_CEILING);
}

function stripEmDashes(value: string): string {
  return value.replace(/\s+[—–―]\s+/g, ", ").replace(/[—–―]/g, "-");
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
