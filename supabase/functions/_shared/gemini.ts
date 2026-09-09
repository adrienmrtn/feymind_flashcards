/**
 * Repli quand fal.ai refuse : l'API Gemini, sans intermédiaire.
 *
 * La clé vit dans le secret `GEMINI_API_KEY` du projet Supabase
 * (Edge Functions → Secrets). Le site Vercel n'en a pas besoin.
 */

import { FalError } from "./model-error.ts";
import { resolveModel } from "./models.ts";

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

export function readGeminiKey(): string {
  return Deno.env.get("GEMINI_API_KEY")?.trim() ?? "";
}

export async function callGemini(options: {
  prompt: string;
  systemPrompt?: string;
  model?: string;
  imageUrls?: string[];
  temperature?: number;
  maxTokens?: number;
}, key: string): Promise<string> {
  const model = resolveGeminiModel(options.model);
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
      throw new FalError("Le modèle a mis trop longtemps à répondre.", 504);
    }
    throw new FalError("Le modèle est injoignable.", 502);
  }

  const raw = await response.text();
  if (!response.ok) {
    // Le statut seul ne dit pas si c'est la clé, le modèle ou le quota. Sans le
    // message amont, le 404 des modèles numérotés a coûté une journée d'enquête.
    console.error(JSON.stringify({
      gemini: "http_error",
      status: response.status,
      model,
      upstream: upstreamReason(raw),
    }));
    throw new FalError("L'écriture a échoué. Réessaie, le document n'a rien perdu.", 502);
  }

  let parsed: { choices?: Array<{ message?: { content?: unknown } }> };
  try {
    parsed = JSON.parse(raw) as { choices?: Array<{ message?: { content?: unknown } }> };
  } catch {
    throw new FalError("Réponse illisible de Gemini.", 502);
  }

  const content = flattenContent(parsed.choices?.[0]?.message?.content);
  if (!content) throw new FalError("Le modèle n'a renvoyé aucun contenu.", 502);
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
