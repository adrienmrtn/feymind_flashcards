/**
 * Client modèle partagé par les Edge Functions de Micabo.
 *
 * fal.ai d'abord (`FAL_KEY`), l'API Gemini en repli (`GEMINI_API_KEY`). Les deux clés
 * vivent dans les secrets du projet Supabase.
 *
 * Le repli existe parce que fal.ai refuse parfois **au niveau du compte** : le 8 septembre
 * 2026, il a répondu 403 sur Gemini Flash comme sur Flash-Lite, pour toutes les requêtes.
 * Un 403 de compte ne se retente pas — c'est ce qui rendait les trois essais inutiles avant
 * d'arriver au repli, et faisait attendre dix secondes de plus pour le même échec.
 */

import { checkCircuit, circuitIsOpen, recordFailure, recordSuccess } from "./circuit.ts";
import { callGemini, readGeminiKey, upstreamReason } from "./gemini.ts";
import { parseModelJSON } from "./json.ts";
import { FalError } from "./model-error.ts";
import { DEFAULT_MODEL, resolveModel } from "./models.ts";

const TEXT_ENDPOINT = "https://fal.run/fal-ai/any-llm";
const VISION_ENDPOINT = "https://fal.run/fal-ai/any-llm/vision";
const FAL_TIMEOUT_MS = 120_000;

/** Pauses entre deux essais fal, en texte seulement : la vision échoue tout de suite. */
export const falRetry = { delaysMs: [2_000, 8_000] };
const FLASH = "google/gemini-2.5-flash";

export { DEFAULT_MODEL };
export { FalError } from "./model-error.ts";

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

/**
 * Le texte du modèle, par le premier fournisseur qui répond.
 *
 * Le repli ne se déclenche que sur une panne du fournisseur — pas sur un refus de contenu
 * ni sur une réponse illisible, qui se reproduiraient à l'identique chez l'autre.
 */
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
      if (geminiKey && worthAnotherProvider(error)) {
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

/**
 * fal, avec deux secondes chances.
 *
 * Le modèle change au deuxième essai : un refus sur Flash-Lite n'est pas forcément un refus
 * sur Flash. Le troisième reprend le modèle demandé, après la pause longue. Un refus qui
 * vient du compte (401, 403, 429) ne passe pas par là : il sort tout de suite pour laisser
 * la main au repli.
 */
async function callFal(options: CallOptions, key: string): Promise<string> {
  const useVision = Array.isArray(options.imageUrls) && options.imageUrls.length > 0;
  const primary = resolveModel(options.model);
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
      if (attempt === models.length - 1 || !worthAnotherFalAttempt(lastError)) {
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
    // Le statut seul ne dit pas si c'est le compte, le modèle ou le débit. Le 8 septembre,
    // les 403 n'ont laissé que leur nombre dans les journaux, et il a fallu deviner.
    console.error(JSON.stringify({
      fal: "http_error",
      status: response.status,
      model,
      upstream: upstreamReason(raw),
    }));
    throw new FalError(
      "L'écriture a échoué. Réessaie, le document n'a rien perdu.",
      502,
      response.status,
    );
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

/**
 * Est-ce que retenter **le même fournisseur** peut donner autre chose ?
 *
 * Non pour 401, 403 et 429 : la clé, le compte ou le débit ne changeront pas en huit
 * secondes. C'est le cas du 8 septembre — fal refusait tout en 403, et les deux essais
 * supplémentaires n'ont fait qu'ajouter dix secondes avant le même repli.
 */
function worthAnotherFalAttempt(error: FalError): boolean {
  const upstream = error.upstreamStatus;
  if (upstream === 401 || upstream === 403 || upstream === 429) return false;
  // 504 : deux minutes déjà attendues, un second tour ferait rater le délai du client.
  return error.status === 502 || error.status === 503;
}

/**
 * Est-ce que **l'autre fournisseur** a une chance ?
 *
 * Oui pour une panne ou un refus de compte, non pour un dépassement de délai : Gemini
 * mettrait aussi deux minutes, et le client a déjà raccroché.
 */
function worthAnotherProvider(error: unknown): boolean {
  if (!(error instanceof FalError)) return true;
  if (error.status === 504) return false;
  return error.status >= 500;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
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
