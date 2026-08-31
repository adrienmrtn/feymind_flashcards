/**
 * Coupe fal.ai quand il enchaîne les échecs.
 *
 * Sans ça, une panne amont se paie deux fois : chaque requête attend le timeout,
 * et la facture continue. Cinq échecs d'affilée ferment la porte une minute.
 * Un succès la rouvre. L'état vit dans l'isolat : un redémarrage le remet à zéro,
 * ce qui est le comportement qu'on veut.
 */

const THRESHOLD = 5;
const COOLDOWN_MS = 60_000;

let failures = 0;
let openUntil = 0;

export class CircuitOpenError extends Error {
  readonly status = 503;

  constructor() {
    super("Le modèle est temporairement indisponible. Réessaie dans une minute.");
  }
}

export function checkCircuit(): void {
  if (Date.now() < openUntil) throw new CircuitOpenError();
}

export function recordSuccess(): void {
  failures = 0;
  openUntil = 0;
}

export function recordFailure(): void {
  failures += 1;
  if (failures >= THRESHOLD) {
    openUntil = Date.now() + COOLDOWN_MS;
    failures = 0;
  }
}

/** Remet l'état à zéro. Réservé aux tests. */
export function resetCircuit(): void {
  failures = 0;
  openUntil = 0;
}
