/**
 * L'API Gemini, sans intermédiaire : le premier chemin du texte, le repli de la vision.
 *
 * La clé vit dans le secret `GEMINI_API_KEY` du projet Supabase
 * (Edge Functions → Secrets). Le site Vercel n'en a pas besoin.
 */

import { FalError } from "./model-error.ts";
import { resolveModel } from "./models.ts";
import { type ModelUsage, noteUsage, readUsage } from "./usage.ts";

const GEMINI_CHAT = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions";
const GEMINI_TIMEOUT_MS = 120_000;

/**
 * Un alias `-latest`, jamais un numéro de version.
 *
 * Google ferme ses versions numérotées aux clés récentes : le 8 septembre,
 * `gemini-2.5-flash-lite` répondait « no longer available to new users, please
 * update your code to use models/gemini-3.5-flash-lite » en 404. Le repli
 * Gemini échouait donc juste après un refus de fal, et la génération finissait
 * en 502 après avoir épuisé les deux chemins. Les alias suivent les montées de
 * version de Google sans qu'on ait à les rattraper.
 */
export function resolveGeminiModel(requested?: string): string {
  const fal = resolveModel(requested);
  return fal === "google/gemini-2.5-flash" ? "gemini-flash-latest" : "gemini-flash-lite-latest";
}

/** L'autre alias, celui qu'on essaie quand le premier est en panne ou saturé. */
function otherGeminiModel(model: string): string {
  return model === "gemini-flash-latest" ? "gemini-flash-lite-latest" : "gemini-flash-latest";
}

/**
 * Est-ce que l'autre alias a une chance ?
 *
 * Oui sur un 503 « high demand », qui est une file d'attente et non un verdict, et sur un 404
 * ou un 5xx, qui parlent du modèle et pas de la demande. Non sur un 400 — la requête est en
 * cause, elle le restera — ni sur un 401 ou un 403, qui parlent de la clé.
 */
function worthTheOtherModel(status: number): boolean {
  return status === 404 || status === 429 || status >= 500;
}

export function readGeminiKey(): string {
  return Deno.env.get("GEMINI_API_KEY")?.trim() ?? "";
}

/**
 * **La pensée est coupée**, et c'est le point qui a coûté les thèmes du 21 octobre.
 *
 * Les alias `-latest` ont atterri sur la génération 3.5, qui réfléchit avant d'écrire. Sur
 * l'endpoint compatible OpenAI, ces pensées comptent dans `max_tokens` et la réponse en
 * sort tronquée ou en prose : le JSON ne se lit plus, et la fonction rend « Ce thème n'a pas
 * pu s'écrire ». Micabo ne demande que du JSON à remplir : il n'a rien à faire d'un
 * raisonnement. `reasoning_effort: "none"` le dit à Google ; un modèle qui n'accepte pas la
 * consigne répond 400, et l'appel repart une fois sans elle.
 */
export const geminiThinking = { off: { reasoning_effort: "none" } as Record<string, unknown> };

export async function callGemini(options: {
  prompt: string;
  systemPrompt?: string;
  model?: string;
  imageUrls?: string[];
  temperature?: number;
  maxTokens?: number;
  meter?: ModelUsage[];
}, key: string): Promise<string> {
  const first = resolveGeminiModel(options.model);

  try {
    return await callGeminiModel(options, key, first);
  } catch (error) {
    // Un second alias coûte un appel et rattrape le refus le plus fréquent, la file d'attente.
    if (!(error instanceof FalError) || !worthTheOtherModel(error.upstreamStatus ?? 0)) throw error;
    const second = otherGeminiModel(first);
    console.warn(JSON.stringify({ gemini: "autre_modele", model: second }));
    return await callGeminiModel(options, key, second);
  }
}

/** Un modèle, sans pensée ; puis une fois avec, si c'est la consigne qu'il a refusée. */
async function callGeminiModel(
  options: Parameters<typeof callGeminiOnce>[0],
  key: string,
  model: string,
): Promise<string> {
  try {
    return await callGeminiOnce(options, key, model, true);
  } catch (error) {
    if (!(error instanceof FalError) || !refusedThinkingSetting.has(error)) throw error;
    console.warn(JSON.stringify({ gemini: "pensee_non_reglable", model }));
    return await callGeminiOnce(options, key, model, false);
  }
}

/** Les 400 qui parlent de la consigne de pensée, et pas de la demande elle-même. */
const refusedThinkingSetting = new WeakSet<FalError>();

async function callGeminiOnce(options: {
  prompt: string;
  systemPrompt?: string;
  imageUrls?: string[];
  temperature?: number;
  maxTokens?: number;
  meter?: ModelUsage[];
}, key: string, model: string, withoutThinking: boolean): Promise<string> {
  const images = Array.isArray(options.imageUrls) ? options.imageUrls : [];
  const messages: Array<Record<string, unknown>> = [];
  if (options.systemPrompt) {
    messages.push({ role: "system", content: options.systemPrompt });
  }
  messages.push({
    role: "user",
    content: images.length > 0
      ? [
        { type: "text", text: options.prompt },
        ...images.map((url) => ({ type: "image_url", image_url: { url } })),
      ]
      : options.prompt,
  });

  const body: Record<string, unknown> = { model, messages };
  if (typeof options.temperature === "number") body.temperature = options.temperature;
  if (typeof options.maxTokens === "number") body.max_tokens = options.maxTokens;
  if (withoutThinking) Object.assign(body, geminiThinking.off);

  let response: Response;
  try {
    response = await fetch(GEMINI_CHAT, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(GEMINI_TIMEOUT_MS),
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "TimeoutError") {
      throw new FalError("Le modèle a mis trop longtemps à répondre.", 504, undefined, "timeout");
    }
    throw new FalError("Le modèle est injoignable.", 502, undefined, "provider");
  }

  const raw = await response.text();
  if (!response.ok) {
    // Le statut seul ne dit pas si c'est la clé, le modèle ou le quota. Sans le
    // message amont, le 404 des modèles numérotés a coûté une journée d'enquête.
    const upstream = upstreamReason(raw);
    console.error(JSON.stringify({
      gemini: "http_error",
      status: response.status,
      model,
      upstream,
    }));
    const error = new FalError(
      "L'écriture a échoué. Réessaie, le document n'a rien perdu.",
      502,
      response.status,
      "provider",
    );
    // Tout 400 reçu avec la consigne de pensée vaut un second essai sans elle, quel que soit
    // le mot que Google choisit pour le dire : la seule chose que cet appel ait de différent
    // d'avant le 23 octobre, c'est cette consigne. Un 400 qui revient sans elle est le nôtre.
    if (withoutThinking && response.status === 400) {
      refusedThinkingSetting.add(error);
    }
    throw error;
  }

  let parsed: {
    choices?: Array<{ message?: { content?: unknown }; finish_reason?: unknown }>;
  };
  try {
    parsed = JSON.parse(raw) as typeof parsed;
  } catch {
    throw new FalError("Réponse illisible de Gemini.", 502, undefined, "provider");
  }

  // Le `model` que Google renvoie est la seule façon de savoir sur quelle génération l'alias
  // `-latest` a atterri, et donc à quel tarif ce repli se facture.
  const usage = readUsage(parsed, "gemini", model);
  noteUsage(usage, options.meter);

  const choice = parsed.choices?.[0];
  // Une réponse coupée par `max_tokens` finit en JSON invalide deux appels plus loin, sous
  // une phrase qui ne dit pas d'où elle vient. Le dire ici, avec ce que la sortie a coûté.
  if (choice?.finish_reason === "length") {
    console.warn(JSON.stringify({
      gemini: "tronque",
      model: usage.served || model,
      output: usage.output,
      max_tokens: options.maxTokens ?? null,
    }));
  }

  const content = flattenContent(choice?.message?.content);
  if (!content) throw new FalError("Le modèle n'a renvoyé aucun contenu.", 502, undefined, "provider");
  return content;
}

/** Le message du refus amont, court et sans clé : les journaux sont lisibles par l'équipe. */
export function upstreamReason(raw: string): string {
  try {
    const parsed = JSON.parse(raw);
    const error = Array.isArray(parsed) ? parsed[0]?.error : parsed?.error;
    const message = error?.message ?? parsed?.detail ?? parsed?.message;
    if (typeof message === "string") return message.slice(0, 200);
  } catch {
    // Un corps non JSON reste utile : c'est souvent une page d'erreur nommée.
  }
  return raw.replace(/\s+/g, " ").trim().slice(0, 200);
}

export function flattenContent(content: unknown): string {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === "string") return part;
        if (part && typeof part === "object" && typeof (part as { text?: unknown }).text === "string") {
          return (part as { text: string }).text;
        }
        return "";
      })
      .join("");
  }
  return "";
}
