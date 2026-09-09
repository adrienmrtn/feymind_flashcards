/**
 * La file de révision : ce qu'on sert, et dans quel ordre. Porté depuis
 * `Micabo/SRS/StudyQueue.swift`.
 *
 * **Il n'y a plus de plafond.** La file servait au plus N cartes neuves par jour, N déduit
 * d'un budget de minutes déclaré au réglage. Deux choses n'allaient pas. La première : le
 * chiffre était faux pour tout le monde, puisque personne ne révise le même nombre de minutes
 * d'un jour à l'autre. La seconde, plus grave : un étudiant à trois jours d'un partiel se
 * voyait refuser des cartes de ce partiel parce qu'il avait « atteint son rythme ». Un
 * produit qui retient du travail le jour où il en faut le plus se trompe de métier.
 *
 * Ce qui est dû est donc servi, en entier. L'ordre, lui, compte plus que jamais, parce qu'il
 * est désormais la seule chose qui distingue une file utile d'un tas :
 *
 * 1. **ce qui est en cours d'apprentissage**, par échéance : une carte ratée il y a dix
 *    minutes doit revenir avant tout le reste, sinon elle est perdue ;
 * 2. **les révisions**, l'échéance d'examen la plus proche d'abord ;
 * 3. **les cartes neuves**, celles d'un examen déclaré avant les autres, puis dans l'ordre
 *    du cours.
 */

import { NO_DEADLINES, type ExamDeadlines } from "./exam";
import type { CardState } from "./types";

export interface QueueCard {
  id: string;
  state: CardState;
  dueDate: Date;
  position: number;
  createdAt: Date;
  isSuspended: boolean;
}

export interface StudyCounts {
  newCards: number;
  learning: number;
  review: number;
  total: number;
}

export function isDue(card: QueueCard, now: Date): boolean {
  if (card.isSuspended) return false;
  return card.dueDate.getTime() <= now.getTime();
}

export function buildQueue(
  cards: QueueCard[],
  options: { now?: Date; deadlines?: ExamDeadlines } = {},
): QueueCard[] {
  const now = options.now ?? new Date();
  const deadlines = options.deadlines ?? NO_DEADLINES;

  const due = cards.filter((card) => isDue(card, now));

  const learning = due
    .filter((card) => card.state === "learning" || card.state === "relearning")
    .sort((first, second) => first.dueDate.getTime() - second.dueDate.getTime());

  const reviews = due
    .filter((card) => card.state === "review")
    .sort((first, second) =>
      byDeadline(
        deadlines.get(first.id) ?? null,
        first.dueDate,
        deadlines.get(second.id) ?? null,
        second.dueDate,
      ),
    );

  const newCards = due.filter((card) => card.state === "new");
  const examNewCards = newCards.filter((card) => deadlines.has(card.id)).sort(byPosition);
  const otherNewCards = newCards.filter((card) => !deadlines.has(card.id)).sort(byPosition);

  return [...learning, ...reviews, ...examNewCards, ...otherNewCards];
}

export function studyCounts(
  cards: QueueCard[],
  options: { now?: Date; deadlines?: ExamDeadlines } = {},
): StudyCounts {
  const queue = buildQueue(cards, options);
  const newCards = queue.filter((card) => card.state === "new").length;
  const learning = queue.filter(
    (card) => card.state === "learning" || card.state === "relearning",
  ).length;
  const review = queue.filter((card) => card.state === "review").length;
  return { newCards, learning, review, total: newCards + learning + review };
}

function byPosition(first: QueueCard, second: QueueCard): number {
  if (first.position !== second.position) return first.position - second.position;
  return first.createdAt.getTime() - second.createdAt.getTime();
}

/**
 * Une carte qui compte pour un examen proche passe devant, et à échéance égale c'est la plus
 * en retard qui passe. Une carte sans examen passe après toutes celles qui en ont un.
 */
function byDeadline(
  firstDeadline: Date | null,
  firstDue: Date,
  secondDeadline: Date | null,
  secondDue: Date,
): number {
  if (firstDeadline && secondDeadline) {
    if (firstDeadline.getTime() === secondDeadline.getTime()) {
      return firstDue.getTime() - secondDue.getTime();
    }
    return firstDeadline.getTime() - secondDeadline.getTime();
  }
  if (firstDeadline) return -1;
  if (secondDeadline) return 1;
  return firstDue.getTime() - secondDue.getTime();
}
