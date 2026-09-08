/**
 * Repli quand fal.ai refuse : même famille de modèles, autre tuyau.
 *
 * La clé reste dans le secret `REPLICATE_API_TOKEN` du projet Supabase
 * (Edge Functions → Secrets). Le site Vercel n'en a pas besoin : il n'appelle
 * jamais Replicate, seules les fonctions le font.
 */

import { FalError } from "./model-error.ts";

const REPLICATE_TIMEOUT_MS = 120_000;
const POLL_MS = 800;

/** Lite n'existe pas chez Replicate : on sert Flash, le plus proche. */
export const REPLICATE_MODEL = "google/gemini-2.5-flash";

export function resolveReplicateModel(_requested?: string): { owner: string; name: string } {
  return { owner: "google", name: "gemini-2.5-flash" };
}

export function flattenReplicateOutput(output: unknown): string {
  if (typeof output === "string") return output;
  if (Array.isArray(output)) return output.map(flattenReplicateOutput).join("");
  if (output && typeof output === "object") {
    const record = output as Record<string, unknown>;
    if (typeof record.text === "string") return record.text;
    if (typeof record.output === "string") return record.output;
  }
  return "";
}

interface Prediction {
  status?: string;
  output?: unknown;
  error?: string | null;
  urls?: { get?: string };
}

export async function callReplicate(options: {
  prompt: string;
  systemPrompt?: string;
  model?: string;
  imageUrls?: string[];
  temperature?: number;
  maxTokens?: number;
}, token: string): Promise<string> {
  const deadline = Date.now() + REPLICATE_TIMEOUT_MS;
  const { owner, name } = resolveReplicateModel(options.model);
  const input: Record<string, unknown> = {
    prompt: options.prompt,
    thinking_budget: 0,
  };
  if (options.systemPrompt) input.system_instruction = options.systemPrompt;
  if (typeof options.temperature === "number") input.temperature = options.temperature;
  if (typeof options.maxTokens === "number") input.max_output_tokens = options.maxTokens;
  if (Array.isArray(options.imageUrls) && options.imageUrls.length > 0) {
    input.images = options.imageUrls;
  }

  let prediction: Prediction;
  try {
    const response = await fetch(
      `https://api.replicate.com/v1/models/${owner}/${name}/predictions`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          Prefer: "wait",
        },
        body: JSON.stringify({ input }),
        signal: AbortSignal.timeout(Math.max(8_000, deadline - Date.now())),
      },
    );
    const raw = await response.text();
    if (!response.ok) {
      console.error(JSON.stringify({ replicate: "http_error", status: response.status, model: `${owner}/${name}` }));
      throw new FalError("L'écriture a échoué. Réessaie, le document n'a rien perdu.", 502);
    }
    prediction = JSON.parse(raw) as Prediction;
  } catch (error) {
    if (error instanceof FalError) throw error;
    if (error instanceof DOMException && error.name === "TimeoutError") {
      throw new FalError("Le modèle a mis trop longtemps à répondre.", 504);
    }
    throw new FalError("Le modèle est injoignable.", 502);
  }

  while (prediction.status === "starting" || prediction.status === "processing") {
    const remaining = deadline - Date.now();
    if (remaining <= 0) {
      throw new FalError("Le modèle a mis trop longtemps à répondre.", 504);
    }
    const getUrl = prediction.urls?.get;
    if (!getUrl) {
      throw new FalError("Réponse illisible de Replicate.", 502);
    }
    await sleep(Math.min(POLL_MS, remaining));
    const polled = await fetch(getUrl, {
      headers: { Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(Math.max(5_000, deadline - Date.now())),
    });
    if (!polled.ok) {
      console.error(JSON.stringify({ replicate: "poll_error", status: polled.status }));
      throw new FalError("L'écriture a échoué. Réessaie, le document n'a rien perdu.", 502);
    }
    prediction = (await polled.json()) as Prediction;
  }

  if (prediction.status !== "succeeded") {
    console.error(JSON.stringify({ replicate: "model_error", status: prediction.status ?? "unknown" }));
    throw new FalError("L'écriture a échoué. Réessaie, le document n'a rien perdu.", 502);
  }

  const output = flattenReplicateOutput(prediction.output);
  if (!output) throw new FalError("Le modèle n'a renvoyé aucun contenu.", 502);
  return output;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
