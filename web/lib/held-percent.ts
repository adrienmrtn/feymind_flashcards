/**
 * Un pourcentage qui avance, puis s'arrête avant la fin.
 *
 * On ne peut pas connaître la durée réelle d'une génération. Montrer 100 %
 * trop tôt ment ; rester à 0 % abandonne. On grimpe jusqu'à 92 %, et le
 * composant disparaît quand l'attente se ferme pour de bon.
 */

export const HELD_PERCENT_CAP = 92;

export function heldPercentAt(elapsedMs: number, durationMs: number): number {
  if (durationMs <= 0 || elapsedMs <= 0) return 1;
  const t = Math.min(1, elapsedMs / durationMs);
  const eased = 1 - (1 - t) ** 2.4;
  return Math.max(1, Math.min(HELD_PERCENT_CAP, Math.round(eased * HELD_PERCENT_CAP)));
}
