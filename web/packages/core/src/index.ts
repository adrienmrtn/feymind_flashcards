/**
 * `@micabo/core` — les règles que l'iPhone et le web doivent partager.
 *
 * Tout ce qui est ici est **pur** : pas de réseau, pas de base de données, pas de React. C'est
 * la condition pour que ce soit vérifiable, et c'est ce qui permet aux tests de reprendre les
 * valeurs attendues de `MicaboTests/` telles quelles.
 *
 * Ce qui n'a pas sa place ici : tout ce qui dépend d'un rendu, d'une requête ou d'une session.
 */

// La fiche : le module canonique du serveur, et le parseur de balisage pour le rendu.
export {
  SHEET_LIMITS,
  ensureHighlights,
  markPassage,
  normalizeSheet,
  sheetToPlainText,
  stripInlineMarkup,
  type SheetBlock,
} from "./sheet/canonical";
export {
  containsInlineMarkup,
  parseInlineMarkup,
  type MarkupSpan,
} from "./sheet/markup";
export { stripEmDashes } from "./sheet/em-dashes";

// La répétition espacée.
export {
  MATURE_INTERVAL_DAYS,
  REVIEW_RATINGS,
  REVIEW_RATING_LABELS,
  ReviewRating,
  isMature,
  type CardSnapshot,
  type CardState,
  type ScheduleOutcome,
} from "./srs/types";
export {
  DAY_SECONDS,
  DEFAULT_CONFIG,
  DETERMINISTIC_CONFIG,
  MINUTE_SECONDS,
  clampedToDeadline,
  delaySeconds,
  formatDelay,
  isLeech,
  newCardSnapshot,
  previewLabels,
  schedule,
  type SchedulerConfig,
} from "./srs/sm2";
export {
  CARDS_PER_MINUTE,
  DAILY_MINUTES_STEPS,
  DAYS_PER_YEAR,
  DEFAULT_DAILY_MINUTES,
  MAXIMUM_DAILY_MINUTES,
  MINIMUM_DAILY_MINUTES,
  PACE_LABELS,
  REPETITIONS_PER_CARD,
  cardsPerYear,
  dailyMinutesLabel,
  minutesAtStepIndex,
  nearestStep,
  newCardsPerDay,
  paceFor,
  stepIndexFor,
  type Pace,
} from "./srs/daily-load";
export {
  DEFAULT_LIMITS,
  UNLIMITED,
  buildQueue,
  dailyLimits,
  isDue,
  studyCounts,
  type QueueCard,
  type QueueLimits,
  type StudyCounts,
} from "./srs/queue";

// Le mode examen.
export {
  BASE_PASSES,
  CLOSING_DAYS,
  EXAM_INTENSITY_LABELS,
  NO_DEADLINES,
  activeDeadlines,
  addDays,
  averageDailyLoad,
  busiestDay,
  dayDifference,
  isProjectionEmpty,
  ladder,
  orderedCards,
  passesFor,
  planExam,
  startOfDay,
  type DeadlineCard,
  type DeadlineExam,
  type ExamCard,
  type ExamDeadlines,
  type ExamIntensity,
  type ExamPlan,
  type ExamProjection,
} from "./srs/exam";

// La courbe de l'oubli, pour la page d'accueil.
export {
  HORIZON_DAYS,
  INTERVAL_LABELS,
  REVIEW_DAYS,
  curveWithMicabo,
  curveWithoutReview,
  intervalLabel,
  type CurvePoint,
} from "./retention";

// Le verrou du gratuit — aligné sur `ProAccess.swift`, construit mais pas armé.
export * as entitlement from "./entitlement";

// Les offres, dont le pourcentage d'économie est calculé et jamais écrit.
export * as pricing from "./pricing";

// Les deux palettes qui sont des données.
export {
  COURSE_ACCENTS,
  TILE_PASTELS,
  courseAccent,
  lightened,
  tilePastel,
} from "./palette";
