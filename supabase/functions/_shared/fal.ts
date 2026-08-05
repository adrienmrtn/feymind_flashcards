/**
 * Client fal.ai partagé par les Edge Functions de Feymind.
 * La clé reste côté serveur, dans le secret `FAL_KEY` du projet Supabase.
 */

const TEXT_ENDPOINT = "https://fal.run/fal-ai/any-llm";
const VISION_ENDPOINT = "https://fal.run/fal-ai/any-llm/vision";

export const DEFAULT_MODEL = "google/gemini-flash-1.5";

export const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export class FalError extends Error {
  readonly status: number;

  constructor(message: string, status = 502) {
    super(message);
    this.status = status;
  }
}

export interface CallOptions {
  prompt: string;
  systemPrompt?: string;
  model?: string;
  imageUrls?: string[];
  temperature?: number;
  maxTokens?: number;
}

export async function callModel(options: CallOptions): Promise<string> {
  const key = Deno.env.get("FAL_KEY");
  if (!key) {
    throw new FalError(
      "Le secret FAL_KEY est absent du projet Supabase. Ajoutez-le dans Edge Functions, Secrets.",
      500,
    );
  }

  const useVision = Array.isArray(options.imageUrls) && options.imageUrls.length > 0;
  const body: Record<string, unknown> = {
    model: options.model || DEFAULT_MODEL,
    prompt: options.prompt,
    priority: "throughput",
    reasoning: false,
  };

  if (options.systemPrompt) body.system_prompt = options.systemPrompt;
  if (typeof options.temperature === "number") body.temperature = options.temperature;
  if (typeof options.maxTokens === "number") body.max_tokens = options.maxTokens;
  if (useVision) body.image_urls = options.imageUrls;

  const response = await fetch(useVision ? VISION_ENDPOINT : TEXT_ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Key ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const raw = await response.text();

  if (!response.ok) {
    throw new FalError(`fal.ai a répondu ${response.status} : ${raw.slice(0, 400)}`, 502);
  }

  let parsed: { output?: string; error?: string };
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new FalError("Réponse illisible de fal.ai.", 502);
  }

  if (parsed.error) throw new FalError(parsed.error, 502);
  if (!parsed.output) throw new FalError("fal.ai n'a renvoyé aucun contenu.", 502);

  return parsed.output;
}

/** Extrait le premier objet ou tableau JSON d'une réponse, même entourée de texte ou de balises. */
export function extractJSON<T>(output: string): T {
  let text = output.trim();

  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced) text = fenced[1].trim();

  const firstBrace = text.indexOf("{");
  const firstBracket = text.indexOf("[");
  const start = firstBrace === -1
    ? firstBracket
    : firstBracket === -1
    ? firstBrace
    : Math.min(firstBrace, firstBracket);

  if (start === -1) throw new FalError("Le modèle n'a pas renvoyé de JSON.", 502);

  const opening = text[start];
  const closing = opening === "{" ? "}" : "]";
  const end = text.lastIndexOf(closing);
  if (end <= start) throw new FalError("JSON incomplet renvoyé par le modèle.", 502);

  const candidate = text.slice(start, end + 1);
  try {
    return JSON.parse(candidate) as T;
  } catch (error) {
    throw new FalError(`JSON invalide renvoyé par le modèle : ${(error as Error).message}`, 502);
  }
}

/** Retire les tirets cadratins, bannis de tous les contenus Feymind. */
export function stripEmDashes(value: string): string {
  return value
    .replace(/\s+[—–―]\s+/g, ", ")
    .replace(/[—–―]/g, "-");
}

export function deepStripEmDashes<T>(value: T): T {
  if (typeof value === "string") return stripEmDashes(value) as unknown as T;
  if (Array.isArray(value)) return value.map(deepStripEmDashes) as unknown as T;
  if (value && typeof value === "object") {
    const result: Record<string, unknown> = {};
    for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
      result[key] = deepStripEmDashes(item);
    }
    return result as unknown as T;
  }
  return value;
}

export function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

export function errorResponse(error: unknown): Response {
  const status = error instanceof FalError ? error.status : 500;
  const message = error instanceof Error ? error.message : "Erreur inconnue.";
  return jsonResponse({ error: message }, status);
}
