/**
 * SM-2 d'Anki, **réglages legacy par défaut**, porté depuis `Micabo/SRS/SM2Scheduler.swift`.
 *
 * Pas une approximation : les paliers, les boutons, la facilité et le réapprentissage
 * sont ceux d'Anki 2.1 (schedv2 / « SM-2 »). Une révision faite sur le téléphone
 * doit compter sur le web, et réciproquement.
 *
 * Les seules libertés de forme : le tirage de la dispersion est injectable, pour
 * qu'un test puisse le fixer sans drapeau.
 */

import {
  type CardSnapshot,
  type CardState,
  type ScheduleOutcome,
  ReviewRating,
  REVIEW_RATINGS,
} from "./types";

export interface SchedulerConfig {
  learningStepsMinutes: number[];
  relearningStepsMinutes: number[];
  graduatingIntervalDays: number;
  easyIntervalDays: number;
  startingEase: number;
  easyBonus: number;
  hardMultiplier: number;
  intervalModifier: number;
  /** Pourcentage de l'ancien intervalle conservé après une rechute (0 % chez Anki). */
  lapseIntervalMultiplier: number;
  minimumIntervalDays: number;
  maximumIntervalDays: number;
  minimumEase: number;
  leechThreshold: number;
  /** Dispersion aléatoire des échéances, désactivée dans les tests et les aperçus. */
  fuzzEnabled: boolean;
}

/**
 * Deck options d'Anki, SM-2 legacy, telles quelles.
 *
 * Apprentissage `1 10`, diplôme 1 j, facile 4 j, facilité 2,5.
 * Rechutes : un seul palier de 10 minutes, nouvel intervalle 0 %, minimum 1 j.
 */
export const DEFAULT_CONFIG: SchedulerConfig = {
  learningStepsMinutes: [1, 10],
  relearningStepsMinutes: [10],
  graduatingIntervalDays: 1,
  easyIntervalDays: 4,
  startingEase: 2.5,
  easyBonus: 1.3,
  hardMultiplier: 1.2,
  intervalModifier: 1.0,
  lapseIntervalMultiplier: 0,
  minimumIntervalDays: 1,
  maximumIntervalDays: 36_500,
  minimumEase: 1.3,
  leechThreshold: 8,
  fuzzEnabled: true,
};

/** Variante déterministe, utilisée pour les aperçus d'intervalle et les tests. */
export const DETERMINISTIC_CONFIG: SchedulerConfig = { ...DEFAULT_CONFIG, fuzzEnabled: false };

export const MINUTE_SECONDS = 60;
export const DAY_SECONDS = 86_400;

export function newCardSnapshot(overrides: Partial<CardSnapshot> = {}): CardSnapshot {
  return {
    state: "new",
    intervalDays: 0,
    easeFactor: DEFAULT_CONFIG.startingEase,
    repetitions: 0,
    lapses: 0,
    stepIndex: 0,
    ...overrides,
  };
}

/** Délai réel, en secondes, avant la prochaine présentation de la carte. */
export function delaySeconds(outcome: ScheduleOutcome, now: Date): number {
  return (outcome.dueDate.getTime() - now.getTime()) / 1000;
}

interface ScheduleOptions {
  now?: Date;
  config?: SchedulerConfig;
  /** Échéance actuelle, pour le bonus de retard d'Anki. */
  dueDate?: Date | string | null;
  /** Tirage de la dispersion, dans `[0, 1)`. Injectable pour les tests. */
  random?: () => number;
}

export function schedule(
  snapshot: CardSnapshot,
  rating: ReviewRating,
  options: ScheduleOptions = {},
): ScheduleOutcome {
  const now = options.now ?? new Date();
  const config = options.config ?? DEFAULT_CONFIG;
  const random = options.random ?? Math.random;
  const late = daysLate(now, options.dueDate ?? snapshot.dueDate ?? null);

  switch (snapshot.state) {
    case "new":
    case "learning":
      return scheduleLearning(snapshot, rating, now, config, random);
    case "review":
      return scheduleReview(snapshot, rating, now, late, config, random);
    case "relearning":
      return scheduleRelearning(snapshot, rating, now, config, random);
  }
}

// MARK: - Apprentissage

/**
 * Les quatre boutons d'Anki sur une carte neuve : **1 min, 6 min, 10 min, 4 j.**
 *
 * Again revient au premier palier. Hard, au premier palier, est la moyenne des
 * deux premiers (5,5 min, lu 6 min) ; ensuite il rejoue le palier courant.
 * Good avance d'un palier, et ne diplôme qu'après le dernier. Easy diplôme
 * tout de suite à l'intervalle facile.
 */
function scheduleLearning(
  snapshot: CardSnapshot,
  rating: ReviewRating,
  now: Date,
  config: SchedulerConfig,
  random: () => number,
): ScheduleOutcome {
  const steps = stepsOf(config.learningStepsMinutes, [1, 10]);
  const step = clampedStep(snapshot.stepIndex, steps);

  if (rating === ReviewRating.easy) {
    return graduate(snapshot, rating, config.easyIntervalDays, now, config, random);
  }
  if (rating === ReviewRating.good && step >= steps.length - 1) {
    return graduate(snapshot, rating, config.graduatingIntervalDays, now, config, random);
  }
  if (rating === ReviewRating.good) {
    const next = step + 1;
    return stayInSteps(snapshot, rating, "learning", next, steps[next]!, now);
  }
  if (rating === ReviewRating.again) {
    return stayInSteps(snapshot, rating, "learning", 0, steps[0]!, now);
  }

  return stayInSteps(snapshot, rating, "learning", step, hardStepMinutes(steps, step), now);
}

function graduate(
  snapshot: CardSnapshot,
  rating: ReviewRating,
  intervalDays: number,
  now: Date,
  config: SchedulerConfig,
  random: () => number,
): ScheduleOutcome {
  return reviewOutcome(
    snapshot,
    rating,
    clampInterval(intervalDays, config),
    snapshot.easeFactor,
    now,
    config,
    random,
  );
}

// MARK: - Révision

function scheduleReview(
  snapshot: CardSnapshot,
  rating: ReviewRating,
  now: Date,
  late: number,
  config: SchedulerConfig,
  random: () => number,
): ScheduleOutcome {
  const previous = Math.max(snapshot.intervalDays, config.minimumIntervalDays);
  const ease = snapshot.easeFactor;

  if (rating === ReviewRating.again) {
    const steps = stepsOf(config.relearningStepsMinutes, [10]);
    const postLapse = constrainedIvl(
      Math.max(config.minimumIntervalDays, previous * config.lapseIntervalMultiplier),
      0,
      config,
    );
    return {
      rating,
      state: "relearning",
      dueDate: advanced(now, steps[0]! * MINUTE_SECONDS),
      intervalDays: postLapse,
      easeFactor: clampEase(ease - 0.2, config),
      repetitions: snapshot.repetitions,
      lapses: snapshot.lapses + 1,
      stepIndex: 0,
    };
  }

  const hardIvl = constrainedIvl(previous * config.hardMultiplier, previous, config);
  const goodIvl = constrainedIvl((previous + late / 2) * ease, hardIvl, config);
  const easyIvl = constrainedIvl((previous + late) * ease * config.easyBonus, goodIvl, config);

  let nextEase = ease;
  let interval = goodIvl;
  if (rating === ReviewRating.hard) {
    nextEase = clampEase(ease - 0.15, config);
    interval = hardIvl;
  } else if (rating === ReviewRating.easy) {
    nextEase = clampEase(ease + 0.15, config);
    interval = easyIvl;
  }

  return reviewOutcome(snapshot, rating, interval, nextEase, now, config, random);
}

/** Échéance de révision : Anki stocke l'intervalle déjà dispersé. */
function reviewOutcome(
  snapshot: CardSnapshot,
  rating: ReviewRating,
  intervalDays: number,
  easeFactor: number,
  now: Date,
  config: SchedulerConfig,
  random: () => number,
): ScheduleOutcome {
  const shown = fuzzed(intervalDays, config, random);
  return {
    rating,
    state: "review",
    dueDate: advanced(now, shown * DAY_SECONDS),
    intervalDays: shown,
    easeFactor: clampEase(easeFactor, config),
    repetitions: snapshot.repetitions + 1,
    lapses: snapshot.lapses,
    stepIndex: 0,
  };
}

// MARK: - Réapprentissage

/**
 * Un seul palier de dix minutes, comme Anki. Good diplôme à l'intervalle
 * post-rechute. Easy ajoute un jour. Hard, palier unique, vaut 1,5 × 10 min.
 */
function scheduleRelearning(
  snapshot: CardSnapshot,
  rating: ReviewRating,
  now: Date,
  config: SchedulerConfig,
  random: () => number,
): ScheduleOutcome {
  const steps = stepsOf(config.relearningStepsMinutes, [10]);
  const step = clampedStep(snapshot.stepIndex, steps);
  const postLapse = Math.max(snapshot.intervalDays, config.minimumIntervalDays);

  if (rating === ReviewRating.easy) {
    return graduate(snapshot, rating, postLapse + 1, now, config, random);
  }
  if (rating === ReviewRating.good && step >= steps.length - 1) {
    return graduate(snapshot, rating, postLapse, now, config, random);
  }
  if (rating === ReviewRating.good) {
    const next = step + 1;
    return stayInSteps(snapshot, rating, "relearning", next, steps[next]!, now);
  }
  if (rating === ReviewRating.again) {
    return stayInSteps(snapshot, rating, "relearning", 0, steps[0]!, now);
  }

  return stayInSteps(snapshot, rating, "relearning", step, hardStepMinutes(steps, step), now);
}

function stayInSteps(
  snapshot: CardSnapshot,
  rating: ReviewRating,
  state: Extract<CardState, "learning" | "relearning">,
  stepIndex: number,
  minutes: number,
  now: Date,
): ScheduleOutcome {
  return {
    rating,
    state,
    dueDate: advanced(now, minutes * MINUTE_SECONDS),
    intervalDays: snapshot.intervalDays,
    easeFactor: snapshot.easeFactor,
    repetitions: snapshot.repetitions,
    lapses: snapshot.lapses,
    stepIndex,
  };
}

// MARK: - Utilitaires

export function isLeech(lapses: number, config: SchedulerConfig = DEFAULT_CONFIG): boolean {
  return lapses >= config.leechThreshold;
}

/**
 * Hard en apprentissage, tel qu'Anki le documente.
 *
 * Premier palier : moyenne des deux premiers. Palier unique : 1,5×, au plus
 * un jour de plus. Ensuite : on rejoue le palier courant.
 */
export function hardStepMinutes(steps: number[], stepIndex: number): number {
  const step = clampedStep(stepIndex, steps);
  if (steps.length <= 1) {
    const only = steps[0] ?? 10;
    return Math.min(only * 1.5, only + 1_440);
  }
  if (step <= 0) return (steps[0]! + steps[1]!) / 2;
  return steps[step]!;
}

function stepsOf(configured: number[], fallback: number[]): number[] {
  return configured.length > 0 ? configured : fallback;
}

function clampedStep(index: number, steps: number[]): number {
  if (steps.length === 0) return 0;
  return Math.min(Math.max(0, Math.round(index)), steps.length - 1);
}

function daysLate(now: Date, due: Date | string | null | undefined): number {
  if (!due) return 0;
  const at = due instanceof Date ? due : new Date(due);
  if (Number.isNaN(at.getTime())) return 0;
  return Math.max(0, Math.floor((now.getTime() - at.getTime()) / (DAY_SECONDS * 1000)));
}

function advanced(from: Date, seconds: number): Date {
  return new Date(from.getTime() + seconds * 1000);
}

function clampEase(ease: number, config: SchedulerConfig): number {
  return Math.max(config.minimumEase, ease);
}

function clampInterval(interval: number, config: SchedulerConfig): number {
  return Math.min(config.maximumIntervalDays, Math.max(config.minimumIntervalDays, interval));
}

/** Intervalle de révision d'Anki : entier, toujours plus grand que le précédent. */
function constrainedIvl(raw: number, previous: number, config: SchedulerConfig): number {
  const ivl = Math.trunc(raw * config.intervalModifier);
  return clampInterval(Math.max(ivl, previous + 1, 1), config);
}

/**
 * Dispersion d'Anki (`_fuzzIvlRange`) : entier, et c'est cet entier qui est
 * stocké. Sans ça, le prochain passage re-multiplierait un intervalle « propre »
 * que la carte n'a jamais eu.
 */
function fuzzIvlRange(intervalDays: number): [number, number] {
  const ivl = Math.trunc(intervalDays);
  if (ivl < 2) return [1, 1];
  if (ivl === 2) return [2, 3];
  let fuzz: number;
  if (ivl < 7) fuzz = Math.trunc(ivl * 0.25);
  else if (ivl < 30) fuzz = Math.max(2, Math.trunc(ivl * 0.15));
  else fuzz = Math.max(4, Math.trunc(ivl * 0.05));
  fuzz = Math.max(fuzz, 1);
  return [ivl - fuzz, ivl + fuzz];
}

function fuzzed(intervalDays: number, config: SchedulerConfig, random: () => number): number {
  if (!config.fuzzEnabled) return intervalDays;
  const [min, max] = fuzzIvlRange(intervalDays);
  const span = max - min + 1;
  const unit = Math.min(0.999_999_999, Math.max(0, random()));
  return clampInterval(min + Math.floor(unit * span), config);
}

// MARK: - Aperçu des boutons

/**
 * Rabat l'échéance calculée sur la date butoir d'un examen.
 *
 * Trois refus, et chacun compte. Un **palier d'apprentissage** se mesure en minutes : le
 * rabattre sur un jour lointain casserait l'apprentissage au lieu de l'accélérer. Une
 * échéance **déjà en deçà** de la butoir n'a rien à corriger. Et à **moins de vingt-quatre
 * heures** de l'examen, il n'y a plus de planning à faire : rabattre ferait revenir la carte
 * dans la minute, en boucle.
 */
export function clampedToDeadline(
  outcome: ScheduleOutcome,
  deadline: Date | null | undefined,
  now: Date,
): ScheduleOutcome {
  if (!deadline) return outcome;
  if (outcome.state !== "review") return outcome;
  if (outcome.dueDate.getTime() <= deadline.getTime()) return outcome;

  const untilDeadlineSeconds = (deadline.getTime() - now.getTime()) / 1000;
  if (untilDeadlineSeconds < DAY_SECONDS) return outcome;

  return {
    ...outcome,
    dueDate: deadline,
    intervalDays: Math.max(1, Math.round((untilDeadlineSeconds / DAY_SECONDS) * 100) / 100),
  };
}

/**
 * Libellés sous les boutons de maîtrise.
 *
 * La date butoir d'un examen, quand il y en a une, est appliquée avant l'affichage : un
 * bouton qui annonce trois semaines alors que la carte reviendra dans quatre jours mentirait,
 * et c'est le seul endroit du produit où l'on lit un intervalle.
 */
export function previewLabels(
  snapshot: CardSnapshot,
  options: {
    now?: Date;
    config?: SchedulerConfig;
    deadline?: Date | null;
    dueDate?: Date | string | null;
  } = {},
): Record<ReviewRating, string> {
  const now = options.now ?? new Date();
  const config = options.config ?? DETERMINISTIC_CONFIG;
  const labels = {} as Record<ReviewRating, string>;

  for (const rating of REVIEW_RATINGS) {
    const outcome = clampedToDeadline(
      schedule(snapshot, rating, { now, config, dueDate: options.dueDate ?? snapshot.dueDate }),
      options.deadline,
      now,
    );
    labels[rating] = formatDelay(delaySeconds(outcome, now));
  }

  return labels;
}

/** « < 1 min », « 10 min », « 2 h », « 4 j », « 3 mois », « 2 ans ». */
export function formatDelay(seconds: number): string {
  const minutes = seconds / MINUTE_SECONDS;
  if (minutes < 1) return "< 1 min";
  if (minutes < 60) return `${Math.round(minutes)} min`;

  const hours = minutes / 60;
  if (hours < 24) return `${Math.round(hours)} h`;

  const days = hours / 24;
  if (days < 31) return `${Math.round(days)} j`;

  const months = days / 30.4;
  if (months < 12) return `${Math.round(months)} mois`;

  const years = days / 365;
  const value = Math.round(years * 10) / 10;
  const plural = value >= 2 ? "s" : "";
  return Number.isInteger(value) ? `${value} an${plural}` : `${value} an${plural}`;
}

export type { CardSnapshot, CardState, ScheduleOutcome };
