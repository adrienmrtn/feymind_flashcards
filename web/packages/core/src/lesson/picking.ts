import type { QuizQuestion } from "./types";
import { questionIsValid } from "./types";

/**
 * **Quelles questions, quelles cartes** — le tirage des Checkpoints, du Quiz final, du quiz
 * complet et de la révision. Jumeau de `Micabo/Features/Lesson/LessonPicking.swift`.
 *
 * Tout est pur et reproductible : le même tirage sort pour la même graine, ce qui rend une
 * reprise stable (on retrouve ses questions) et les tests exacts. Le générateur est celui de
 * l'app (SplitMix64, le mélange de Swift, le même hachage de graine) : une leçon ouverte sur
 * le site et sur l'iPhone pose le même quiz à la même tentative.
 */

/** Le Checkpoint d'un palier : cinq questions sur le palier… */
export const CIRCLE_QUIZ_COUNT = 5;
/** … et deux sur les paliers d'avant, pour ne pas les oublier (l'entrelacement). */
export const CHECKPOINT_REVIEW_COUNT = 2;
/** Le quiz complet et l'examen blanc : dix questions. */
export const FULL_QUIZ_COUNT = 10;
/** La révision des flashcards de la leçon : dix cartes. */
export const CIRCLE_CARD_COUNT = 10;

/** Le Quiz final : deux questions par thème, entre huit et douze. */
export function finalQuizCount(themes: number): number {
  return Math.min(12, Math.max(8, themes * 2));
}

// MARK: - Le générateur

const MASK = (1n << 64n) - 1n;

/** FNV-1a sur les octets UTF-8 : le même nombre partout, à chaque lancement. */
export function stableHash(text: string): bigint {
  let hash = 0xcbf29ce484222325n;
  for (const byte of new TextEncoder().encode(text)) {
    hash ^= BigInt(byte);
    hash = (hash * 0x100000001b3n) & MASK;
  }
  return hash;
}

/** Une graine qui change à chaque tentative, stable pour une même tentative. */
export function pickingSeed(...parts: string[]): bigint {
  return stableHash(parts.join("|"));
}

/** SplitMix64 : un générateur reproductible, celui de `SeededGenerator` côté Swift. */
export class SeededGenerator {
  private state: bigint;

  constructor(seed: bigint | number) {
    this.state = BigInt(seed) & MASK;
  }

  next(): bigint {
    this.state = (this.state + 0x9e3779b97f4a7c15n) & MASK;
    let z = this.state;
    z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & MASK;
    z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & MASK;
    return z ^ (z >> 31n);
  }

  /** Un entier dans `0..<upperBound`, comme `Int.random(in:using:)` : la méthode de Lemire. */
  below(upperBound: number): number {
    const bound = BigInt(upperBound);
    if (bound <= 0n) return 0;
    let random = this.next();
    let product = random * bound;
    let low = product & MASK;
    if (low < bound) {
      const threshold = ((1n << 64n) - bound) % bound;
      while (low < threshold) {
        random = this.next();
        product = random * bound;
        low = product & MASK;
      }
    }
    return Number(product >> 64n);
  }
}

/** Le mélange de Swift (`shuffle(using:)`), pour que le site tire comme l'app. */
export function shuffled<T>(items: readonly T[], generator: SeededGenerator): T[] {
  const out = [...items];
  let amount = out.length;
  let current = 0;
  while (amount > 1) {
    const random = generator.below(amount);
    amount -= 1;
    const other = current + random;
    [out[current], out[other]] = [out[other]!, out[current]!];
    current += 1;
  }
  return out;
}

// MARK: - Les questions

/** Du plus simple au plus exigeant, sans changer l'ordre entre questions de même difficulté. */
export function progressive(questions: readonly QuizQuestion[]): QuizQuestion[] {
  return questions
    .map((question, index) => ({ question, index }))
    .sort((a, b) => a.question.difficulty - b.question.difficulty || a.index - b.index)
    .map((entry) => entry.question);
}

/**
 * **Les questions d'un quiz.** Les ratées d'abord (les plus récentes en tête), puis les
 * questions de réserve tirées en alternant les thèmes, pour qu'aucun ne soit oublié ; les
 * questions de fin ne servent que si la réserve ne suffit pas.
 *
 * @param themes par thème couvert, ses questions (la première est celle de fin).
 * @param missed les questions ratées, des plus anciennes aux plus récentes.
 */
export function pickQuiz(
  themes: readonly (readonly QuizQuestion[])[],
  missed: readonly string[],
  count: number,
  seed: bigint,
): QuizQuestion[] {
  const generator = new SeededGenerator(seed);
  const all = themes.flat().filter(questionIsValid);
  const picked: QuizQuestion[] = [];
  const used = new Set<string>();

  for (const id of [...missed].reverse()) {
    if (picked.length >= count) break;
    const question = all.find((candidate) => candidate.id === id);
    if (question && !used.has(id)) {
      picked.push(question);
      used.add(id);
    }
  }

  const roundRobin = (pools: readonly (readonly QuizQuestion[])[]) => {
    const remaining = pools.map((pool) =>
      shuffled(pool.filter((question) => !used.has(question.id) && questionIsValid(question)), generator),
    );
    let progressed = true;
    while (picked.length < count && progressed) {
      progressed = false;
      for (const pool of remaining) {
        if (picked.length >= count) break;
        const question = pool.shift();
        if (!question) continue;
        picked.push(question);
        used.add(question.id);
        progressed = true;
      }
    }
  };

  roundRobin(themes.map((pool) => pool.slice(1)));
  roundRobin(themes.map((pool) => pool.slice(0, 1)));
  return picked;
}

// MARK: - Les cartes

/** Ce que le tirage des cartes sait d'une carte. */
export interface CardCandidate {
  id: string;
  /** Une question de quiz ratée, devenue carte : elle passe en premier. */
  isMissedQuestion: boolean;
  isDue: boolean;
  isNew: boolean;
  position: number;
}

/**
 * **Les dix cartes d'une révision** : les questions ratées d'abord, puis les cartes dues,
 * puis les neuves dans l'ordre de la leçon, puis un tirage du reste.
 */
export function pickCards(candidates: readonly CardCandidate[], count: number, seed: bigint): string[] {
  const generator = new SeededGenerator(seed);
  const picked: string[] = [];
  const used = new Set<string>();
  const take = (list: readonly CardCandidate[]) => {
    for (const candidate of list) {
      if (picked.length >= count) break;
      if (used.has(candidate.id)) continue;
      picked.push(candidate.id);
      used.add(candidate.id);
    }
  };
  take([...candidates.filter((card) => card.isMissedQuestion)].sort((a, b) => b.position - a.position));
  take(shuffled(candidates.filter((card) => card.isDue && !card.isNew), generator));
  take([...candidates.filter((card) => card.isNew)].sort((a, b) => a.position - b.position));
  take(shuffled(candidates, generator));
  return picked;
}
