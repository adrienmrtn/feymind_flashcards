/**
 * Ce qui résiste, et comment le faire revenir.
 *
 * La répétition espacée traite l'échec par l'intervalle : une carte ratée redescend, elle
 * revient plus tôt, et c'est tout. Ça suffit hors examen, où le temps est infini. Avant une
 * épreuve, non : une carte ratée quatre fois sur six est une **note perdue le jour J**, et
 * l'algorithme la traite exactement comme une carte ratée une fois sur douze.
 *
 * Ce fichier ajoute la seule chose que SM-2 ne sait pas voir : **le taux d'échec dans le
 * temps**. Il ne remplace ni l'intervalle ni la file d'Anki - il les trie.
 *
 * Trois notions, à ne pas confondre.
 *
 * - **La fragilité** (`weakness`) : la part de ratés sur les derniers passages, corrigée du
 *   nombre de passages. Deux ratés sur trois est un signal ; deux ratés sur quarante n'en est
 *   pas un, et un rapport brut confondrait les deux.
 * - **Le point noir** (`isStubborn`) : une carte qui a assez rechuté pour qu'on doive la
 *   signaler à l'étudiant, parce que la répéter encore ne suffira pas - c'est la formulation
 *   de la carte qu'il faut revoir.
 * - **La maîtrise** (`mastery.ts`) : l'inverse, à l'échelle d'un cours.
 *
 * Rien ici ne devine : tout part de `review_logs`, c'est-à-dire de ce que l'étudiant a
 * réellement répondu.
 */

import type { CardState } from "./types";
import { isMature } from "./types";

/** Ce que le journal de révision dit d'une carte. */
export interface CardDifficulty {
  cardId: string;
  reviews: number;
  againCount: number;
  hardCount: number;
  lastRating: number | null;
  lastReviewedAt: Date | null;
}

export const NO_DIFFICULTY: ReadonlyMap<string, CardDifficulty> = new Map();

/** En deçà, le taux d'échec ne veut rien dire : on ne juge pas sur deux réponses. */
export const MIN_REVIEWS_FOR_WEAKNESS = 3;

/** Au-delà de ce taux d'échec, la carte remonte devant les autres. */
export const WEAK_THRESHOLD = 0.3;

/** Au-delà, la carte mérite deux passages de plus et non un seul. */
export const SEVERE_THRESHOLD = 0.45;

/**
 * Le poids de l'a priori, en passages fictifs, et le taux d'échec qu'il suppose.
 *
 * Six passages à 15 % de ratés : c'est ce qu'on « croit » d'une carte avant de l'avoir vue
 * travailler. Plus ce poids est faible, plus une carte ratée une fois sur une remonte haut,
 * et c'est exactement le classement qu'il ne faut pas produire.
 */
export const PRIOR_REVIEWS = 6;
export const PRIOR_FAILURE_RATE = 0.15;

/** Rechutes à partir desquelles on prévient l'étudiant que la carte est mal formulée. */
export const STUBBORN_LAPSES = 5;

/**
 * La fragilité d'une carte, entre 0 et 1.
 *
 * Le taux de ratés, tiré vers un a priori neutre à proportion du peu qu'on sait. Le rapport
 * brut ne peut pas servir : une carte ratée une fois sur une donnerait 100 %, et passerait
 * devant une carte ratée huit fois sur vingt qui est le vrai problème. Un lissage trop léger
 * ne suffit pas non plus - il faut que six passages fictifs pèsent, pour qu'une poignée de
 * réponses ne fasse pas un verdict.
 *
 * Un « difficile » compte pour un demi-raté : ce n'est pas un échec, mais ce n'est pas su.
 */
export function weakness(difficulty: CardDifficulty): number {
  const reviews = Math.max(0, difficulty.reviews);
  if (reviews === 0) return 0;
  const failures = Math.max(0, difficulty.againCount) + Math.max(0, difficulty.hardCount) * 0.5;
  const prior = PRIOR_REVIEWS * PRIOR_FAILURE_RATE;
  return clamp01((failures + prior) / (reviews + PRIOR_REVIEWS));
}

/** Une carte qu'il faut revoir en priorité avant l'épreuve. */
export function isWeak(difficulty: CardDifficulty): boolean {
  if (difficulty.reviews < MIN_REVIEWS_FOR_WEAKNESS) return false;
  return weakness(difficulty) >= WEAK_THRESHOLD;
}

/**
 * Une carte qui a trop rechuté pour que la répétition seule s'en sorte.
 *
 * À ne pas confondre avec `isLeech` de `sm2.ts`, qui applique le seuil d'Anki à huit rechutes
 * pour décider d'une suspension. Ici on avertit plus tôt et on ne suspend rien : à trois jours
 * d'une épreuve, retirer une carte du programme est la dernière chose à faire. On la signale,
 * et l'étudiant décide de la reformuler ou de la couper en deux.
 */
export function isStubborn(lapses: number, difficulty: CardDifficulty | undefined): boolean {
  if (lapses >= STUBBORN_LAPSES) return true;
  if (!difficulty) return false;
  return difficulty.reviews >= 6 && difficulty.againCount >= 4;
}

/** Une carte vue par le tri des points faibles. */
export interface WeakCandidate {
  id: string;
  courseId: string | null;
  front: string;
  kind: string;
  state: CardState;
  intervalDays: number;
  lapses: number;
  isSuspended: boolean;
}

export interface WeakCard {
  id: string;
  courseId: string | null;
  front: string;
  kind: string;
  /** Entre 0 et 1. Plus c'est haut, plus la carte résiste. */
  weakness: number;
  reviews: number;
  againCount: number;
  lapses: number;
  isStubborn: boolean;
}

/**
 * Les cartes qui résistent, de la pire à la moins pire.
 *
 * On garde les cartes réellement passées plusieurs fois : une carte neuve n'est pas
 * « fragile », elle est neuve, et la mélanger aux vraies rechutes noierait le signal.
 */
export function weakCards(
  cards: readonly WeakCandidate[],
  difficulties: ReadonlyMap<string, CardDifficulty>,
  options: { limit?: number; courseIds?: readonly string[] } = {},
): WeakCard[] {
  const scope = options.courseIds ? new Set(options.courseIds) : null;
  const found: WeakCard[] = [];

  for (const card of cards) {
    if (card.isSuspended) continue;
    if (scope && (!card.courseId || !scope.has(card.courseId))) continue;
    const difficulty = difficulties.get(card.id);
    if (!difficulty || !isWeak(difficulty)) continue;

    found.push({
      id: card.id,
      courseId: card.courseId,
      front: card.front,
      kind: card.kind,
      weakness: weakness(difficulty),
      reviews: difficulty.reviews,
      againCount: difficulty.againCount,
      lapses: card.lapses,
      isStubborn: isStubborn(card.lapses, difficulty),
    });
  }

  found.sort((left, right) => {
    if (right.weakness !== left.weakness) return right.weakness - left.weakness;
    if (right.againCount !== left.againCount) return right.againCount - left.againCount;
    return left.id < right.id ? -1 : 1;
  });

  return options.limit ? found.slice(0, options.limit) : found;
}

/**
 * Les passages supplémentaires qu'une carte fragile mérite avant l'épreuve.
 *
 * Zéro pour une carte saine, un ou deux pour une carte qui résiste. C'est volontairement
 * borné : une carte impossible peut engloutir une session entière, et la note se gagne sur
 * l'ensemble du programme, pas sur la carte qui a vexé l'étudiant.
 */
export function extraPassesFor(difficulty: CardDifficulty | undefined): number {
  if (!difficulty || !isWeak(difficulty)) return 0;
  return weakness(difficulty) >= SEVERE_THRESHOLD ? 2 : 1;
}

/**
 * L'ordre de révision, points faibles devant.
 *
 * Rend les identifiants de cartes triés : les fragiles d'abord, à fragilité égale l'ordre
 * reçu. On trie une file déjà construite plutôt que d'en construire une autre - la file
 * d'Anki décide **de ce qui est dû**, ceci décide seulement **de ce qui passe en premier**.
 */
export function weakFirst(
  cardIds: readonly string[],
  difficulties: ReadonlyMap<string, CardDifficulty>,
): string[] {
  const rank = new Map<string, number>();
  cardIds.forEach((id, index) => rank.set(id, index));

  return [...cardIds].sort((left, right) => {
    const leftWeak = scoreOf(left, difficulties);
    const rightWeak = scoreOf(right, difficulties);
    if (leftWeak !== rightWeak) return rightWeak - leftWeak;
    return (rank.get(left) ?? 0) - (rank.get(right) ?? 0);
  });
}

function scoreOf(id: string, difficulties: ReadonlyMap<string, CardDifficulty>): number {
  const difficulty = difficulties.get(id);
  if (!difficulty || !isWeak(difficulty)) return 0;
  return weakness(difficulty);
}

/**
 * La solidité d'une carte devant une épreuve, entre 0 et 1.
 *
 * L'état et l'intervalle disent ce que l'algorithme croit ; le journal dit ce qui s'est
 * réellement passé. On part du premier et on le corrige par le second, parce qu'une carte
 * « acquise » ratée trois fois de suite ne l'est pas.
 */
export function cardReadiness(
  card: { state: CardState; intervalDays: number },
  difficulty: CardDifficulty | undefined,
): number {
  const base =
    card.state === "new"
      ? 0
      : card.state === "learning" || card.state === "relearning"
        ? 0.35
        : isMature(card.intervalDays)
          ? 0.95
          : 0.7;
  if (!difficulty || difficulty.reviews < MIN_REVIEWS_FOR_WEAKNESS) return base;
  return clamp01(base * (1 - weakness(difficulty) * 0.8));
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(1, value));
}
