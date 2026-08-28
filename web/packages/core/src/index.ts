/**
 * `@micabo/core` - les règles que l'iPhone et le web doivent partager.
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
export { latexCommandsToUnicode, latexToUnicode } from "./formula";

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
  SESSION_NEW_SLIDER_CAP,
  UNLIMITED,
  buildQueue,
  countNewIntroducedToday,
  dailyLimits,
  isDue,
  remainingNewCards,
  sessionNewLimit,
  sessionNewSliderMax,
  studyCounts,
  type NewIntroductionEvent,
  type QueueCard,
  type QueueLimits,
  type StudyCounts,
} from "./srs/queue";
export {
  LEARN_AHEAD_SECONDS,
  advanceSession,
  earliestAvailableAt,
  earliestIndex,
  enqueueInitial,
  returnsInSession,
  type SessionAdvance,
  type SessionEntry,
} from "./srs/session";
export {
  desiredGradeLabel,
  desiredGradeScale,
  gradeIndexFor,
  intensityFromGradeIndex,
  type DesiredGradeScale,
} from "./srs/grade-scale";

// Le mode examen.
export {
  BASE_PASSES,
  CLOSING_DAYS,
  EXAM_INTENSITIES,
  EXAM_INTENSITY_EMOJIS,
  EXAM_INTENSITY_LABELS,
  NO_DEADLINES,
  NO_EXAM_MARKS,
  activeDeadlines,
  activeExamMarks,
  addDays,
  averageDailyLoad,
  busiestDay,
  dayDifference,
  examCountdownLabel,
  examUrgency,
  isProjectionEmpty,
  ladder,
  orderedCards,
  passesFor,
  planExam,
  startOfDay,
  type DeadlineCard,
  type DeadlineExam,
  type ExamCard,
  type ExamMark,
  type ExamMarks,
  type ExamDeadlines,
  type ExamUrgency,
  type ExamIntensity,
  type ExamPlan,
  type ExamProjection,
} from "./srs/exam";

// Les séries, les niveaux de connaissance, et l'audience d'un cours.
export {
  KNOWLEDGE_LEVELS,
  KNOWLEDGE_LEVEL_LABELS,
  bestStreak,
  courseAudienceLabel,
  knowledgeDistribution,
  knowledgeLevel,
  mostReviewedCards,
  streak,
  weekStrip,
  WEEK_STRIP_RADIUS,
  type KnowledgeBucket,
  type KnowledgeCard,
  type KnowledgeLevel,
  type ReviewedCard,
  type WeekCard,
  type WeekDayLoad,
} from "./stats";

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

// Le verrou du gratuit - aligné sur `ProAccess.swift`, construit mais pas armé.
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

// Le parcours d'accueil : les pays, leurs paliers, les matières, et les emojis.
export {
  COUNTRIES,
  FALLBACK_COUNTRY,
  LANGUAGE_LABELS,
  CONTENT_LANGUAGES,
  countryFor,
  flagFor,
  isoFromFlagEmoji,
  guessCountry,
  isContentLanguage,
  languageFor,
  languageLabel,
  sheetLanguage,
  type ContentLanguage,
  type Country,
  type CountryCode,
} from "./onboarding/countries";
export {
  TIER_LADDER,
  resolveStage,
  stagesFor,
  type EducationStage,
  type EducationTier,
  type StudyLevel,
} from "./onboarding/stages";
export {
  ALL_SUBJECTS,
  SUBJECT_FAMILIES,
  subjectEmoji,
  type SubjectFamily,
} from "./onboarding/subjects";
export { examStoryFor, type ExamGrade, type ExamStory } from "./onboarding/exam-story";
export { FALLBACK_EMOJI, deriveEmoji, resolveEmoji } from "./emoji";

// Les réglages de génération, portés depuis l'app : ce sont les mêmes bornes des deux côtés,
// parce que c'est la même fonction Edge qui les reçoit.
export {
  CARD_KINDS,
  DEFAULT_QUOTA,
  PER_FORMAT_RANGE,
  TOTAL_RANGE,
  clampQuota,
  countOf,
  formatBounded,
  isAtCap,
  quotaTotal,
  type CardKind,
  type QuestionQuota,
} from "./generation/quota";
export {
  BLOCK_BOUNDS,
  DEFAULT_SHEET_LENGTH,
  SHEET_LENGTHS,
  blockRange,
  clampBlocks,
  defaultBlocks,
  isSheetLength,
  lengthContaining,
  readingHint,
  sheetLengthTitle,
  type SheetLength,
} from "./generation/sheet-length";
export {
  DEFAULT_VISIBILITY,
  VISIBILITIES,
  isShared,
  isVisibility,
  visibilityDetail,
  visibilityTitle,
  type CourseVisibility,
} from "./generation/visibility";
export {
  USERNAME_MAX,
  USERNAME_MESSAGES,
  USERNAME_MIN,
  USERNAME_SHAPE,
  displayUsername,
  normalizeUsername,
  validateUsername,
  type UsernameProblem,
} from "./username";
