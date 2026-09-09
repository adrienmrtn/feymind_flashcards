/**
 * Le plan cesse de supposer, et se met à mesurer.
 *
 * `CARDS_PER_MINUTE = 4` est une constante, la même pour tout le monde depuis le premier jour.
 * Elle décide de tout : combien de cartes tiennent dans une soirée, si la période tient, quel
 * déficit annoncer. Pour quelqu'un qui fait deux cartes et demie à la minute, **chaque chiffre
 * du produit ment de soixante pour cent** - et il ment dans le sens qui fait rater l'examen,
 * puisqu'il promet plus que ce qui sera fait.
 *
 * On ne peut pas le demander : personne ne connaît son propre débit, et une réponse au jugé
 * serait aussi fausse que la constante. On le mesure, sur ce que l'étudiant a déjà fait.
 *
 * Deux mesures, deux usages.
 *
 * - **Le débit** (`throughput`) remplace la constante dans la conversion cartes ↔ minutes.
 * - **L'observance** (`adherence`) dit quelle part du temps déclaré est réellement utilisée.
 *   Elle ne sert pas à faire la morale : elle sert à ce que le déficit apparaisse à J-20,
 *   quand on peut encore l'absorber, plutôt qu'à J-2.
 *
 * Tant qu'on ne sait pas, on ne prétend pas savoir : les deux fonctions rendent la valeur par
 * défaut jusqu'à ce qu'il y ait assez de passages, et le produit se comporte comme avant.
 */

import { CARDS_PER_MINUTE } from "./daily-load";
import { startOfDay } from "./exam";
import type { DailyReview } from "./mastery";

/** En deçà, la mesure n'est pas une mesure : on garde la constante. */
export const MIN_PASSES_FOR_THROUGHPUT = 40;

/** Bornes du débit mesuré. Au-delà, c'est un artefact et non un étudiant. */
export const MIN_THROUGHPUT = 1.0;
export const MAX_THROUGHPUT = 12.0;

/** Ce que la base a mesuré sur les écarts entre passages. */
export interface ThroughputSample {
  cards: number;
  cardsPerMinute: number | null;
}

export interface Throughput {
  /** Cartes par minute retenues pour tous les calculs. */
  cardsPerMinute: number;
  /** Vrai quand le chiffre vient de l'étudiant et non du défaut. */
  measured: boolean;
  /** Écart au défaut, en pourcentage. Négatif quand l'étudiant est plus lent. */
  driftPercent: number;
}

export const DEFAULT_THROUGHPUT: Throughput = {
  cardsPerMinute: CARDS_PER_MINUTE,
  measured: false,
  driftPercent: 0,
};

export function throughputFrom(sample: ThroughputSample | null | undefined): Throughput {
  if (
    !sample ||
    sample.cardsPerMinute == null ||
    !Number.isFinite(sample.cardsPerMinute) ||
    sample.cards < MIN_PASSES_FOR_THROUGHPUT
  ) {
    return DEFAULT_THROUGHPUT;
  }

  const rate = Math.max(MIN_THROUGHPUT, Math.min(MAX_THROUGHPUT, sample.cardsPerMinute));
  return {
    cardsPerMinute: rate,
    measured: true,
    driftPercent: Math.round(((rate - CARDS_PER_MINUTE) / CARDS_PER_MINUTE) * 100),
  };
}

/** Les cartes qui tiennent dans un temps, au débit de cet étudiant. */
export function cardsIn(minutes: number, throughput: Throughput): number {
  return Math.max(0, Math.floor(Math.max(0, minutes) * throughput.cardsPerMinute));
}

/** Le temps que coûtent des cartes, au débit de cet étudiant. */
export function minutesFor(cards: number, throughput: Throughput): number {
  if (cards <= 0) return 0;
  return Math.max(1, Math.ceil(cards / throughput.cardsPerMinute));
}

// MARK: - L'observance

/** Jours regardés pour juger l'observance : assez pour lisser une mauvaise semaine. */
export const ADHERENCE_WINDOW_DAYS = 21;

/** En deçà de tant de jours ouverts observés, on ne conclut rien. */
export const MIN_DAYS_FOR_ADHERENCE = 5;

export interface Adherence {
  /** Entre 0 et 1. Part de la capacité déclarée réellement utilisée. */
  ratio: number;
  measured: boolean;
  /** Jours ouverts observés. */
  observedDays: number;
  /** Jours ouverts où rien n'a été fait. */
  missedDays: number;
}

export const FULL_ADHERENCE: Adherence = {
  ratio: 1,
  measured: false,
  observedDays: 0,
  missedDays: 0,
};

/**
 * Quelle part du temps déclaré est réellement utilisée.
 *
 * On compare aux **jours ouverts uniquement** : un dimanche déclaré à zéro n'est pas un jour
 * manqué, c'est un jour qu'on s'est donné. Compter les jours fermés dans la moyenne
 * punirait exactement les gens qui ont réglé leurs disponibilités honnêtement.
 *
 * Le jour en cours ne compte pas : à dix heures du matin, personne n'a encore fait sa journée,
 * et l'inclure ferait plonger l'observance à chaque ouverture de l'app.
 */
export function adherenceFrom(
  daily: readonly DailyReview[],
  capacityFor: (date: Date) => number,
  throughput: Throughput,
  now: Date = new Date(),
): Adherence {
  const today = startOfDay(now);
  const doneByDay = new Map<string, number>();
  for (const point of daily) {
    doneByDay.set(dayKey(point.day), point.passes);
  }

  let sum = 0;
  let observed = 0;
  let missed = 0;

  for (let back = 1; back <= ADHERENCE_WINDOW_DAYS; back += 1) {
    const day = new Date(today.getTime());
    day.setDate(day.getDate() - back);

    const capacity = capacityFor(day);
    if (capacity <= 0) continue;

    const expected = cardsIn(capacity, throughput);
    if (expected <= 0) continue;

    const done = doneByDay.get(dayKey(day)) ?? 0;
    sum += Math.min(1, done / expected);
    observed += 1;
    if (done === 0) missed += 1;
  }

  if (observed < MIN_DAYS_FOR_ADHERENCE) {
    return { ...FULL_ADHERENCE, observedDays: observed, missedDays: missed };
  }

  return {
    ratio: Math.max(0, Math.min(1, sum / observed)),
    measured: true,
    observedDays: observed,
    missedDays: missed,
  };
}

/**
 * La capacité à laquelle il faut vraiment planifier.
 *
 * Planifier sur le temps déclaré quand on n'en tient que la moitié, c'est produire un plan qui
 * se sait faux et qui reporte l'aveu au dernier moment. On rabat donc la capacité sur ce qui
 * est réellement tenu, sans jamais descendre en dessous de la moitié du déclaré : quelqu'un
 * qui a eu une mauvaise semaine ne doit pas voir son plan s'effondrer, il doit le voir se
 * resserrer.
 *
 * On ne rabat **jamais vers le haut** : si l'étudiant en fait plus que prévu, tant mieux, le
 * plan n'a pas à lui en demander davantage que le temps qu'il s'est donné.
 */
export function realisticCapacity(declaredMinutes: number, adherence: Adherence): number {
  if (!adherence.measured || declaredMinutes <= 0) return declaredMinutes;
  const factor = Math.max(0.5, Math.min(1, adherence.ratio));
  return Math.max(1, Math.round(declaredMinutes * factor));
}

/** Comment nommer l'observance à l'écran, sans juger. */
export type AdherenceLevel = "steady" | "slipping" | "behind";

export function adherenceLevel(adherence: Adherence): AdherenceLevel {
  if (!adherence.measured || adherence.ratio >= 0.8) return "steady";
  return adherence.ratio >= 0.5 ? "slipping" : "behind";
}

function dayKey(date: Date): string {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, "0");
  const day = `${date.getDate()}`.padStart(2, "0");
  return `${year}-${month}-${day}`;
}
