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

export function resolveGeminiModel(requested?: string): string {
  const fal = resolveModel(requested);
  if (fal === "google/gemini-2.5-flash") return "gemini-2.5-flash";
  if (fal === "google/gemini-2.0-flash-001") return "gemini-2.0-flash";
  return "gemini-2.5-flash-lite";
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
    console.error(JSON.stringify({ gemini: "http_error", status: response.status, model }));
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
