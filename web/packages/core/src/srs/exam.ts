/**
 * Le mode examen : le plan, et le plafond qui le tient.
 *
 * Porté depuis `Micabo/SRS/ExamPlanner.swift` et `Micabo/SRS/ExamDeadlines.swift`.
 *
 * **Le problème.** La répétition espacée optimise la mémoire à long terme : elle repousse les
 * cartes de plus en plus loin, et se fiche de la date du contrôle. Une carte revue hier avec
 * un intervalle de vingt jours retombera trois semaines après l'examen, au pire moment.
 *
 * **Le principe.** On garde la répétition espacée, mais on lui donne une date butoir. Deux
 * mécanismes complémentaires : la replanification initiale (ici) redistribue les prochaines
 * échéances sur les jours qui restent ; le plafond d'intervalle (`clampedToDeadline`, dans
 * `sm2.ts`) empêche la première note donnée de renvoyer la carte au-delà du jour J.
 *
 * Tout est en jours locaux : un examen est une date, pas un instant. Les décalages se
 * comptent depuis le début de la journée, comme le fait `MicaboCalendar` côté iOS.
 */

import { isMature, type CardState } from "./types";

export type ExamIntensity = "light" | "standard" | "intense";

/**
 * Passages de base, avant l'ajustement dû à l'état de la carte. Deux pour un chapitre déjà
 * su, trois pour un contrôle ordinaire, quatre pour un examen qui compte.
 */
export const BASE_PASSES: Record<ExamIntensity, number> = {
  light: 2,
  standard: 3,
  intense: 4,
};

export const EXAM_INTENSITY_LABELS: Record<ExamIntensity, string> = {
  light: "Légère",
  standard: "Normale",
  intense: "Intensive",
};

export const EXAM_INTENSITIES: readonly ExamIntensity[] = ["light", "standard", "intense"];

/** Les visages du curseur d'intensité, dans le même ordre que les paliers. */
export const EXAM_INTENSITY_EMOJIS: Record<ExamIntensity, string> = {
  light: "😌",
  standard: "📘",
  intense: "🔥",
};

/**
 * Sur combien de jours de fin les derniers passages s'étalent.
 *
 * Tout mettre sur la veille garantirait le pic de rétention, et une session de trois cents
 * cartes que personne ne fait. Trois jours laissent la rétention très haute le jour J tout en
 * gardant des sessions faisables.
 */
export const CLOSING_DAYS = 3;

/** Une carte vue par le planificateur : des valeurs, pas une ligne de base de données. */
export interface ExamCard {
  id: string;
  state: CardState;
  intervalDays: number;
  dueDate: Date;
}

/** Ce que la replanification donnera, annoncé **avant** de l'appliquer. */
export interface ExamProjection {
  cardCount: number;
  /** Jours entiers d'ici l'examen. 0 signifie « aujourd'hui ». */
  daysRemaining: number;
  totalReviews: number;
  /** Charge par jour, indexée par décalage depuis aujourd'hui. */
  load: number[];
}

export interface ExamPlan {
  /** Le jour de l'examen, au début de la journée. */
  examDay: Date;
  /** Le premier jour de révision possible, c'est-à-dire aujourd'hui. */
  firstDay: Date;
  /** Le dernier jour de révision, c'est-à-dire la veille de l'examen. */
  lastReviewDay: Date;
  /** Nombre de journées utilisables, veille comprise. Toujours au moins 1. */
  windowDays: number;
  /** Par carte, ses jours de passage en décalage depuis `firstDay`. */
  days: Map<string, number[]>;
  projection: ExamProjection;
}

// MARK: - Jours

export function startOfDay(date: Date): Date {
  const result = new Date(date.getTime());
  result.setHours(0, 0, 0, 0);
  return result;
}

export function addDays(date: Date, days: number): Date {
  const result = new Date(date.getTime());
  result.setDate(result.getDate() + days);
  return result;
}

/** Jours entiers entre deux dates, en journées locales. */
export function dayDifference(from: Date, to: Date): number {
  const a = startOfDay(from);
  const b = startOfDay(to);
  return Math.round((b.getTime() - a.getTime()) / 86_400_000);
}

/**
 * « aujourd'hui », « demain », « J-5 », « passé » — le libellé d'iOS,
 * `Exam.countdownLabel()`.
 */
export function examCountdownLabel(daysRemaining: number): string {
  if (daysRemaining < 0) return "passé";
  if (daysRemaining === 0) return "aujourd'hui";
  if (daysRemaining === 1) return "demain";
  return `J-${daysRemaining}`;
}

/**
 * L'urgence d'un examen, pour colorer la carte du tableau de bord.
 *
 * Aujourd'hui et demain sont rouges : c'est trop tard pour improviser.
 * La semaine qui vient est ocre. Au-delà de trois semaines, on est encore
 * dans le vert — le plan a le temps de travailler.
 */
export type ExamUrgency = "critical" | "soon" | "upcoming" | "later" | "past";

export function examUrgency(daysRemaining: number): ExamUrgency {
  if (daysRemaining < 0) return "past";
  if (daysRemaining <= 1) return "critical";
  if (daysRemaining <= 7) return "soon";
  if (daysRemaining <= 21) return "upcoming";
  return "later";
}

// MARK: - Plan

export function planExam(
  cards: ExamCard[],
  examDate: Date,
  options: { now?: Date; intensity?: ExamIntensity } = {},
): ExamPlan {
  const now = options.now ?? new Date();
  const intensity = options.intensity ?? "standard";

  const today = startOfDay(now);
  const examDay = startOfDay(examDate);
  const daysRemaining = dayDifference(today, examDay);

  // On révise jusqu'à la veille : le jour de l'examen ne sert plus à apprendre. Un examen
  // aujourd'hui ou demain ne laisse qu'une journée, celle-ci.
  const window = Math.max(1, daysRemaining);
  const lastReviewDay = addDays(today, window - 1);

  const days = new Map<string, number[]>();
  const load = new Array<number>(window).fill(0);
  let total = 0;

  orderedCards(cards, now).forEach((card, index) => {
    const offsets = ladder(passesFor(card, intensity), window, index);
    days.set(card.id, offsets);
    total += offsets.length;
    for (const offset of offsets) {
      if (offset >= 0 && offset < load.length) load[offset] = load[offset]! + 1;
    }
  });

  return {
    examDay,
    firstDay: today,
    lastReviewDay,
    windowDays: window,
    days,
    projection: { cardCount: cards.length, daysRemaining, totalReviews: total, load },
  };
}

/**
 * L'ordre décide du décalage de chaque carte, donc du lissage de la charge. Les cartes en
 * retard passent devant, puis les neuves, puis les moins solides : si le temps manque, c'est
 * ce qui doit être vu d'abord.
 */
export function orderedCards(cards: ExamCard[], now: Date): ExamCard[] {
  return [...cards].sort((first, second) => {
    const firstDue = first.dueDate.getTime() <= now.getTime();
    const secondDue = second.dueDate.getTime() <= now.getTime();
    if (firstDue !== secondDue) return firstDue ? -1 : 1;

    const firstNew = first.state === "new";
    const secondNew = second.state === "new";
    if (firstNew !== secondNew) return firstNew ? -1 : 1;

    if (first.intervalDays !== second.intervalDays) {
      return first.intervalDays - second.intervalDays;
    }
    return first.id < second.id ? -1 : first.id > second.id ? 1 : 0;
  });
}

/** Combien de fois cette carte doit repasser avant l'examen. */
export function passesFor(card: ExamCard, intensity: ExamIntensity): number {
  let count = BASE_PASSES[intensity];
  // Une carte jamais vue doit d'abord être apprise, pas seulement rafraîchie.
  if (card.state === "new") count += 1;
  // Une carte acquise depuis trois semaines n'a pas besoin d'un passage de plus.
  if (isMature(card.intervalDays)) count -= 1;
  return Math.max(1, count);
}

/**
 * Les jours de passage d'une carte, en décalage depuis aujourd'hui.
 *
 * Trois règles, dans cet ordre. Le **dernier passage** tombe dans les derniers jours, décalé
 * d'une carte à l'autre pour ne pas empiler tout le jeu sur la veille. Le **premier** est
 * échelonné lui aussi, pour que le premier jour ne prenne pas tout. Entre les deux, les
 * passages sont **régulièrement espacés**, ce qui donne une charge quotidienne à peu près
 * constante, la seule qu'on puisse tenir.
 */
export function ladder(passes: number, window: number, phase: number): number[] {
  if (window <= 0) return [];

  const closing = Math.max(1, Math.min(window, CLOSING_DAYS));
  const last = Math.max(0, window - 1 - (phase % closing));

  // On ne peut pas voir une carte deux fois le même jour : le nombre de passages est borné
  // par le nombre de jours disponibles avant son dernier.
  const wanted = Math.max(1, Math.min(passes, last + 1));
  if (wanted <= 1) return [last];

  const span = Math.max(1, window - wanted + 1);
  const first = Math.min(last, phase % span);
  if (last <= first) return [last];

  const offsets: number[] = [];
  for (let step = 0; step < wanted; step += 1) {
    const position = first + ((last - first) * step) / (wanted - 1);
    const day = Math.round(position);
    if (offsets[offsets.length - 1] !== day) offsets.push(day);
  }
  if (offsets[offsets.length - 1] !== last) offsets.push(last);
  return offsets;
}

export function averageDailyLoad(projection: ExamProjection): number {
  if (projection.load.length === 0) return 0;
  return Math.round(projection.totalReviews / projection.load.length);
}

export function busiestDay(projection: ExamProjection): { offset: number; count: number } | null {
  let bestOffset = -1;
  let bestCount = 0;
  projection.load.forEach((count, offset) => {
    if (count > bestCount) {
      bestCount = count;
      bestOffset = offset;
    }
  });
  return bestOffset < 0 ? null : { offset: bestOffset, count: bestCount };
}

export function isProjectionEmpty(projection: ExamProjection): boolean {
  return projection.cardCount === 0 || projection.totalReviews === 0;
}

// MARK: - Échéances actives

/**
 * Par carte, le jour de l'examen le plus proche qui la concerne.
 *
 * Un examen passé ne contraint plus rien, et un examen déclaré mais non planifié n'a encore
 * rien demandé. Quand deux examens portent sur la même carte, c'est **le plus proche** qui
 * commande : c'est lui qu'on rate en premier.
 */
export type ExamDeadlines = ReadonlyMap<string, Date>;

export const NO_DEADLINES: ExamDeadlines = new Map();

export interface DeadlineExam {
  date: Date;
  isPlanned: boolean;
  courseIds: string[];
}

export interface DeadlineCard {
  id: string;
  courseId: string | null;
  isSuspended: boolean;
}

export function activeDeadlines(
  exams: DeadlineExam[],
  cards: DeadlineCard[],
  now: Date = new Date(),
): ExamDeadlines {
  const today = startOfDay(now);
  const cardsByCourse = new Map<string, DeadlineCard[]>();
  for (const card of cards) {
    if (card.isSuspended || !card.courseId) continue;
    const bucket = cardsByCourse.get(card.courseId);
    if (bucket) bucket.push(card);
    else cardsByCourse.set(card.courseId, [card]);
  }

  const byCard = new Map<string, Date>();

  for (const exam of exams) {
    if (!exam.isPlanned) continue;
    const examDay = startOfDay(exam.date);
    if (examDay.getTime() < today.getTime()) continue;

    for (const courseId of exam.courseIds) {
      for (const card of cardsByCourse.get(courseId) ?? []) {
        const existing = byCard.get(card.id);
        if (existing && existing.getTime() <= examDay.getTime()) continue;
        byCard.set(card.id, examDay);
      }
    }
  }

  return byCard;
}
