/**
 * Lire une vidéo YouTube **par le modèle**, quand les sous-titres sont hors d'atteinte.
 *
 * ## Pourquoi ce module existe
 *
 * Les sous-titres se téléchargent en deux temps : `youtubei/v1/player` rend une URL
 * `timedtext` signée, puis on télécharge cette URL. Le premier temps est fermé à toute
 * IP de datacenter. Mesuré depuis l'exécution edge du projet le 8 septembre 2026 :
 *
 * | source                          | réponse                                  |
 * | ------------------------------- | ---------------------------------------- |
 * | `youtubei/v1/player`, 4 clients | 403, page « Sorry… »                     |
 * | `youtube.com/watch`             | 429                                      |
 * | `api/timedtext` sans signature  | 200, zéro octet                          |
 * | Invidious, 6 instances          | 401, 403, 404                            |
 * | Piped, 2 instances vivantes     | 500 « Sign in to confirm you're not a bot » sauf vidéo déjà en cache |
 *
 * C'est ce qui a produit les 19 refus 422 du 8 septembre : l'aperçu passait — oEmbed rend
 * le titre — mais la transcription trouvait zéro piste et refusait. Les 9 réponses 200 du
 * même jour étaient toutes des aperçus, aucune n'était une transcription.
 *
 * Le navigateur ne sauve pas la mise : `youtubei/v1/player` répond 403 dès qu'un en-tête
 * `Origin` est présent, et ne rend aucun en-tête CORS. Un onglet ne peut donc pas lire la
 * réponse, quelle que soit l'IP.
 *
 * ## Ce que fait ce module
 *
 * Google ne se bloque pas lui-même : l'API Gemini accepte une URL YouTube comme pièce
 * jointe et lit la vidéo depuis l'infrastructure de Google. Aucune IP à cacher, aucun
 * CORS, aucune signature. C'est le seul chemin qui répond depuis une Edge Function.
 *
 * Deux détails coûtent cher si on les rate.
 *
 * **On ne demande pas une transcription mot à mot.** Le modèle répond alors
 * `finishReason: RECITATION` et **rien** : Google refuse de restituer verbatim une œuvre
 * publiée. On demande le contenu enseigné, ce dont la fiche a besoin de toute façon.
 *
 * **On limite le nombre d'images.** Une vidéo est facturée image par image : 19 minutes à
 * la cadence par défaut coûtent 102 000 jetons, contre 35 000 à `VIDEO_FPS`. Une image
 * toutes les cinq secondes suffit à lire un tableau ou une diapositive.
 */

import { readGeminiKey, upstreamReason } from "./gemini.ts";
import { YOUTUBE_LIMITS, YouTubeError } from "./youtube.ts";

const GEMINI_VIDEO = "https://generativelanguage.googleapis.com/v1beta/models";

/** Une image toutes les cinq secondes : assez pour une diapositive, trois fois moins cher. */
const VIDEO_FPS = 0.2;

/** Le modèle rend rarement plus, et un plafond bas couperait une longue vidéo en plein mot. */
const MAX_OUTPUT_TOKENS = 32_768;

/**
 * Le premier suffit presque toujours. Le second existe parce que `-latest` renvoie parfois
 * 503 « high demand » : c'est une file d'attente, pas un refus, et l'autre modèle passe.
 */
const VIDEO_MODELS = ["gemini-flash-lite-latest", "gemini-flash-latest"];

/** Une lecture de 90 minutes tient largement dedans ; au delà c'est l'amont qui a lâché. */
const VIDEO_TIMEOUT_MS = 150_000;

const PROMPT = [
  "Écris le compte rendu complet de cette vidéo, dans la langue parlée dans la vidéo.",
  "",
  "Règles :",
  "- Suis l'ordre de la vidéo, du début à la fin, sans rien sauter.",
  "- Reprends chaque notion : la définition donnée, le raisonnement entier, chaque exemple,",
  "  chaque chiffre, chaque nom propre, chaque formule.",
  "- Reprends ce qui est écrit à l'écran quand cela porte du contenu : formules, schémas",
  "  commentés, listes.",
  "- Écris en paragraphes suivis, comme un cours pris en notes par un étudiant attentif.",
  "  Pas de puces, pas d'horodatage, pas de titre.",
  "- Ne parle ni de la vidéo ni de celui qui parle : écris directement le contenu enseigné.",
  "- Commence par la première notion, sans phrase d'introduction.",
  "- N'invente rien.",
].join("\n");

export interface VideoReading {
  text: string;
  model: string;
}

/** Vrai quand la clé Gemini est posée, donc quand ce repli est disponible. */
export function canReadVideo(): boolean {
  return readGeminiKey().length > 0;
}

/**
 * Le contenu de la vidéo, lu par Gemini.
 *
 * Lève un `YouTubeError` `no_captions` si aucun modèle n'a rendu de texte : côté produit,
 * « on n'a pas pu lire cette vidéo » est la même chose pour l'utilisateur, qu'il n'y ait
 * pas de sous-titres ou que le modèle ait refusé.
 */
export async function readVideoWithGemini(videoId: string): Promise<VideoReading> {
  const key = readGeminiKey();
  if (key.length === 0) {
    throw new YouTubeError("no_captions", "Cette vidéo n'a pas de piste de sous-titres.");
  }

  let lastReason = "";

  for (const model of VIDEO_MODELS) {
    const body = {
      contents: [{
        parts: [
          { text: PROMPT },
          {
            file_data: { file_uri: `https://www.youtube.com/watch?v=${videoId}` },
            video_metadata: {
              fps: VIDEO_FPS,
              end_offset: `${YOUTUBE_LIMITS.maxDurationSeconds}s`,
            },
          },
        ],
      }],
      generationConfig: { temperature: 0.2, maxOutputTokens: MAX_OUTPUT_TOKENS },
    };

    let response: Response;
    try {
      response = await fetch(`${GEMINI_VIDEO}/${model}:generateContent?key=${key}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(VIDEO_TIMEOUT_MS),
      });
    } catch (error) {
      lastReason = error instanceof DOMException && error.name === "TimeoutError"
        ? "timeout"
        : "injoignable";
      continue;
    }

    const raw = await response.text();
    if (!response.ok) {
      lastReason = `${response.status} ${upstreamReason(raw)}`;
      console.error(JSON.stringify({
        youtube: "gemini_http_error",
        status: response.status,
        model,
        upstream: upstreamReason(raw),
      }));
      continue;
    }

    const text = readingText(raw);
    if (text.length >= YOUTUBE_LIMITS.minTranscriptCharacters) {
      return { text: text.slice(0, YOUTUBE_LIMITS.maxTranscriptCharacters), model };
    }

    // `RECITATION` arrive avec un texte vide : Google a coupé plutôt que de citer.
    lastReason = `${finishReason(raw) || "vide"} (${text.length} caractères)`;
    console.error(JSON.stringify({
      youtube: "gemini_trop_court",
      model,
      finishReason: finishReason(raw),
      characters: text.length,
    }));
  }

  throw new YouTubeError(
    "no_captions",
    "Cette vidéo n'a pas pu être lue.",
    422,
    { reason: lastReason.slice(0, 120) },
  );
}

/** Le texte des `parts` de la première réponse, recollé et débarrassé de son préambule. */
export function readingText(raw: string): string {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return "";
  }

  const candidate = asRecord(asArray(asRecord(parsed)?.candidates)[0]);
  const parts = asArray(asRecord(candidate?.content)?.parts);
  const text = parts
    .map((part) => {
      const value = asRecord(part)?.text;
      return typeof value === "string" ? value : "";
    })
    .join("")
    .trim();

  return stripPreamble(text);
}

/** Les mots par lesquels le modèle annonce ce qu'il va rendre. */
const ANNOUNCES = /^(voici|voilà|here (is|are)|ci-dessous|aquí|hier ist|below)\b/i;

/** Ce qu'il annonce : l'artefact, jamais la matière enseignée. */
const NAMES_ARTEFACT =
  /\b(vid[eé]os?|video|compte[ -]rendu|re?transcription|transcript|notes?|r[eé]sum[eé]|summary|account)\b/i;

/**
 * Retire la phrase d'annonce que le modèle place parfois avant le contenu.
 *
 * « Voici le compte rendu complet du contenu de la vidéo. » n'apprend rien à l'étudiant et
 * se retrouverait dans la fiche, puis sur une carte.
 *
 * Les deux conditions comptent. Annoncer ne suffit pas : « Voici pourquoi un réseau
 * apprend : chaque poids se corrige. » commence pareil et enseigne quelque chose. Il faut
 * que la phrase parle de l'artefact — la vidéo, le compte rendu, les notes — pour qu'on
 * sache qu'elle parle du travail et non du sujet.
 */
export function stripPreamble(text: string): string {
  const [first, ...rest] = text.split("\n");
  if (rest.length === 0 || first === undefined) return text;
  const line = first.trim();
  if (line.length > 160) return text;
  if (!ANNOUNCES.test(line) || !NAMES_ARTEFACT.test(line)) return text;
  return rest.join("\n").trim();
}

function finishReason(raw: string): string {
  try {
    const candidate = asRecord(asArray(asRecord(JSON.parse(raw))?.candidates)[0]);
    return typeof candidate?.finishReason === "string" ? candidate.finishReason : "";
  } catch {
    return "";
  }
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}
