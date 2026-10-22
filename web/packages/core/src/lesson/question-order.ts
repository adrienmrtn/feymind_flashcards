import { SeededGenerator, pickingSeed, shuffled } from "./picking";
import type { QuizQuestion } from "./types";

/**
 * **L'ordre d'affichage des propositions**, mélangées selon une graine : une question qui
 * revient ne présente pas sa bonne réponse au même rang, et l'élève apprend la réponse, pas sa
 * place. La même graine redonne le même ordre : une question relue se relit pareil. Jumeau
 * des tirages de `QuestionCard.swift`.
 */

const MASK = (1n << 64n) - 1n;

function indices(count: number): number[] {
  return Array.from({ length: count }, (_, index) => index);
}

function isIdentity(order: readonly number[]): boolean {
  return order.every((value, index) => value === index);
}

/** Un QCM, un vrai/faux ou une phrase à trou : `order[i]` est le rang, dans `choices`, de la proposition montrée en `i`. */
export function choiceOrder(question: QuizQuestion, seed: bigint): number[] {
  if (seed === 0n) return indices(question.choices.length);
  const generator = new SeededGenerator((seed ^ pickingSeed(question.id)) & MASK);
  return shuffled(indices(question.choices.length), generator);
}

/** Remettre dans l'ordre : le mélange de départ, jamais dans le bon ordre. */
export function orderPool(question: QuizQuestion, seed: bigint): number[] {
  const generator = new SeededGenerator(seed === 0n ? 7n : seed);
  const order = shuffled(indices(question.choices.length), generator);
  if (isIdentity(order) && order.length > 1) [order[0], order[1]] = [order[1]!, order[0]!];
  return order;
}

/** Associer : l'ordre des définitions de droite, jamais celui des termes de gauche. */
export function matchRightOrder(question: QuizQuestion, seed: bigint): number[] {
  const generator = new SeededGenerator(((seed === 0n ? 11n : seed) + 3n) & MASK);
  const order = shuffled(indices(question.matches.length), generator);
  if (isIdentity(order) && order.length > 1) [order[0], order[1]] = [order[1]!, order[0]!];
  return order;
}

/** Une graine neuve à chaque ouverture d'un quiz, jamais nulle. */
export function randomSeed(): bigint {
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  let seed = 0n;
  for (const byte of bytes) seed = (seed << 8n) | BigInt(byte);
  return seed === 0n ? 1n : seed;
}
