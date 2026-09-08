/**
 * Client modèle partagé par les Edge Functions de Micabo.
 * fal.ai d'abord (`FAL_KEY`), Gemini directe si ça casse (`GEMINI_API_KEY`).
 * Les deux clés restent dans les secrets du projet Supabase.
 */

import { checkCircuit, circuitIsOpen, recordFailure, recordSuccess } from "./circuit.ts";
import { parseModelJSON } from "./json.ts";
import { FalError } from "./model-error.ts";
import { callGemini, readGeminiKey } from "./gemini.ts";
import { DEFAULT_MODEL, resolveModel } from "./models.ts";

export { FalError } from "./model-error.ts";

const TEXT_ENDPOINT = "https://fal.run/fal-ai/any-llm";
const VISION_ENDPOINT = "https://fal.run/fal-ai/any-llm/vision";
const FAL_TIMEOUT_MS = 120_000;
/** Pauses entre essais Fal (texte seulement). La vision échoue tout de suite. */
export const falRetry = { delaysMs: [2_000, 8_000] };
const FLASH = "google/gemini-2.5-flash";

export { DEFAULT_MODEL };

export const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export interface CallOptions {
  prompt: string;
  systemPrompt?: string;
  model?: string;
  imageUrls?: string[];
  temperature?: number;
  maxTokens?: number;
}

export async function callModel(options: CallOptions): Promise<string> {
  const falKey = Deno.env.get("FAL_KEY")?.trim() ?? "";
  const geminiKey = readGeminiKey();
  if (!falKey && !geminiKey) {
    throw new FalError("Configuration serveur incomplète.", 500);
  }

  if (falKey && !circuitIsOpen()) {
    try {
      return await callFal(options, falKey);
    } catch (error) {
      if (geminiKey && isRetryable(error)) {
        const status = error instanceof FalError ? error.status : 502;
        console.error(JSON.stringify({ fal: "fallback_gemini", status }));
        return await callGemini(options, geminiKey);
      }
      throw error;
    }
  }

  if (geminiKey) {
    if (falKey) console.error(JSON.stringify({ fal: "circuit_open_gemini" }));
    return await callGemini(options, geminiKey);
  }

  checkCircuit();
  throw new FalError("Configuration serveur incomplète.", 500);
}

async function callFal(options: CallOptions, key: string): Promise<string> {
  const useVision = Array.isArray(options.imageUrls) && options.imageUrls.length > 0;
  const primary = resolveModel(options.model);
  // Un 403 lite n'est pas forcément un 403 Flash : on change de modèle
  // au deuxième essai, puis on reprend le défaut après la pause longue.
  const models = useVision ? [primary] : [primary, FLASH, primary];
  const delays = useVision ? [] : falRetry.delaysMs;

  let lastError: FalError | null = null;
  for (let attempt = 0; attempt < models.length; attempt += 1) {
    const model = models[attempt]!;
    if (attempt > 0) {
      const wait = delays[attempt - 1] ?? 0;
      if (wait > 0) await sleep(wait);
      console.error(JSON.stringify({ fal: "retry", attempt: attempt + 1, model }));
    }
    try {
      const output = await callFalOnce(options, key, model, useVision);
      recordSuccess();
      return output;
    } catch (error) {
      lastError = error instanceof FalError
        ? error
        : new FalError("L'écriture a échoué. Réessaie, le document n'a rien perdu.", 502);
      const retry = !useVision && attempt < models.length - 1 && isTransientFal(lastError);
      if (!retry) {
        recordFailure();
        throw lastError;
      }
    }
  }

  recordFailure();
  throw lastError ?? new FalError("L'écriture a échoué. Réessaie, le document n'a rien perdu.", 502);
}

async function callFalOnce(
  options: CallOptions,
  key: string,
  model: string,
  useVision: boolean,
): Promise<string> {
  const body: Record<string, unknown> = {
    model,
    prompt: options.prompt,
    priority: "throughput",
    reasoning: false,
  };

  if (options.systemPrompt) body.system_prompt = options.systemPrompt;
  if (typeof options.temperature === "number") body.temperature = options.temperature;
  if (typeof options.maxTokens === "number") body.max_tokens = options.maxTokens;
  if (useVision) body.image_urls = options.imageUrls;

  let response: Response;
  try {
    response = await fetch(useVision ? VISION_ENDPOINT : TEXT_ENDPOINT, {
      method: "POST",
      headers: {
        "Authorization": `Key ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(FAL_TIMEOUT_MS),
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "TimeoutError") {
      throw new FalError("Le modèle a mis trop longtemps à répondre.", 504);
    }
    throw new FalError("Le modèle est injoignable.", 502);
  }

  const raw = await response.text();

  if (!response.ok) {
    console.error(JSON.stringify({ fal: "http_error", status: response.status, model }));
    throw new FalError("L'écriture a échoué. Réessaie, le document n'a rien perdu.", 502);
  }

  let parsed: { output?: string; error?: string };
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new FalError("Réponse illisible de fal.ai.", 502);
  }

  if (parsed.error) {
    console.error(JSON.stringify({ fal: "model_error", model }));
    throw new FalError("L'écriture a échoué. Réessaie, le document n'a rien perdu.", 502);
  }
  if (!parsed.output) throw new FalError("Le modèle n'a renvoyé aucun contenu.", 502);

  return parsed.output;
}

function isTransientFal(error: FalError): boolean {
  // 504 : on a déjà attendu deux minutes, un second tour ne ferait que
  // rater le timeout client. 403 / 429 / 502 : Fal a dit non tout de suite.
  return error.status === 502 || error.status === 503;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isRetryable(error: unknown): boolean {
  if (!(error instanceof FalError)) return true;
  return error.status >= 500;
}

/** Extrait le premier objet ou tableau JSON d'une réponse, même entourée de texte ou de balises. */
export function extractJSON<T>(output: string): T {
  try {
    return parseModelJSON<T>(output);
  } catch (error) {
    const detail = error instanceof Error ? error.message : "";
    if (detail.includes("n'a pas renvoyé de JSON")) {
      throw new FalError("Le modèle n'a pas renvoyé de JSON.", 502);
    }
    throw new FalError(
      "L'écriture de la fiche a échoué. Réessaie, le document n'a rien perdu.",
      502,
    );
  }
}

/** Retire les tirets cadratins, bannis de tous les contenus Micabo. */
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

/**
 * Le refus, dans les mots de celui qui refuse.
 *
 * Le statut est lu sur l'erreur elle-même, et non sur son type : `FalError` n'est plus la seule à
 * en porter un — `CallerError` refuse en 401 ou en 429, et un plafond atteint rendu en 500 serait
 * lu comme une panne par l'app comme par le site.
 */
export function errorResponse(error: unknown): Response {
  const status = error && typeof (error as { status?: unknown }).status === "number"
    ? (error as { status: number }).status
    : 500;
  const message = error instanceof Error ? error.message : "Erreur inconnue.";
  return jsonResponse({ error: message }, status);
}
