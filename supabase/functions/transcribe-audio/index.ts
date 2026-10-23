import {
  authorize,
  CallerError,
  consumeQuota,
  requireAccount,
  withCors,
} from "../_shared/caller.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { attemptTimeout, deadlineIn } from "../_shared/deadline.ts";
import { errorResponse, jsonResponse } from "../_shared/fal.ts";
import { readGeminiKey, upstreamReason } from "../_shared/gemini.ts";
import { hasPro } from "../_shared/pro.ts";

interface RequestBody {
  /** L'enregistrement, en base64, sans préfixe `data:`. */
  audio?: string;
  /** Le type du fichier : `audio/mp4` pour un enregistrement de l'app Android. */
  mimeType?: string;
  /** La langue du cours, s'il faut aider le modèle (`fr`, `en`…). */
  language?: string;
}

/**
 * **Un cours enregistré, mis en texte.**
 *
 * L'iPhone transcrit sur le téléphone (`SFSpeechRecognizer`). Android n'a pas d'équivalent
 * fiable pour un fichier d'une heure : l'app envoie donc l'enregistrement, compressé (AAC mono
 * à bas débit, une heure et demie tient sous la limite), et Gemini le transcrit, avec la clé
 * déjà utilisée pour regarder les vidéos YouTube (`youtube-video.ts`). Le texte repart dans le
 * chemin de n'importe quel support : `generate-lesson`, source `audio`.
 *
 * Importer un enregistrement est Pro, comme tout import : la porte est tenue ici, avant
 * l'appel au modèle, parce que c'est lui qui coûte. Rien n'est gardé.
 */
Deno.serve((request: Request) =>
  withCors(request, async () => {
    // L'échéance de la requête, posée à son entrée : voir `_shared/deadline.ts`.
    const deadline = deadlineIn();
    try {
      const caller = await authorize(request, "transcribe-audio", { meter: false });
      // Une transcription est une étape lourde : jamais sur la clé publiable. Le refus vient
      // avant le décompte, qui n'aurait sinon rien d'autre à faire que vider le budget commun.
      requireAccount(caller);
      await consumeQuota(caller, "transcribe-audio", 1, 4, 40);
      if (!(await hasPro(caller.userId))) {
        return jsonResponse({ error: "Importer un enregistrement, c'est avec Pro.", code: "import_pro" }, 402);
      }

      const body = (await request.json()) as RequestBody;
      const audio = typeof body.audio === "string" ? body.audio.replace(/\s+/g, "") : "";
      const mimeType = typeof body.mimeType === "string" && ALLOWED_TYPES.has(body.mimeType)
        ? body.mimeType
        : "audio/mp4";
      if (audio.length < 1_000) {
        return jsonResponse({ error: "L'enregistrement est vide.", code: "too_short" }, 400);
      }
      if (audio.length > MAX_AUDIO_CHARS) {
        return jsonResponse({ error: "L'enregistrement est trop long.", code: "too_long" }, 413);
      }

      const text = await transcribe(audio, mimeType, languageName(body.language), deadline);
      if (text.length < MIN_CHARACTERS) {
        return jsonResponse({ error: "Rien de lisible dans cet enregistrement.", code: "too_short" }, 422);
      }
      return jsonResponse({ transcript: { text: text.slice(0, MAX_TRANSCRIPT) } });
    } catch (error) {
      return errorResponse(error);
    }
  })
);

/** Gemini accepte vingt mégaoctets par requête : la marge couvre le reste du corps. */
const MAX_AUDIO_CHARS = 25_000_000;
const MAX_TRANSCRIPT = 120_000;
const MIN_CHARACTERS = 40;
const MODELS = ["gemini-flash-lite-latest", "gemini-flash-latest"];
const GEMINI = "https://generativelanguage.googleapis.com/v1beta/models";
/**
 * Le délai d'un essai, **borné par l'échéance de la requête** (`deadline.ts`). Seul, il
 * faisait 150 secondes par modèle, deux modèles : trois cents secondes au pire, pour une
 * fonction que la plateforme coupe bien avant. Le second modèle n'est tenté que s'il reste
 * du temps.
 */
const ATTEMPT_MS = 150_000;
/** En deçà, le second modèle n'aurait pas le temps de transcrire quoi que ce soit. */
const SECOND_ATTEMPT_MIN_MS = 25_000;

const ALLOWED_TYPES = new Set([
  "audio/mp4",
  "audio/m4a",
  "audio/x-m4a",
  "audio/aac",
  "audio/mpeg",
  "audio/mp3",
  "audio/wav",
  "audio/x-wav",
  "audio/ogg",
  "audio/webm",
  "audio/flac",
  "audio/3gpp",
  "audio/amr",
]);

const LANGUAGES: Record<string, string> = {
  fr: "français",
  en: "anglais",
  de: "allemand",
  es: "espagnol",
  it: "italien",
  pt: "portugais",
  nl: "néerlandais",
  tr: "turc",
  pl: "polonais",
  ro: "roumain",
  ar: "arabe",
  ru: "russe",
};

function languageName(code: unknown): string | null {
  if (typeof code !== "string") return null;
  return LANGUAGES[code.slice(0, 2).toLowerCase()] ?? null;
}

/**
 * La transcription. **Fidèle, pas résumée** : c'est le cours de l'élève, enregistré par lui ;
 * le modèle ne répète pas une œuvre publiée, il met en texte une classe. Les hésitations et
 * les bruits partent, les exemples et les chiffres restent.
 */
async function transcribe(
  audio: string,
  mimeType: string,
  language: string | null,
  deadline: number,
): Promise<string> {
  const key = readGeminiKey();
  if (!key) throw new CallerError("La transcription n'est pas configurée.", 503);
  const prompt = [
    "Voici l'enregistrement d'un cours, fait par un élève pour réviser.",
    "Transcris fidèlement ce qui est enseigné, dans la langue parlée" +
    (language ? ` (probablement le ${language})` : "") + ".",
    "Retire les hésitations, les répétitions et ce qui n'est pas le cours (bruits, discussions à côté).",
    "Garde tous les exemples, les définitions, les dates, les chiffres et les formules.",
    "Va à la ligne à chaque changement d'idée. Rends uniquement le texte, sans titre ni commentaire.",
  ].join(" ");

  let lastReason = "";
  for (const [rank, model] of MODELS.entries()) {
    const timeout = attemptTimeout(ATTEMPT_MS, deadline);
    if (timeout === null || (rank > 0 && timeout < SECOND_ATTEMPT_MIN_MS)) {
      lastReason = lastReason || "timeout";
      break;
    }
    let response: Response;
    try {
      response = await fetch(`${GEMINI}/${model}:generateContent?key=${key}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }, { inline_data: { mime_type: mimeType, data: audio } }] }],
          generationConfig: { temperature: 0.1, maxOutputTokens: 32_768 },
        }),
        signal: AbortSignal.timeout(timeout),
      });
    } catch (error) {
      lastReason = error instanceof DOMException && error.name === "TimeoutError" ? "timeout" : "injoignable";
      continue;
    }
    const raw = await response.text();
    if (!response.ok) {
      lastReason = `${response.status} ${upstreamReason(raw)}`;
      console.error(JSON.stringify({ transcription: "gemini_http_error", status: response.status, model }));
      continue;
    }
    const text = partsText(raw);
    if (text.length >= MIN_CHARACTERS) return text;
    lastReason = `vide (${text.length} caractères)`;
  }
  console.error(JSON.stringify({ transcription: "echec", raison: lastReason.slice(0, 120) }));
  throw new CallerError("L'enregistrement n'a pas pu être transcrit. Réessaie.", 502);
}

/** Le texte des `parts` de la première réponse. */
function partsText(raw: string): string {
  try {
    const parsed = JSON.parse(raw) as { candidates?: { content?: { parts?: { text?: unknown }[] } }[] };
    return (parsed.candidates?.[0]?.content?.parts ?? [])
      .map((part) => (typeof part.text === "string" ? part.text : ""))
      .join("")
      .trim();
  } catch {
    return "";
  }
}
