/**
 * La maîtrise : le seul chiffre du produit qui monte vers 100 %.
 *
 * Un tableau de bord d'app d'étude affiche d'habitude des volumes - cartes vues, jours de
 * série, minutes. Ce sont des chiffres d'activité : ils montent même quand rien n'est appris,
 * et ils ne répondent pas à la question que l'étudiant se pose la veille d'un partiel, qui
 * est **« est-ce que je sais mon cours ? »**.
 *
 * La maîtrise y répond, et elle a une propriété que les volumes n'ont pas : **elle a une
 * fin**. 100 % veut dire quelque chose - toutes les cartes du programme sont acquises et
 * aucune ne résiste - donc la barre est un objectif et pas un compteur.
 *
 * Elle se calcule sur trois entrées, dans cet ordre d'autorité : ce que l'étudiant a
 * réellement répondu (`review_logs`), l'intervalle atteint, l'état de la carte. Une carte
 * jamais vue vaut zéro, pas « en attente ».
 */

import { cardReadiness, type CardDifficulty } from "./weakness";
import { isMature, type CardState } from "./types";

/** Une carte vue par le calcul de maîtrise. */
export interface MasteryCard {
  id: string;
  courseId: string | null;
  state: CardState;
  intervalDays: number;
  isSuspended: boolean;
}

export interface Mastery {
  /** Entre 0 et 100, arrondi. C'est le chiffre affiché. */
  percent: number;
  cardCount: number;
  /** Cartes acquises : en révision et au-delà de la maturité. */
  solid: number;
  /** Cartes commencées mais pas encore acquises. */
  learning: number;
  /** Cartes jamais vues. */
  untouched: number;
  /** Cartes acquises sur le papier mais qui résistent au journal. */
  fragile: number;
}

export const EMPTY_MASTERY: Mastery = {
  percent: 0,
  cardCount: 0,
  solid: 0,
  learning: 0,
  untouched: 0,
  fragile: 0,
};

/**
 * La maîtrise d'un ensemble de cartes.
 *
 * La moyenne des solidités individuelles, pas la part de cartes acquises : une carte à mi-
 * chemin doit compter pour la moitié, sinon la barre reste à zéro pendant deux semaines puis
 * saute, ce qui ne se lit pas comme une progression.
 */
export function masteryOf(
  cards: readonly MasteryCard[],
  difficulties: ReadonlyMap<string, CardDifficulty>,
): Mastery {
  const usable = cards.filter((card) => !card.isSuspended);
  if (usable.length === 0) return EMPTY_MASTERY;

  let sum = 0;
  let solid = 0;
  let learning = 0;
  let untouched = 0;
  let fragile = 0;

  for (const card of usable) {
    const difficulty = difficulties.get(card.id);
    const readiness = cardReadiness(card, difficulty);
    sum += readiness;

    if (card.state === "new") untouched += 1;
    else if (card.state === "review" && isMature(card.intervalDays)) {
      if (readiness < 0.6) fragile += 1;
      else solid += 1;
    } else learning += 1;
  }

  return {
    percent: Math.round((sum / usable.length) * 100),
    cardCount: usable.length,
    solid,
    learning,
    untouched,
    fragile,
  };
}

/** La maîtrise par cours, pour l'étagère et le tableau de bord. */
export function masteryByCourse(
  cards: readonly MasteryCard[],
  difficulties: ReadonlyMap<string, CardDifficulty>,
): Map<string, Mastery> {
  const grouped = new Map<string, MasteryCard[]>();
  for (const card of cards) {
    if (!card.courseId) continue;
    const bucket = grouped.get(card.courseId);
    if (bucket) bucket.push(card);
    else grouped.set(card.courseId, [card]);
  }

  const result = new Map<string, Mastery>();
  for (const [courseId, group] of grouped) {
    result.set(courseId, masteryOf(group, difficulties));
  }
  return result;
}

/** La maîtrise restreinte à des cours, c'est-à-dire au programme d'une épreuve. */
export function masteryForCourses(
  cards: readonly MasteryCard[],
  difficulties: ReadonlyMap<string, CardDifficulty>,
  courseIds: readonly string[],
): Mastery {
  const scope = new Set(courseIds);
  return masteryOf(
    cards.filter((card) => card.courseId && scope.has(card.courseId)),
    difficulties,
  );
}

// MARK: - Les statistiques du tableau de bord

/** Un point de la courbe de révision : un jour, ce qui a été passé et raté. */
export interface DailyReview {
  day: Date;
  passes: number;
  againCount: number;
}

export interface StudyStats {
  /** Passages sur la période lue. */
  totalPasses: number;
  /** Part de réponses justes, entre 0 et 100. */
  accuracyPercent: number;
  /** Jours où au moins une carte a été passée. */
  activeDays: number;
  /** Série en cours, en jours consécutifs jusqu'à aujourd'hui. */
  streak: number;
  /** Meilleure série de la période. */
  bestStreak: number;
  /** Moyenne de passages sur les jours actifs. */
  averagePasses: number;
  /** Le meilleur jour de la période. */
  best: DailyReview | null;
}

export const EMPTY_STATS: StudyStats = {
  totalPasses: 0,
  accuracyPercent: 0,
  activeDays: 0,
  streak: 0,
  bestStreak: 0,
  averagePasses: 0,
  best: null,
};

/**
 * Ce que l'historique dit de l'étudiant.
 *
 * `accuracyPercent` est la statistique qui manquait : le volume dit combien on a travaillé, la
 * justesse dit si ça marche. C'est aussi elle qui rend la fragilité crédible - un étudiant à
 * 62 % de justesse comprend pourquoi des cartes lui reviennent sans arrêt.
 */
export function studyStats(
  daily: readonly DailyReview[],
  now: Date = new Date(),
): StudyStats {
  if (daily.length === 0) return EMPTY_STATS;

  const sorted = [...daily].sort((left, right) => left.day.getTime() - right.day.getTime());
  const totalPasses = sorted.reduce((sum, point) => sum + point.passes, 0);
  const totalAgain = sorted.reduce((sum, point) => sum + point.againCount, 0);
  const active = sorted.filter((point) => point.passes > 0);

  let best: DailyReview | null = null;
  for (const point of sorted) {
    if (!best || point.passes > best.passes) best = point;
  }

  return {
    totalPasses,
    accuracyPercent:
      totalPasses === 0 ? 0 : Math.round(((totalPasses - totalAgain) / totalPasses) * 100),
    activeDays: active.length,
    streak: currentStreak(active.map((point) => point.day), now),
    bestStreak: longestStreak(active.map((point) => point.day)),
    averagePasses: active.length === 0 ? 0 : Math.round(totalPasses / active.length),
    best: best && best.passes > 0 ? best : null,
  };
}

/**
 * La série en cours.
 *
 * Elle tient si l'on a révisé aujourd'hui **ou** hier : à dix heures du matin, quelqu'un qui a
 * révisé tous les jours depuis un mois n'a pas encore ouvert l'app, et lui annoncer que sa
 * série est retombée à zéro serait faux.
 */
export function currentStreak(days: readonly Date[], now: Date = new Date()): number {
  if (days.length === 0) return 0;
  const stamps = new Set(days.map((day) => dayKey(day)));
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  let cursor = new Date(today.getTime());
  if (!stamps.has(dayKey(cursor))) {
    cursor = new Date(cursor.getTime());
    cursor.setDate(cursor.getDate() - 1);
    if (!stamps.has(dayKey(cursor))) return 0;
  }

  let count = 0;
  while (stamps.has(dayKey(cursor))) {
    count += 1;
    cursor.setDate(cursor.getDate() - 1);
  }
  return count;
}

export function longestStreak(days: readonly Date[]): number {
  if (days.length === 0) return 0;
  const stamps = [...new Set(days.map((day) => dayKey(day)))].sort();

  let best = 1;
  let run = 1;
  for (let index = 1; index < stamps.length; index += 1) {
    const previous = new Date(`${stamps[index - 1]}T12:00:00`);
    const current = new Date(`${stamps[index]}T12:00:00`);
    const gap = Math.round((current.getTime() - previous.getTime()) / 86_400_000);
    run = gap === 1 ? run + 1 : 1;
    if (run > best) best = run;
  }
  return best;
}

function dayKey(date: Date): string {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, "0");
  const day = `${date.getDate()}`.padStart(2, "0");
  return `${year}-${month}-${day}`;
}
