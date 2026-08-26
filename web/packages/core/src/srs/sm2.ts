/**
 * SM-2, porté depuis `Micabo/SRS/SM2Scheduler.swift`.
 *
 * **C'est le module qui justifie le monorepo.** Une révision faite sur le téléphone doit
 * compter sur le web, et réciproquement : deux copies de cette formule qui divergent d'un
 * dixième donnent une carte revue deux fois, ou pas du tout. Le port est donc littéral, et
 * `test/sm2.test.ts` reprend les valeurs attendues de `MicaboTests/SM2SchedulerTests.swift`
 * — les mêmes nombres, vérifiés des deux côtés.
 *
 * Les seules libertés prises par rapport au Swift sont de forme : le tirage aléatoire de la
 * dispersion est injectable, pour qu'un test puisse le fixer sans passer par un drapeau.
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

export const DEFAULT_CONFIG: SchedulerConfig = {
  learningStepsMinutes: [1, 10],
  // Une carte ratée après une révision repart du premier palier, comme une neuve : c'est
  // le même oubli, et le rattraper à dix minutes sans l'avoir revue à une minute laisse
  // passer une carte qu'on ne sait pas encore.
  relearningStepsMinutes: [1, 10],
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

  switch (snapshot.state) {
    case "new":
    case "learning":
      return scheduleLearning(snapshot, rating, now, config, random);
    case "review":
      return scheduleReview(snapshot, rating, now, config, random);
    case "relearning":
      return scheduleRelearning(snapshot, rating, now, config, random);
  }
}

// MARK: - Apprentissage

/**
 * Les quatre boutons d'une carte en apprentissage : **1 min, 10 min, 1 j, 4 j.**
 *
 * Anki rejoue le palier courant sur « Difficile », ce qui affiche « 1 min » sous deux
 * boutons voisins d'une carte neuve — deux fois la même promesse, dont une qui n'apprend
 * rien. Ici chaque note dit autre chose : on reprend au premier palier, on saute au
 * dernier, ou on sort de l'apprentissage.
 *
 * La conséquence assumée est que « Correct » **fait sortir** la carte de l'apprentissage
 * au lieu de la reposer dix minutes plus loin. Ce qui revient dans la session est donc ce
 * qu'on n'a pas su : c'est le sens des quatre boutons.
 */
function scheduleLearning(
  snapshot: CardSnapshot,
  rating: ReviewRating,
  now: Date,
  config: SchedulerConfig,
  random: () => number,
): ScheduleOutcome {
  const steps = stepsOf(config.learningStepsMinutes);

  if (rating === ReviewRating.good) {
    return graduate(snapshot, rating, config.graduatingIntervalDays, now, config, random);
  }
  if (rating === ReviewRating.easy) {
    return graduate(snapshot, rating, config.easyIntervalDays, now, config, random);
  }

  const index = rating === ReviewRating.again ? 0 : steps.length - 1;
  return {
    rating,
    state: "learning",
    dueDate: advanced(now, stepAt(steps, index) * MINUTE_SECONDS),
    intervalDays: snapshot.intervalDays,
    easeFactor: snapshot.easeFactor,
    repetitions: snapshot.repetitions,
    lapses: snapshot.lapses,
    stepIndex: index,
  };
}

function graduate(
  snapshot: CardSnapshot,
  rating: ReviewRating,
  intervalDays: number,
  now: Date,
  config: SchedulerConfig,
  random: () => number,
): ScheduleOutcome {
  const interval = clampInterval(intervalDays, config);
  return {
    rating,
    state: "review",
    dueDate: advanced(now, fuzzed(interval, config, random) * DAY_SECONDS),
    intervalDays: interval,
    easeFactor: clampEase(snapshot.easeFactor, config),
    repetitions: snapshot.repetitions + 1,
    lapses: snapshot.lapses,
    stepIndex: 0,
  };
}

// MARK: - Révision

function scheduleReview(
  snapshot: CardSnapshot,
  rating: ReviewRating,
  now: Date,
  config: SchedulerConfig,
  random: () => number,
): ScheduleOutcome {
  const previous = Math.max(snapshot.intervalDays, config.minimumIntervalDays);

  if (rating === ReviewRating.again) {
    const steps = stepsOf(config.relearningStepsMinutes);
    const postLapse = clampInterval(
      Math.max(config.minimumIntervalDays, previous * config.lapseIntervalMultiplier),
      config,
    );
    return {
      rating,
      state: "relearning",
      dueDate: advanced(now, stepAt(steps, 0) * MINUTE_SECONDS),
      intervalDays: postLapse,
      easeFactor: clampEase(snapshot.easeFactor - 0.2, config),
      repetitions: snapshot.repetitions,
      lapses: snapshot.lapses + 1,
      stepIndex: 0,
    };
  }

  let ease = snapshot.easeFactor;
  let interval: number;

  switch (rating) {
    case ReviewRating.hard:
      ease = clampEase(ease - 0.15, config);
      interval = previous * config.hardMultiplier * config.intervalModifier;
      break;
    case ReviewRating.good:
      ease = clampEase(ease, config);
      interval = previous * ease * config.intervalModifier;
      break;
    case ReviewRating.easy:
      ease = clampEase(ease + 0.15, config);
      interval = previous * ease * config.easyBonus * config.intervalModifier;
      break;
  }

  // Anki garantit qu'une réponse positive fait toujours grandir l'intervalle d'au moins un jour.
  interval = clampInterval(Math.max(interval, previous + 1), config);

  return {
    rating,
    state: "review",
    dueDate: advanced(now, fuzzed(interval, config, random) * DAY_SECONDS),
    intervalDays: interval,
    easeFactor: ease,
    repetitions: snapshot.repetitions + 1,
    lapses: snapshot.lapses,
    stepIndex: 0,
  };
}

// MARK: - Réapprentissage

/** Mêmes quatre paliers qu'en apprentissage : un oubli se rattrape de la même façon. */
function scheduleRelearning(
  snapshot: CardSnapshot,
  rating: ReviewRating,
  now: Date,
  config: SchedulerConfig,
  random: () => number,
): ScheduleOutcome {
  const steps = stepsOf(config.relearningStepsMinutes);
  const postLapse = Math.max(snapshot.intervalDays, config.minimumIntervalDays);

  if (rating === ReviewRating.good || rating === ReviewRating.easy) {
    const interval = clampInterval(
      rating === ReviewRating.easy ? postLapse + 1 : postLapse,
      config,
    );
    return {
      rating,
      state: "review",
      dueDate: advanced(now, fuzzed(interval, config, random) * DAY_SECONDS),
      intervalDays: interval,
      easeFactor: clampEase(snapshot.easeFactor, config),
      repetitions: snapshot.repetitions + 1,
      lapses: snapshot.lapses,
      stepIndex: 0,
    };
  }

  const index = rating === ReviewRating.again ? 0 : steps.length - 1;
  return {
    rating,
    state: "relearning",
    dueDate: advanced(now, stepAt(steps, index) * MINUTE_SECONDS),
    intervalDays: postLapse,
    easeFactor: clampEase(snapshot.easeFactor, config),
    repetitions: snapshot.repetitions,
    lapses: snapshot.lapses,
    stepIndex: index,
  };
}

// MARK: - Utilitaires

export function isLeech(lapses: number, config: SchedulerConfig = DEFAULT_CONFIG): boolean {
  return lapses >= config.leechThreshold;
}

function stepsOf(configured: number[]): number[] {
  return configured.length > 0 ? configured : [1, 10];
}

function stepAt(steps: number[], index: number): number {
  return steps[index] ?? 10;
}

function advanced(from: Date, seconds: number): Date {
  return new Date(from.getTime() + seconds * 1000);
}

function clampEase(ease: number, config: SchedulerConfig): number {
  return Math.max(config.minimumEase, ease);
}

function clampInterval(interval: number, config: SchedulerConfig): number {
  const rounded = Math.round(interval * 100) / 100;
  return Math.min(config.maximumIntervalDays, Math.max(config.minimumIntervalDays, rounded));
}

/** Dispersion d'Anki : évite que des paquets entiers retombent le même jour. */
function fuzzed(intervalDays: number, config: SchedulerConfig, random: () => number): number {
  if (!config.fuzzEnabled || intervalDays < 2.5) return intervalDays;

  let spread: number;
  if (intervalDays < 7) spread = Math.max(1, intervalDays * 0.15);
  else if (intervalDays < 30) spread = Math.max(2, intervalDays * 0.1);
  else spread = Math.max(4, intervalDays * 0.05);

  const offset = -spread + random() * (2 * spread);
  return Math.max(config.minimumIntervalDays, intervalDays + offset);
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
    // L'intervalle doit rester cohérent avec l'échéance : c'est lui qu'affichent les
    // statistiques, et lui que SM-2 reprendra au passage suivant.
    intervalDays: Math.max(1, Math.round((untilDeadlineSeconds / DAY_SECONDS) * 100) / 100),
  };
}

/**
 * Libellés « 1 min / 10 min / 1 j / 4 j » affichés sous les boutons de maîtrise.
 *
 * La date butoir d'un examen, quand il y en a une, est appliquée avant l'affichage : un
 * bouton qui annonce trois semaines alors que la carte reviendra dans quatre jours mentirait,
 * et c'est le seul endroit du produit où l'on lit un intervalle.
 */
export function previewLabels(
  snapshot: CardSnapshot,
  options: { now?: Date; config?: SchedulerConfig; deadline?: Date | null } = {},
): Record<ReviewRating, string> {
  const now = options.now ?? new Date();
  const config = options.config ?? DETERMINISTIC_CONFIG;
  const labels = {} as Record<ReviewRating, string>;

  for (const rating of REVIEW_RATINGS) {
    const outcome = clampedToDeadline(
      schedule(snapshot, rating, { now, config }),
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
