/**
 * La file **pendant** une session - pas la file du jour.
 *
 * `buildQueue` décide quelles cartes entrent. Celle-ci décide dans quel ordre elles
 * repassent, et quand la session s'arrête.
 *
 * **Personne n'attend devant un compte à rebours.** Une carte notée « 1 min »,
 * « 6 min » ou « 10 min » n'est pas terminée, mais faire patienter devant un chronomètre est un écran
 * qui ne sert à rien : le palier existe pour espacer deux passages quand il y a autre
 * chose à faire, pas pour immobiliser quelqu'un qui a fini son paquet. Quand il ne reste
 * que des cartes d'apprentissage, on les sert **tout de suite** - c'est la fenêtre
 * d'anticipation d'Anki (20 min), appliquée sans écran intermédiaire.
 *
 * « Tout est à jour » n'apparaît donc que lorsque la file est vraiment vide.
 */

/** Une carte replanifiée dans la fenêtre d'Anki (20 min) revient dans la même session. */
export const LEARN_AHEAD_SECONDS = 20 * 60;

export function returnsInSession(
  dueDate: Date,
  now: Date,
  windowSeconds: number = LEARN_AHEAD_SECONDS,
): boolean {
  return (dueDate.getTime() - now.getTime()) / 1000 <= windowSeconds;
}

export interface SessionEntry<T> {
  card: T;
  availableAt: Date;
}

export interface SessionAdvance<T> {
  current: T | null;
  pending: SessionEntry<T>[];
  done: boolean;
}

/**
 * Échelonne les instants d'un rien pour que l'ordre reçu survive au tri par
 * disponibilité. Toutes les cartes sont déjà dues : elles sont donc prêtes tout de suite.
 */
export function enqueueInitial<T>(cards: readonly T[], now: Date): SessionEntry<T>[] {
  return cards.map((card, index) => ({
    card,
    availableAt: new Date(now.getTime() + (index - cards.length) * 1000),
  }));
}

/** L'entrée qui revient le plus tôt, ou `-1` si la file est vide. */
export function earliestIndex<T>(pending: readonly SessionEntry<T>[]): number {
  let best = -1;
  let bestAt = Number.POSITIVE_INFINITY;

  for (let index = 0; index < pending.length; index += 1) {
    const at = pending[index]!.availableAt.getTime();
    if (at < bestAt) {
      best = index;
      bestAt = at;
    }
  }

  return best;
}

export function earliestAvailableAt<T>(pending: readonly SessionEntry<T>[]): Date | null {
  const index = earliestIndex(pending);
  return index < 0 ? null : pending[index]!.availableAt;
}

/**
 * Sert la carte qui revient le plus tôt, **même si son palier n'est pas écoulé**, tant
 * qu'elle rentre dans la fenêtre d'anticipation. Les cartes déjà dues passent d'abord,
 * puisqu'elles sont les plus anciennes ; une carte d'apprentissage seule au monde est
 * servie sans attendre.
 */
export function advanceSession<T>(
  pending: readonly SessionEntry<T>[],
  now: Date,
  windowSeconds: number = LEARN_AHEAD_SECONDS,
): SessionAdvance<T> {
  const index = earliestIndex(pending);
  if (index < 0) {
    return { current: null, pending: [], done: true };
  }

  const entry = pending[index]!;
  if ((entry.availableAt.getTime() - now.getTime()) / 1000 > windowSeconds) {
    // Hors fenêtre : plus rien à faire aujourd'hui. Ne peut arriver que si une carte a
    // été mise en file par un chemin qui n'a pas filtré, et vaut mieux qu'une attente.
    return { current: null, pending: [], done: true };
  }

  return {
    current: entry.card,
    pending: pending.filter((_, at) => at !== index),
    done: false,
  };
}
