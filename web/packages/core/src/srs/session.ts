/**
 * La file **pendant** une session — pas la file du jour.
 *
 * `buildQueue` décide quelles cartes entrent. Celle-ci décide quand la session s'arrête.
 * Une carte notée « 10 min » n'est pas une carte terminée : si le reste du paquet est
 * épuisé avant ces dix minutes, la session attend, comme Anki. « Tout est à jour »
 * n'apparaît que lorsque plus aucune carte de la session n'est due dans la fenêtre
 * d'anticipation.
 */

/** Une carte replanifiée à moins de 20 minutes revient dans la même session. */
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
  nextAvailableAt: Date | null;
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

/** La première carte dont l'échéance est déjà passée, ou `-1`. */
export function nextReadyIndex<T>(pending: readonly SessionEntry<T>[], now: Date): number {
  const nowMs = now.getTime();
  let best = -1;
  let bestAt = Number.POSITIVE_INFINITY;

  for (let index = 0; index < pending.length; index += 1) {
    const at = pending[index]!.availableAt.getTime();
    if (at <= nowMs && at < bestAt) {
      best = index;
      bestAt = at;
    }
  }

  return best;
}

export function earliestAvailableAt<T>(pending: readonly SessionEntry<T>[]): Date | null {
  if (pending.length === 0) return null;
  return pending.reduce(
    (min, entry) => (entry.availableAt < min ? entry.availableAt : min),
    pending[0]!.availableAt,
  );
}

/**
 * Sert une carte seulement si elle est due **maintenant**. S'il reste des cartes plus
 * tard dans la fenêtre, la session n'est pas finie : elle attend.
 */
export function advanceSession<T>(
  pending: readonly SessionEntry<T>[],
  now: Date,
): SessionAdvance<T> {
  const ready = nextReadyIndex(pending, now);
  if (ready >= 0) {
    return {
      current: pending[ready]!.card,
      pending: pending.filter((_, index) => index !== ready),
      nextAvailableAt: null,
      done: false,
    };
  }

  if (pending.length === 0) {
    return { current: null, pending: [], nextAvailableAt: null, done: true };
  }

  return {
    current: null,
    pending: [...pending],
    nextAvailableAt: earliestAvailableAt(pending),
    done: false,
  };
}
