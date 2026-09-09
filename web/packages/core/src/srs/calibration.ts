/**
 * Le plan cesse de supposer, et se met à mesurer.
 *
 * `CARDS_PER_MINUTE = 4` est une constante, la même pour tout le monde depuis le premier jour.
 * Elle décide de la seule chose que le produit annonce encore en minutes : le temps que la
 * journée va prendre. Pour quelqu'un qui fait deux cartes et demie à la minute, **ce chiffre
 * ment de soixante pour cent** - et il ment dans le sens qui fait rater l'examen, puisqu'il
 * promet une soirée plus courte qu'elle ne sera.
 *
 * On ne peut pas le demander : personne ne connaît son propre débit, et une réponse au jugé
 * serait aussi fausse que la constante. On le mesure, sur ce que l'étudiant a déjà fait.
 *
 * L'observance vivait ici aussi : quelle part du temps déclaré était réellement utilisée. Elle
 * est partie avec le temps déclaré. Rien ne se déclare plus, donc il n'y a plus d'écart entre
 * la promesse et le fait, donc il n'y a plus rien à rattraper de ce côté.
 *
 * Tant qu'on ne sait pas, on ne prétend pas savoir : la mesure rend la valeur par défaut
 * jusqu'à ce qu'il y ait assez de passages, et le produit se comporte comme avant.
 */

import { CARDS_PER_MINUTE } from "./daily-load";

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
