/**
 * L'examen blanc : **le seul moment où l'app mesure au lieu d'estimer.**
 *
 * Tout le reste du produit juge carte par carte. C'est la bonne échelle pour apprendre, et la
 * mauvaise pour prévoir une note : réussir quatre-vingts pour cent de ses cartes une par une,
 * chacune sortie de son contexte et revue le jour où l'algorithme la propose, ne dit pas qu'on
 * saura répondre à vingt questions d'affilée sur tout le programme, sans indice, en temps
 * imparti. C'est exactement l'écart que les étudiants découvrent le jour J.
 *
 * Un blanc ferme cet écart : un tirage sur **tout** le programme, un temps compté, un score.
 *
 * Deux conséquences dans le reste du code.
 *
 * - `planTerm` sait poser un second type de bloc. Un plan n'est plus une suite de « révise N
 *   cartes ».
 * - `examReadiness` préfère un score mesuré à une projection calculée. Une formule qui annonce
 *   88 % contre un blanc qui en donne 54 a tort, et c'est le blanc qu'il faut croire.
 */

import { dayDifference, startOfDay } from "./exam";
import type { ExamKind } from "./term";

/** Les jours avant l'épreuve où un blanc a un sens. */
export const MOCK_OFFSETS: readonly number[] = [7, 2];

/** En deçà, un blanc ne mesure rien : le tirage n'est pas représentatif. */
export const MIN_MOCK_QUESTIONS = 8;
export const DEFAULT_MOCK_QUESTIONS = 20;
export const MAX_MOCK_QUESTIONS = 60;

/** Minutes accordées par question. Un peu plus qu'une révision : on ne s'aide pas. */
export const MINUTES_PER_MOCK_QUESTION = 0.75;

/**
 * Les types d'épreuve qui méritent un blanc.
 *
 * Un contrôle de routine n'en demande pas - c'est du temps pris à la révision pour mesurer un
 * enjeu faible. Un oral non plus : on ne s'entraîne pas à parler avec des cartes.
 */
export function wantsMock(kind: ExamKind): boolean {
  return kind === "final" || kind === "mock" || kind === "midterm" || kind === "quiz";
}

/** Un blanc déjà passé, tel que le calcul le lit. */
export interface MockResult {
  id: string;
  examId: string | null;
  questionCount: number;
  correctCount: number;
  finishedAt: Date;
}

/** Le score d'un blanc, entre 0 et 100. */
export function mockScore(result: MockResult): number {
  if (result.questionCount <= 0) return 0;
  return Math.round((result.correctCount / result.questionCount) * 100);
}

/**
 * Combien de questions pour cette épreuve.
 *
 * Assez pour que le score veuille dire quelque chose, jamais plus du quart du programme :
 * un blanc qui passe tout le paquet est une session de révision déguisée, et il mange le
 * temps qu'il était censé mesurer.
 */
export function mockQuestionCount(cardCount: number): number {
  if (cardCount < MIN_MOCK_QUESTIONS) return 0;
  const quarter = Math.round(cardCount / 4);
  return Math.max(
    MIN_MOCK_QUESTIONS,
    Math.min(MAX_MOCK_QUESTIONS, Math.min(DEFAULT_MOCK_QUESTIONS, quarter)),
  );
}

export function mockMinutes(questionCount: number): number {
  return Math.max(5, Math.round(questionCount * MINUTES_PER_MOCK_QUESTION));
}

/** Un blanc que le plan pose sur un jour. */
export interface PlannedMock {
  examId: string;
  examName: string;
  /** Décalage depuis aujourd'hui. */
  offset: number;
  questionCount: number;
  minutes: number;
}

export interface MockPlanInput {
  exams: readonly {
    id: string;
    name: string;
    examDate: Date;
    kind: ExamKind;
    cardCount: number;
  }[];
  /** Les blancs déjà passés : on ne repose pas celui qui est fait. */
  done: readonly MockResult[];
  /** Capacités par décalage, en minutes. Un jour fermé ne reçoit pas de blanc. */
  capacities: readonly number[];
  now?: Date;
}

/**
 * Où poser les blancs.
 *
 * À J-7 on a encore le temps de corriger ce que le score révèle ; à J-2 on vérifie que la
 * correction a pris. Poser le premier plus tôt mesurerait un programme à moitié appris, et
 * plus tard ne laisserait rien à en faire.
 *
 * Un jour fermé décale le blanc vers le jour ouvert le plus proche **avant** l'épreuve : après,
 * il ne servirait plus à rien.
 */
export function planMocks(input: MockPlanInput): PlannedMock[] {
  const now = input.now ?? new Date();
  const today = startOfDay(now);
  const posed: PlannedMock[] = [];
  const taken = new Set<number>();

  for (const exam of input.exams) {
    if (!wantsMock(exam.kind)) continue;

    const questionCount = mockQuestionCount(exam.cardCount);
    if (questionCount === 0) continue;

    const daysRemaining = dayDifference(today, exam.examDate);
    if (daysRemaining < 0) continue;

    const alreadyDone = input.done.filter((result) => result.examId === exam.id);

    for (const [index, before] of MOCK_OFFSETS.entries()) {
      const wanted = daysRemaining - before;
      // Un blanc dont le jour est passé ne se rattrape pas : le suivant le remplace.
      if (wanted < 0) continue;
      // Un blanc par palier : celui de J-7 fait, on ne le repose pas.
      if (alreadyDone.length > index) continue;

      const offset = openDayFor(wanted, input.capacities, daysRemaining, taken);
      if (offset == null) continue;

      taken.add(offset);
      posed.push({
        examId: exam.id,
        examName: exam.name,
        offset,
        questionCount,
        minutes: mockMinutes(questionCount),
      });
    }
  }

  return posed.sort((left, right) => left.offset - right.offset);
}

/**
 * Le jour ouvert le plus proche du jour voulu, sans dépasser la veille de l'épreuve.
 *
 * On cherche d'abord avant : un blanc anticipé garde sa valeur, un blanc après l'épreuve n'en
 * a aucune. Deux blancs ne partagent pas un jour - en enchaîner deux ne mesure plus rien.
 */
function openDayFor(
  wanted: number,
  capacities: readonly number[],
  deadline: number,
  taken: ReadonlySet<number>,
): number | null {
  const last = Math.min(Math.max(0, deadline - 1), capacities.length - 1);

  for (let distance = 0; distance <= capacities.length; distance += 1) {
    for (const offset of distance === 0 ? [wanted] : [wanted - distance, wanted + distance]) {
      if (offset < 0 || offset > last) continue;
      if (taken.has(offset)) continue;
      if ((capacities[offset] ?? 0) <= 0) continue;
      return offset;
    }
  }
  return null;
}


// MARK: - Le tirage

export interface DrawCandidate {
  id: string;
  courseId: string | null;
  kind: string;
  isSuspended: boolean;
}

/**
 * Les cartes d'un blanc.
 *
 * **Un tirage, pas une file de révision.** La file sert ce qui est dû ; ici on veut un
 * échantillon de tout le programme, y compris ce qui est acquis - c'est justement ce qu'on
 * prétend savoir qu'il faut vérifier. L'ordre est déterministe pour une graine donnée, parce
 * qu'un blanc rechargé au milieu doit rendre les mêmes questions.
 */
export function drawMock(
  cards: readonly DrawCandidate[],
  courseIds: readonly string[],
  questionCount: number,
  seed: string,
): string[] {
  const scope = new Set(courseIds);
  const usable = cards.filter(
    (card) => !card.isSuspended && card.courseId && scope.has(card.courseId),
  );
  if (usable.length === 0) return [];

  const ranked = usable
    .map((card) => ({ id: card.id, rank: hash(`${seed}:${card.id}`) }))
    .sort((left, right) => (left.rank - right.rank) || (left.id < right.id ? -1 : 1));

  return ranked.slice(0, Math.min(questionCount, ranked.length)).map((entry) => entry.id);
}

/**
 * Somme stable : le même tirage sur deux appareils, pour la même graine.
 *
 * La somme naïve `h * 31 + c` ne suffit pas ici. Le préfixe commun à toutes les clés - la
 * graine - n'y contribue qu'un décalage constant, donc **changer de graine ne change pas
 * l'ordre** : deux blancs successifs poseraient les mêmes questions. FNV-1a suivi d'une
 * dispersion finale casse cette corrélation, ce qu'un test vérifie.
 */
function hash(value: string): number {
  let result = 0x811c9dc5;
  for (let index = 0; index < value.length; index += 1) {
    result ^= value.charCodeAt(index);
    result = Math.imul(result, 0x01000193);
  }
  result ^= result >>> 16;
  result = Math.imul(result, 0x85ebca6b);
  result ^= result >>> 13;
  return (result >>> 0) % 0x7fffffff;
}

// MARK: - Ce que le score change

/**
 * La préparation d'une épreuve : **le blanc l'emporte sur la formule.**
 *
 * Sans blanc, on ne peut que projeter - la maîtrise des cartes plus ce que le plan promet
 * d'ajouter. Dès qu'un blanc existe, on tient une mesure, et une mesure ne se discute pas
 * contre une estimation. Le mélange penche vers le blanc à mesure qu'il est récent : un score
 * d'il y a trois semaines a moins de valeur qu'une maîtrise d'aujourd'hui.
 */
export function examReadiness(input: {
  masteryPercent: number;
  projectedPercent: number;
  mocks: readonly MockResult[];
  examId: string;
  now?: Date;
}): { percent: number; measured: boolean; mockScore: number | null } {
  const now = input.now ?? new Date();
  const mine = input.mocks
    .filter((result) => result.examId === input.examId)
    .sort((left, right) => right.finishedAt.getTime() - left.finishedAt.getTime());

  const latest = mine[0];
  if (!latest) {
    return { percent: input.projectedPercent, measured: false, mockScore: null };
  }

  const score = mockScore(latest);
  const age = Math.max(0, dayDifference(startOfDay(latest.finishedAt), startOfDay(now)));
  // Un blanc du jour pèse quatre cinquièmes ; à trois semaines il ne pèse presque plus.
  const weight = 0.8 * Math.exp(-age / 14);

  return {
    percent: Math.round(score * weight + input.projectedPercent * (1 - weight)),
    measured: true,
    mockScore: score,
  };
}

/**
 * L'écart entre ce qu'on croit savoir et ce qu'on sait.
 *
 * Positif quand le blanc déçoit. C'est le chiffre le plus utile du produit à J-7 : il dit que
 * réviser plus ne suffira pas, et qu'il faut réviser autrement.
 */
export function readinessGap(masteryPercent: number, mock: MockResult): number {
  return masteryPercent - mockScore(mock);
}
