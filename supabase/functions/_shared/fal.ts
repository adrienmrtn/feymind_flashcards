/**
 * Client modèle partagé par les Edge Functions de Micabo.
 *
 * **L'API Gemini d'abord pour le texte, fal.ai en repli** ; fal d'abord pour la vision, Gemini
 * en repli. Les deux clés vivent dans les secrets du projet Supabase (`GEMINI_API_KEY`,
 * `FAL_KEY`).
 *
 * L'ordre s'est inversé le 23 octobre 2026, et voici pourquoi. fal servait Gemini par son
 * endpoint `any-llm`, que fal a marqué déprécié et dont la liste s'arrête à Gemini 2.5 ; or
 * Google ferme ses versions numérotées, et répond 404 « gemini-2.5-flash is no longer
 * available » derrière fal, par intermittence depuis le 20 octobre. Le même jour, le compte
 * fal s'est trouvé à sec (403 « User is locked. Reason: TOP_UP ») : quarante-cinq thèmes de
 * leçon ont fini en 502 en une journée. L'API Gemini directe, elle, suit les alias `-latest`
 * de Google et ne dépend d'aucun intermédiaire. fal reste derrière, pour une panne ou un
 * quota chez Google, avec une échelle qui change de **famille** de modèle quand Google
 * refuse : un modèle retiré ne se rattrape pas en le redemandant.
 *
 * La vision garde fal devant : c'est le chemin éprouvé pour les photos de cours, et Gemini
 * direct le double déjà.
 */

import { checkCircuit, circuitIsOpen, recordFailure, recordSuccess } from "./circuit.ts";
import { attemptTimeout, MIN_ATTEMPT_MS, remainingMs } from "./deadline.ts";
import { callGemini, readGeminiKey, upstreamReason } from "./gemini.ts";
import { describeModelOutput, parseModelJSON } from "./json.ts";
import { FalError } from "./model-error.ts";
import { DEFAULT_MODEL, resolveModel } from "./models.ts";
import { type ModelUsage, noteUsage, readUsage } from "./usage.ts";

const TEXT_ENDPOINT = "https://fal.run/fal-ai/any-llm";
const VISION_ENDPOINT = "https://fal.run/fal-ai/any-llm/vision";
const FAL_TIMEOUT_MS = 120_000;

/** Pauses entre deux essais fal, en texte seulement : la vision échoue tout de suite. */
export const falRetry = { delaysMs: [2_000, 8_000] };
const FLASH = "google/gemini-2.5-flash";
/**
 * Le barreau d'une autre famille. Quand Google, derrière fal, dit qu'un modèle n'existe
 * plus, redemander un autre Gemini à fal rend le même 404 : il faut changer de fournisseur
 * amont, pas de taille.
 */
export const OTHER_FAMILY = "openai/gpt-5-mini";

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
  /**
   * Où déposer ce que chaque appel a consommé.
   *
   * Le tableau s'accumule : une fonction qui écrit une fiche en trois appels - la passe
   * visuelle, l'écriture, le marquage - en ressort trois lignes, et sait laquelle a coûté
   * quoi. Facultatif, et les journaux reçoivent la ligne dans tous les cas.
   */
  meter?: ModelUsage[];
  /**
   * L'échéance de la requête entière (`deadline.ts`), en millisecondes depuis l'époque.
   * Chaque essai, chaque repli et chaque pause la respecte : une fonction qui enchaîne
   * plusieurs appels échoue elle-même avant que la plateforme ne la tue.
   */
  deadline?: number;
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
    throw new FalError("Configuration serveur incomplète.", 500, undefined, "config");
  }

  const useVision = Array.isArray(options.imageUrls) && options.imageUrls.length > 0;
  const falReady = falKey.length > 0 && !circuitIsOpen();

  // Le texte : Gemini direct, puis fal.
  if (!useVision && geminiKey) {
    try {
      return await callGemini(options, geminiKey);
    } catch (error) {
      if (falReady && worthAnotherProvider(error)) {
        const status = error instanceof FalError ? error.upstreamStatus ?? error.status : 502;
        console.warn(JSON.stringify({ gemini: "fallback_fal", status }));
        return await callFal(options, falKey);
      }
      throw error;
    }
  }

  // La vision, ou un texte sans clé Gemini : fal, puis Gemini.
  if (falReady) {
    try {
      return await callFal(options, falKey);
    } catch (error) {
      if (geminiKey && worthAnotherProvider(error)) {
        const status = error instanceof FalError ? error.status : 502;
        console.warn(JSON.stringify({ fal: "fallback_gemini", status }));
        return await callGemini(options, geminiKey);
      }
      throw error;
    }
  }

  if (geminiKey) {
    if (falKey) console.warn(JSON.stringify({ fal: "circuit_open_gemini" }));
    return await callGemini(options, geminiKey);
  }

  checkCircuit();
  throw new FalError("Configuration serveur incomplète.", 500, undefined, "config");
}

/**
 * L'échelle des modèles chez fal, sans doublon.
 *
 * Avant, elle était `[demandé, Flash, demandé]` : avec Flash demandé, c'était trois fois le
 * même modèle, et un modèle retiré par Google l'était trois fois. Un barreau d'une autre
 * famille termine l'échelle : c'est le seul qui ait une chance quand Google a fermé la porte.
 */
export function falLadder(primary: string, useVision: boolean): string[] {
  if (useVision) return [primary];
  const rungs = [primary, FLASH, OTHER_FAMILY];
  return rungs.filter((model, index) => rungs.indexOf(model) === index);
}

/**
 * fal, avec ses secondes chances.
 *
 * Une panne passagère (5xx) attend deux puis huit secondes et change de modèle. Un refus qui
 * vient du compte (401, 403, 429) sort tout de suite pour laisser la main au repli. Un
 * modèle que Google ne sert plus (400 ou 404 amont) saute **sans attendre** au barreau
 * d'une autre famille : attendre dix secondes pour redemander un Gemini mort, c'est ce qui
 * a rallongé chaque thème du 21 octobre.
 */
async function callFal(options: CallOptions, key: string): Promise<string> {
  const useVision = Array.isArray(options.imageUrls) && options.imageUrls.length > 0;
  const primary = resolveModel(options.model);
  const models = falLadder(primary, useVision);
  const delays = useVision ? [] : falRetry.delaysMs;

  let lastError: FalError | null = null;
  let attempt = 0;
  let skipWait = false;

  while (attempt < models.length) {
    const model = models[attempt]!;
    if (attempt > 0) {
      const wait = skipWait ? 0 : delays[attempt - 1] ?? 0;
      // Une pause qui mangerait le temps du dernier essai ne sert à rien : l'erreur précédente
      // est la réponse.
      if (remainingMs(options.deadline) < wait + MIN_ATTEMPT_MS) {
        recordFailure();
        throw lastError ?? timeoutError();
      }
      if (wait > 0) await sleep(wait);
      console.warn(JSON.stringify({ fal: "retry", attempt: attempt + 1, model }));
    }
    // Plus le temps d'un essai : rien n'est lancé, et rien n'est compté contre fal — ce n'est
    // pas lui qui a échoué, c'est la requête qui n'a plus de temps.
    if (attemptTimeout(FAL_TIMEOUT_MS, options.deadline) === null) {
      throw lastError ?? timeoutError();
    }

    try {
      const output = await callFalOnce(options, key, model, useVision);
      recordSuccess();
      return output;
    } catch (error) {
      lastError = error instanceof FalError
        ? error
        : new FalError("L'écriture a échoué. Réessaie, le document n'a rien perdu.", 502, undefined, "provider");
      if (!worthAnotherFalAttempt(lastError)) {
        recordFailure();
        throw lastError;
      }
      if (isModelGone(lastError)) {
        // Le modèle n'existe plus chez l'amont : droit au barreau d'une autre famille.
        const next = models.findIndex((candidate, index) => index > attempt && !sameFamily(candidate, model));
        if (next === -1) {
          recordFailure();
          throw lastError;
        }
        attempt = next;
        skipWait = true;
        continue;
      }
      attempt += 1;
      skipWait = false;
    }
  }

  recordFailure();
  throw lastError ?? new FalError("L'écriture a échoué. Réessaie, le document n'a rien perdu.", 502, undefined, "provider");
}

function sameFamily(a: string, b: string): boolean {
  return a.split("/")[0] === b.split("/")[0];
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

  // `callFal` a vérifié qu'il restait de quoi faire un essai ; le plancher ne sert qu'à ce que
  // quelques millisecondes écoulées entre-temps ne deviennent pas un délai nul.
  const timeout = attemptTimeout(FAL_TIMEOUT_MS, options.deadline) ?? MIN_ATTEMPT_MS;

  let response: Response;
  try {
    response = await fetch(useVision ? VISION_ENDPOINT : TEXT_ENDPOINT, {
      method: "POST",
      headers: {
        "Authorization": `Key ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeout),
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "TimeoutError") {
      throw new FalError("Le modèle a mis trop longtemps à répondre.", 504, undefined, "timeout");
    }
    throw new FalError("Le modèle est injoignable.", 502, undefined, "provider");
  }

  const raw = await response.text();

  if (!response.ok) {
    // Le statut seul ne dit pas si c'est le compte, le modèle ou le débit. Le 8 septembre,
    // les 403 n'ont laissé que leur nombre dans les journaux, et il a fallu deviner.
    const upstream = upstreamReason(raw);
    console.error(JSON.stringify({
      fal: "http_error",
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
    if (/no longer available|not found|does not exist|unknown model|is not supported/i.test(upstream)) {
      modelGone.add(error);
    }
    throw error;
  }

  let parsed: { output?: string; error?: string; model?: string; usage?: unknown };
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new FalError("Réponse illisible de fal.ai.", 502, undefined, "provider");
  }

  // fal ne documente pas de décompte sur `any-llm`. On le lit quand même : s'il en renvoie un,
  // il apparaît ; sinon les compteurs restent à `null`, ce qui est la mesure honnête de « on ne
  // sait pas » et distingue une absence de décompte d'un cache resté froid.
  noteUsage(readUsage(parsed, "fal", model), options.meter);

  if (parsed.error) {
    console.error(JSON.stringify({ fal: "model_error", model }));
    throw new FalError("L'écriture a échoué. Réessaie, le document n'a rien perdu.", 502, undefined, "provider");
  }
  if (!parsed.output) throw new FalError("Le modèle n'a renvoyé aucun contenu.", 502, undefined, "provider");

  return parsed.output;
}

/**
 * Les erreurs dont l'amont a dit « ce modèle n'existe plus ». Un ensemble faible plutôt
 * qu'un champ : l'erreur garde sa forme, et rien d'autre n'a à connaître ce détail.
 */
const modelGone = new WeakSet<FalError>();

function isModelGone(error: FalError): boolean {
  if (modelGone.has(error)) return true;
  return error.upstreamStatus === 404;
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
 * Oui pour une panne ou un refus de compte, non pour un dépassement de délai : l'autre
 * mettrait aussi deux minutes, et le client a déjà raccroché.
 */
function worthAnotherProvider(error: unknown): boolean {
  if (!(error instanceof FalError)) return true;
  if (error.status === 504) return false;
  return error.status >= 500;
}

/** Le refus d'un essai qui n'a plus le temps d'aboutir : le même qu'un délai dépassé. */
function timeoutError(): FalError {
  return new FalError("Le modèle a mis trop longtemps à répondre.", 504, undefined, "timeout");
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
    // La forme de la sortie, pas son texte : voir `describeModelOutput`. C'est ce qui
    // manquait pour distinguer une réponse tronquée d'une réponse en prose.
    console.error(JSON.stringify({
      json: detail.includes("n'a pas renvoyé de JSON") ? "absent" : "illisible",
      ...describeModelOutput(output, error),
    }));
    if (detail.includes("n'a pas renvoyé de JSON")) {
      throw new FalError("Le modèle n'a pas renvoyé de JSON.", 502, undefined, "invalid_json");
    }
    throw new FalError(
      "L'écriture de la fiche a échoué. Réessaie, le document n'a rien perdu.",
      502,
      undefined,
      "invalid_json",
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
  const reason = error instanceof FalError ? error.reason : undefined;
  // **Toute réponse 5xx laisse sa raison.** Les journaux ne gardaient que le statut : un
  // 502 de `generate-flashcards` ne disait pas s'il venait du fournisseur, d'un JSON
  // illisible ou d'un lot sans carte exploitable. Les 4xx sont des refus attendus (quota,
  // cours trop court) et restent silencieux.
  if (status >= 500) {
    console.error(JSON.stringify({
      reponse: status,
      raison: message.slice(0, 200),
      ...(reason ? { cause: reason } : {}),
    }));
  }
  return jsonResponse(reason ? { error: message, reason } : { error: message }, status);
}
