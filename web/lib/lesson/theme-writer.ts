"use client";

/**
 * **Les thèmes d'une leçon s'écrivent depuis le navigateur**, quatre à la fois, par
 * `/api/lesson/theme`. Un seul chantier pour tout l'onglet : l'écran de génération lance les
 * premiers, la page du chemin reprend ceux qui restent après la navigation, et un thème déjà
 * parti n'est jamais demandé deux fois. Jumeau de `LessonBuilder.writeThemes` côté Swift.
 *
 * Un navigateur fermé en route laisse des thèmes en préparation : la page du chemin les
 * relance à l'ouverture suivante, depuis l'état en base.
 */

export const PARALLEL_THEMES = 4;

export interface ThemeEvent {
  lessonId: string;
  themeIndex: number;
  ok: boolean;
  message?: string;
  code?: string;
}

type Listener = (event: ThemeEvent) => void;

const inflight = new Map<string, Promise<ThemeEvent>>();
const listeners = new Set<Listener>();

function key(lessonId: string, themeIndex: number): string {
  return `${lessonId}:${themeIndex}`;
}

export function isWriting(lessonId: string, themeIndex: number): boolean {
  return inflight.has(key(lessonId, themeIndex));
}

export function writingCount(lessonId: string): number {
  let count = 0;
  for (const entry of inflight.keys()) if (entry.startsWith(`${lessonId}:`)) count += 1;
  return count;
}

export function subscribe(listener: Listener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

async function post(lessonId: string, themeIndex: number, retry: boolean): Promise<ThemeEvent> {
  try {
    const response = await fetch("/api/lesson/theme", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ lessonId, themeIndex, retry }),
    });
    const result = (await response.json()) as { status: string; message?: string; code?: string };
    return { lessonId, themeIndex, ok: result.status === "ok", message: result.message, code: result.code };
  } catch {
    return { lessonId, themeIndex, ok: false };
  }
}

/**
 * Écrit les thèmes donnés, quatre à la fois, en sautant ceux déjà partis. Rend quand tous
 * ceux de cet appel sont arrivés (réussis ou non).
 */
export async function writeThemes(lessonId: string, indices: readonly number[], options: { retry?: boolean } = {}): Promise<ThemeEvent[]> {
  const queue = [...new Set(indices)].filter((index) => !isWriting(lessonId, index));
  const results: ThemeEvent[] = [];
  const workers = Array.from({ length: Math.min(PARALLEL_THEMES, queue.length) }, async () => {
    while (queue.length > 0) {
      const index = queue.shift()!;
      const promise = post(lessonId, index, options.retry === true);
      inflight.set(key(lessonId, index), promise);
      const event = await promise;
      inflight.delete(key(lessonId, index));
      results.push(event);
      for (const listener of listeners) listener(event);
    }
  });
  await Promise.all(workers);
  return results;
}

/** Se résout au premier thème arrivé pour cette leçon — ou tout de suite s'il n'en reste aucun en route. */
export function firstCompletion(lessonId: string): Promise<ThemeEvent | null> {
  if (writingCount(lessonId) === 0) return Promise.resolve(null);
  return new Promise((resolve) => {
    const stop = subscribe((event) => {
      if (event.lessonId !== lessonId) return;
      stop();
      resolve(event);
    });
  });
}
