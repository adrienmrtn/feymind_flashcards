/**
 * **L'échéance d'une requête**, partagée par tous les appels au modèle qu'elle fait.
 *
 * Chaque appel avait son propre délai — deux minutes chez Gemini comme chez fal —, et une
 * requête en enchaîne plusieurs : le plan d'une leçon, c'est la passe visuelle, le plan, et
 * son second essai. Additionnés, ces délais dépassaient l'horloge de la plateforme, qui tue
 * la fonction sans prévenir : le `catch` qui rend la leçon réservée (`releaseLesson`) ne
 * s'exécutait jamais, et la leçon offerte restait prise pour un plan qui n'était pas arrivé.
 *
 * Une échéance pour toute la requête, posée à son entrée : chaque appel prend le plus court
 * de son propre délai et du temps qui reste, et un appel qui n'aurait plus le temps d'aboutir
 * n'est pas lancé. La fonction échoue donc **elle-même**, avant la plateforme, et son `catch`
 * a le temps de faire son travail.
 */

/** Le temps qu'une requête peut passer à attendre le modèle : sous l'horloge de 150 s. */
export const REQUEST_BUDGET_MS = 130_000;

/** En deçà, un appel n'a aucune chance d'aboutir : autant rendre le refus tout de suite. */
export const MIN_ATTEMPT_MS = 5_000;

/** L'échéance d'une requête qui commence maintenant. */
export function deadlineIn(budgetMs = REQUEST_BUDGET_MS, now = Date.now()): number {
  return now + budgetMs;
}

/** Le temps qui reste avant l'échéance ; sans échéance, l'infini. */
export function remainingMs(deadline: number | undefined, now = Date.now()): number {
  if (deadline === undefined || !Number.isFinite(deadline)) return Number.POSITIVE_INFINITY;
  return Math.max(0, deadline - now);
}

/**
 * Le délai d'un appel : le sien, ou le temps qui reste s'il est plus court. `null` quand il
 * ne reste pas `MIN_ATTEMPT_MS` : l'appelant refuse alors sans rien lancer.
 */
export function attemptTimeout(
  ownMs: number,
  deadline: number | undefined,
  now = Date.now(),
): number | null {
  const left = remainingMs(deadline, now);
  if (left < MIN_ATTEMPT_MS) return null;
  return Math.min(ownMs, left);
}

/** La plus proche de deux échéances, l'une ou l'autre pouvant manquer. */
export function earliest(a: number | undefined, b: number | undefined): number | undefined {
  if (a === undefined) return b;
  if (b === undefined) return a;
  return Math.min(a, b);
}
