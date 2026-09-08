/**
 * Client modèle partagé par les Edge Functions de Micabo.
 * fal.ai d'abord (`FAL_KEY`), Replicate si ça casse (`REPLICATE_API_TOKEN`).
 * Les deux clés restent dans les secrets du projet Supabase.
 */

import { checkCircuit, circuitIsOpen, recordFailure, recordSuccess } from "./circuit.ts";
import { parseModelJSON } from "./json.ts";
import { FalError } from "./model-error.ts";
import { DEFAULT_MODEL, resolveModel } from "./models.ts";
import { callReplicate } from "./replicate.ts";

export { FalError } from "./model-error.ts";

const TEXT_ENDPOINT = "https://fal.run/fal-ai/any-llm";
const VISION_ENDPOINT = "https://fal.run/fal-ai/any-llm/vision";
const FAL_TIMEOUT_MS = 120_000;

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
  const replicateKey = Deno.env.get("REPLICATE_API_TOKEN")?.trim() ?? "";
  if (!falKey && !replicateKey) {
    throw new FalError("Configuration serveur incomplète.", 500);
  }

  if (falKey && !circuitIsOpen()) {
    try {
      return await callFal(options, falKey);
    } catch (error) {
      if (replicateKey && isRetryable(error)) {
        console.error(JSON.stringify({ fal: "fallback_replicate" }));
        return await callReplicate(options, replicateKey);
      }
      throw error;
    }
  }

  if (replicateKey) {
    if (falKey) console.error(JSON.stringify({ fal: "circuit_open_replicate" }));
    return await callReplicate(options, replicateKey);
  }

  checkCircuit();
  throw new FalError("Configuration serveur incomplète.", 500);
}

async function callFal(options: CallOptions, key: string): Promise<string> {
  const model = resolveModel(options.model);
  const useVision = Array.isArray(options.imageUrls) && options.imageUrls.length > 0;
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
    recordFailure();
    if (error instanceof DOMException && error.name === "TimeoutError") {
      throw new FalError("Le modèle a mis trop longtemps à répondre.", 504);
    }
    throw new FalError("Le modèle est injoignable.", 502);
  }

  const raw = await response.text();

  if (!response.ok) {
    recordFailure();
    console.error(JSON.stringify({ fal: "http_error", status: response.status, model }));
    throw new FalError("L'écriture a échoué. Réessaie, le document n'a rien perdu.", 502);
  }

  recordSuccess();

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
