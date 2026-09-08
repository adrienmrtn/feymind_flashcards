/**
 * Jauge d'écriture. Personne ne sait combien de temps prend un modèle : on
 * grimpe vite au début, on ralentit, et on ne montre jamais 100 % tant que
 * le travail n'est pas fini. Un Anki qui verse ses cartes a un vrai ratio.
 */

const TAU_MS = 16_000;
const ELAPSED_CAP = 0.94;

export function elapsedGenerationProgress(elapsedMs: number, cap = ELAPSED_CAP): number {
  const t = 1 - Math.exp(-Math.max(0, elapsedMs) / TAU_MS);
  return Math.min(cap, t);
}

export function knownGenerationProgress(done: number, total: number): number {
  if (total <= 0) return 0;
  return Math.min(1, Math.max(0, done / total));
}

export function displayGenerationPercent(
  fraction: number,
  { known }: { known: boolean },
): number {
  const rounded = Math.round(fraction * 100);
  if (known) return Math.min(100, Math.max(0, rounded));
  return Math.min(99, Math.max(1, rounded));
}
