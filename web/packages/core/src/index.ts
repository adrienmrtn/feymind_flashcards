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
  normalizeSheet,
  sheetToPlainText,
  stripInlineMarkup,
  type SheetBlock,
  type SheetCrop,
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
  hardStepMinutes,
  previewLabels,
  schedule,
  type SchedulerConfig,
} from "./srs/sm2";
export {
  CARDS_PER_MINUTE,
  REPETITIONS_PER_CARD,
  dailyMinutesLabel,
} from "./srs/daily-load";
export {
  buildQueue,
  isDue,
  studyCounts,
  type QueueCard,
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
  DEFAULT_TARGET_SCORE,
  TARGET_SCORE_MAX,
  TARGET_SCORE_MIN,
  clampTargetScore,
  desiredGradeLabel,
  desiredGradeScale,
  gradeIndexFor,
  gradeTicks,
  intensityFromGradeIndex,
  intensityFromTargetScore,
  targetScoreFromIntensity,
  type DesiredGradeScale,
  type GradeTick,
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
  usableDays,
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

// Le plan de la période : plusieurs épreuves, un seul emploi du temps.
export {
  EXAM_KINDS,
  STARTING_POINTS,
  TERM_HORIZON_DAYS,
  asExamKind,
  asStartingPoint,
  defaultFormatsFor,
  examPriority,
  intensityFor,
  loadBars,
  termLoad,
  isMockBlock,
  isReviewBlock,
  matchesFormat,
  planTerm,
  todayBlocks,
  todayCardCount,
  type ExamKind,
  type LoadBar,
  type LoadMock,
  type LoadShare,
  type MockBlock,
  type PlanBlock,
  type PlanDay,
  type ReviewBlock,
  type PlannedPass,
  type StartingPoint,
  type TermCard,
  type TermExam,
  type TermInput,
  type TermLoad,
  type TermPlan,
} from "./srs/term";

// La copie d'examen blanc : vingt questions, aucune auto-notation.
export {
  MOCK_GAP,
  MOCK_PAPER_SIZE,
  PASS_MARK,
  clampScore,
  correctCount,
  gradeClosed,
  isClosedQuestion,
  isMockDebrief,
  normalizeAnswer,
  paperMinutes,
  paperQuota,
  paperScore,
  quotaSize,
  sameAnswer,
  type MockAnswer,
  type MockChoiceQuestion,
  type MockDebrief,
  type MockFeynmanQuestion,
  type MockGapQuestion,
  type MockGrade,
  type MockQuestion,
  type MockQuestionKind,
  type MockTrueFalseQuestion,
  type PaperQuota,
} from "./srs/mock-paper";

// L'examen blanc : la seule mesure en conditions d'épreuve.
export {
  DEFAULT_MOCK_QUESTIONS,
  MAX_MOCK_QUESTIONS,
  MINUTES_PER_MOCK_QUESTION,
  MIN_MOCK_QUESTIONS,
  MOCK_OFFSETS,
  WEAK_SHARE,
  drawMock,
  examReadiness,
  mockMinutes,
  mockQuestionCount,
  mockScore,
  planMocks,
  readinessGap,
  wantsMock,
  type DrawCandidate,
  type MockPlanInput,
  type MockResult,
  type PlannedMock,
} from "./srs/mock";

// Le débit réellement mesuré : ce que cet étudiant fait vraiment en une minute.
export {
  DEFAULT_THROUGHPUT,
  MAX_THROUGHPUT,
  MIN_PASSES_FOR_THROUGHPUT,
  MIN_THROUGHPUT,
  cardsIn,
  minutesFor,
  throughputFrom,
  type Throughput,
  type ThroughputSample,
} from "./srs/calibration";

// Ce qui résiste, et ce qui est acquis.
export {
  MIN_REVIEWS_FOR_WEAKNESS,
  NO_DIFFICULTY,
  PRIOR_FAILURE_RATE,
  PRIOR_REVIEWS,
  SEVERE_THRESHOLD,
  STUBBORN_LAPSES,
  WEAK_THRESHOLD,
  cardReadiness,
  extraPassesFor,
  isStubborn,
  isWeak,
  weakCards,
  weakFirst,
  weakness,
  type CardDifficulty,
  type WeakCandidate,
  type WeakCard,
} from "./srs/weakness";
export {
  EMPTY_MASTERY,
  EMPTY_STATS,
  currentStreak,
  longestStreak,
  masteryByCourse,
  masteryForCourses,
  masteryOf,
  studyStats,
  type DailyReview,
  type Mastery,
  type MasteryCard,
  type StudyStats,
} from "./srs/mastery";

export {
  EXAM_CHART_PAST_DAYS,
  buildExamInsight,
  cardKindLabel,
  chartOffsets,
  learnedPercent,
  weakNote,
  type ExamChart,
  type ExamInsight,
  type ExamInsightInput,
  type ExamWeakPoint,
  type InsightCard,
  type InsightReview,
  type WeakKind,
} from "./srs/exam-insight";

// Les séries, les niveaux de connaissance, et l'audience d'un cours.
export {
  KNOWLEDGE_LEVELS,
  KNOWLEDGE_LEVEL_LABELS,
  bestStreak,
  courseAudienceLabel,
  knowledgeDistribution,
  knowledgeLevel,
  knowledgePie,
  mostReviewedCards,
  rankReviewedCards,
  streak,
  weekStrip,
  WEEK_STRIP_RADIUS,
  type KnowledgeBucket,
  type KnowledgeCard,
  type KnowledgeLevel,
  type KnowledgeSlice,
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

// L'offre cadeau : vingt-quatre heures, sur le pop-up comme sur la pastille.
export * as discount from "./discount";

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
  countryFromUiLocale,
  institutionCountryIso,
  institutionSearchCountry,
  isContentLanguage,
  languageFor,
  languageLabel,
  sheetLanguage,
  type ContentLanguage,
  type Country,
  type CountryCode,
} from "./onboarding/countries";
export {
  GENERATION_LANGUAGES,
  SOURCE_LANGUAGE,
  generationLanguageLabel,
  isGenerationLanguage,
  type GenerationLanguage,
} from "./generation/language";
export {
  TIER_LADDER,
  isStudyLevel,
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
  CHOOSABLE_VISIBILITIES,
  DEFAULT_VISIBILITY,
  VISIBILITIES,
  asChoosableVisibility,
  choosableVisibilities,
  isChoosableVisibility,
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
