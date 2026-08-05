/**
 * Synthèse vocale MiniMax via fal.ai.
 * speech-02-turbo à 0,06 $/1k caractères : le meilleur rapport qualité / prix
 * pour du français à deux voix.
 */

import { FalError } from "./fal.ts";

const TTS_ENDPOINT = "https://fal.run/fal-ai/minimax/speech-02-turbo";

export interface TTSResult {
  url: string;
  durationMs: number;
}

export async function synthesizeSpeech(
  text: string,
  voiceId: string,
  options: { speed?: number } = {},
): Promise<TTSResult> {
  const key = Deno.env.get("FAL_KEY");
  if (!key) {
    throw new FalError(
      "Le secret FAL_KEY est absent du projet Supabase. Ajoutez-le dans Edge Functions, Secrets.",
      500,
    );
  }

  const trimmed = text.trim();
  if (!trimmed) {
    throw new FalError("Réplique vide, impossible de synthétiser.", 400);
  }

  // MiniMax plafonne à 5000 caractères par requête.
  const chunk = trimmed.slice(0, 4800);

  const response = await fetch(TTS_ENDPOINT, {
    method: "POST",
    headers: {
      Authorization: `Key ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      text: chunk,
      voice_setting: {
        voice_id: voiceId,
        speed: options.speed ?? 1.05,
        vol: 1,
        pitch: 0,
        emotion: "neutral",
      },
      language_boost: "French",
      output_format: "url",
    }),
  });

  const raw = await response.text();
  if (!response.ok) {
    throw new FalError(`TTS MiniMax a répondu ${response.status} : ${raw.slice(0, 400)}`, 502);
  }

  let parsed: { audio?: { url?: string }; duration_ms?: number; error?: string };
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new FalError("Réponse TTS illisible.", 502);
  }

  if (parsed.error) throw new FalError(parsed.error, 502);
  const url = parsed.audio?.url;
  if (!url) throw new FalError("Le TTS n'a renvoyé aucune URL audio.", 502);

  return {
    url,
    durationMs: typeof parsed.duration_ms === "number" ? parsed.duration_ms : estimateDurationMs(chunk),
  };
}

/** Estimation grossière quand MiniMax n'envoie pas la durée. */
export function estimateDurationMs(text: string): number {
  // Environ 14 caractères par seconde en français parlé.
  return Math.max(800, Math.round((text.length / 14) * 1000));
}

/** Lance les synthèses par lots pour rester sous les limites de concurrence. */
export async function synthesizeBatch(
  items: Array<{ text: string; voiceId: string }>,
  concurrency = 3,
): Promise<TTSResult[]> {
  const results: TTSResult[] = new Array(items.length);
  let cursor = 0;

  async function worker() {
    while (cursor < items.length) {
      const index = cursor++;
      const item = items[index];
      results[index] = await synthesizeSpeech(item.text, item.voiceId);
    }
  }

  const workers = Array.from({ length: Math.min(concurrency, items.length) }, () => worker());
  await Promise.all(workers);
  return results;
}
