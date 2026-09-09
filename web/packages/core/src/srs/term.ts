/**
 * Le plan de la période : plusieurs épreuves, un seul emploi du temps.
 *
 * `planExam` sait préparer **une** épreuve. Il ne sait pas ce qui arrive quand trois épreuves
 * tombent la même semaine et se disputent les mêmes soirées : chacune se croit seule, chacune
 * annonce une charge tenable, et l'addition ne l'est pas. C'est le défaut qui rendait le mode
 * examen joli et inutilisable dès la deuxième date.
 *
 * Ici on empile les plans, puis on les fait tenir dans le temps réellement disponible.
 *
 * Trois règles, dans cet ordre.
 *
 * - **La capacité est une contrainte dure.** Ce qui ne rentre pas un jour ne reste pas sur ce
 *   jour ; on le déplace, jamais au-delà de l'échéance de sa carte.
 * - **Le déplacement va d'abord vers l'avant.** Réviser trop tôt coûte un peu de rétention,
 *   réviser après l'examen n'en rapporte aucune.
 * - **Quand deux épreuves se disputent un jour, la plus proche gagne**, pondérée par ce qui
 *   reste à apprendre. Un contrôle dans trois jours passe devant un partiel dans trois
 *   semaines, même si le partiel est plus gros.
 *
 * Et quand rien ne rentre, on ne rabote pas en silence : `feasibility` rend le déficit en
 * minutes et les leviers qui le comblent. Un plan qui ment est pire qu'un plan absent.
 */

import {
  DEFAULT_THROUGHPUT,
  minutesFor,
  type Throughput,
} from "./calibration";
import { planMocks, type MockResult, type PlannedMock } from "./mock";
import {
  addDays,
  dayDifference,
  planExam,
  startOfDay,
  type ExamCard,
  type ExamIntensity,
} from "./exam";
import { extraPassesFor, type CardDifficulty } from "./weakness";
import { isMature, type CardState } from "./types";

/** Au-delà, on ne planifie plus : une épreuve dans six mois n'a pas d'emploi du temps. */
export const TERM_HORIZON_DAYS = 120;

/** Une épreuve, telle que le planificateur de période la voit. */
export interface TermExam {
  id: string;
  name: string;
  /** Le jour de l'épreuve, à midi ou minuit, peu importe : on ne garde que la journée. */
  examDate: Date;
  intensity: ExamIntensity;
  courseIds: readonly string[];
  /** Formats retenus. Vide signifie « tous les formats du cours ». */
  formats?: readonly string[];
  /** Type d'épreuve. Décide si un blanc a un sens, et lequel. */
  kind?: ExamKind;
  /** D'où l'étudiant part. Décale l'intensité d'un cran. */
  startingPoint?: StartingPoint;
}

export interface TermCard extends ExamCard {
  courseId: string | null;
  kind: string;
  isSuspended: boolean;
}

/** Un passage posé sur un jour, et l'épreuve qui l'a demandé. */
export interface PlannedPass {
  cardId: string;
  courseId: string | null;
  examId: string;
}

/** Ce que l'étudiant a à faire un jour donné, matière par matière. */
export interface PlanDay {
  /** Décalage depuis aujourd'hui. 0 est aujourd'hui. */
  offset: number;
  date: Date;
  cardCount: number;
  minutes: number;
  blocks: PlanBlock[];
  /** Les épreuves qui tombent ce jour-là. */
  examIds: string[];
  /** Un jour posé comme off : l'étudiant a dit qu'il ne réviserait pas. */
  isOff: boolean;
}

/**
 * Un bloc de travail.
 *
 * Deux formes, et c'est le changement de fond : un plan n'est plus une suite de « révise N
 * cartes ». Une **révision** travaille une matière ; un **blanc** mesure tout le programme en
 * temps imparti. Le champ `type` les sépare pour que l'écran n'ait pas à deviner.
 */
export type PlanBlock = ReviewBlock | MockBlock;

export interface ReviewBlock {
  type: "review";
  courseId: string | null;
  examId: string;
  examName: string;
  cardIds: string[];
  minutes: number;
}

export interface MockBlock {
  type: "mock";
  courseId: null;
  examId: string;
  examName: string;
  questionCount: number;
  minutes: number;
}

export function isMockBlock(block: PlanBlock): block is MockBlock {
  return block.type === "mock";
}

export function isReviewBlock(block: PlanBlock): block is ReviewBlock {
  return block.type === "review";
}

export interface TermPlan {
  days: PlanDay[];
  /** Par épreuve, le nombre de passages que le plan lui a réellement accordés. */
  passesByExam: Map<string, number>;
  totalPasses: number;
  horizonDays: number;
  /** Les examens blancs posés, dans l'ordre des jours. */
  mocks: PlannedMock[];
  /** Le débit retenu pour convertir cartes et minutes. */
  throughput: Throughput;
}

export interface TermInput {
  exams: readonly TermExam[];
  cards: readonly TermCard[];
  now?: Date;
  /** Le débit de cet étudiant. Absent, on retombe sur la constante d'avant. */
  throughput?: Throughput;
  /** Les blancs déjà passés : le plan ne repose pas celui qui est fait. */
  mocks?: readonly MockResult[];
  /**
   * Ce que le journal dit de chaque carte.
   *
   * Une carte que l'étudiant rate une fois sur deux mérite un passage de plus que ses
   * voisines : c'est la seule façon de faire **revenir** ce qui résiste plutôt que de se
   * contenter de le montrer en premier dans la session du jour.
   */
  difficulties?: ReadonlyMap<string, CardDifficulty>;
  /**
   * Les jours posés off, en décalage depuis aujourd'hui.
   *
   * Le plan n'y pose rien. C'est la seule chose que l'étudiant déclare encore sur son temps,
   * et c'est la seule qu'il sache dire sans se tromper : un budget de minutes se devine mal,
   * un dimanche en famille se sait.
   */
  offDays?: readonly number[];
}

// MARK: - Le plan

export function planTerm(input: TermInput): TermPlan {
  const now = input.now ?? new Date();
  const today = startOfDay(now);

  const upcoming = [...input.exams]
    .filter((exam) => dayDifference(today, exam.examDate) >= 0)
    .sort((left, right) => left.examDate.getTime() - right.examDate.getTime());

  const lastDay = upcoming.length
    ? dayDifference(today, upcoming[upcoming.length - 1]!.examDate)
    : 0;
  const horizon = Math.min(TERM_HORIZON_DAYS, Math.max(1, lastDay + 1));
  const throughput = input.throughput ?? DEFAULT_THROUGHPUT;

  // Tous les jours d'ici la dernière épreuve sont utilisables. Il n'y a plus de budget
  // déclaré : la journée vaut ce que les échéances lui demandent, et le plan dit ensuite
  // combien de temps ça prend.
  // Les jours off, s'il en reste après le garde-fou : le plan n'y pose aucune révision.
  const off = usableOffDays(input.offDays, horizon);

  const days: PlanDay[] = Array.from({ length: horizon }, (_, offset) => ({
    offset,
    date: addDays(today, offset),
    cardCount: 0,
    minutes: 0,
    blocks: [],
    examIds: [],
    isOff: off.has(offset),
  }));

  for (const exam of upcoming) {
    const offset = dayDifference(today, exam.examDate);
    if (offset >= 0 && offset < days.length) days[offset]!.examIds.push(exam.id);
  }

  const cardsByCourse = new Map<string, number>();
  for (const card of input.cards) {
    if (card.isSuspended || !card.courseId) continue;
    cardsByCourse.set(card.courseId, (cardsByCourse.get(card.courseId) ?? 0) + 1);
  }

  const mocks = planMocks({
    exams: upcoming.map((exam) => ({
      id: exam.id,
      name: exam.name,
      examDate: exam.examDate,
      kind: exam.kind ?? "exam",
      cardCount: exam.courseIds.reduce(
        (sum, courseId) => sum + (cardsByCourse.get(courseId) ?? 0),
        0,
      ),
    })),
    done: input.mocks ?? [],
    horizonDays: horizon,
    now,
  });

  for (const mock of mocks) {
    const day = days[mock.offset];
    if (!day) continue;
    day.blocks.push({
      type: "mock",
      courseId: null,
      examId: mock.examId,
      examName: mock.examName,
      questionCount: mock.questionCount,
      minutes: mock.minutes,
    });
  }

  // Chaque épreuve produit ses passages, puis on les fusionne. On garde l'épreuve d'origine
  // sur chaque passage : c'est elle qui nomme le bloc et qui arbitre les conflits.
  const wanted: { pass: PlannedPass; offset: number; deadline: number; priority: number }[] = [];
  const passesByExam = new Map<string, number>();

  for (const exam of upcoming) {
    const deadline = Math.max(0, dayDifference(today, exam.examDate) - 1);
    const courses = new Set(exam.courseIds);
    const concerned = input.cards.filter(
      (card) =>
        !card.isSuspended &&
        card.courseId != null &&
        courses.has(card.courseId) &&
        matchesFormat(card.kind, exam.formats),
    );
    if (concerned.length === 0) continue;

    const plan = planExam(concerned, exam.examDate, {
      now,
      intensity: intensityFor(exam.intensity, exam.startingPoint),
    });
    const priority = examPriority(exam, concerned, today);
    passesByExam.set(exam.id, 0);

    for (const card of concerned) {
      const offsets = plan.days.get(card.id) ?? [];
      for (const offset of offsets) {
        wanted.push({
          pass: { cardId: card.id, courseId: card.courseId, examId: exam.id },
          offset,
          deadline,
          priority,
        });
      }

      // Les passages de plus d'une carte fragile se glissent **entre** ceux que l'échelle a
      // posés : les coller à la fin les ferait tous tomber la veille, ce que l'échelle
      // s'emploie justement à éviter.
      const extra = extraPassesFor(input.difficulties?.get(card.id));
      for (let step = 0; step < extra && offsets.length >= 2; step += 1) {
        const between = midpoint(offsets, step);
        if (between == null) continue;
        wanted.push({
          pass: { cardId: card.id, courseId: card.courseId, examId: exam.id },
          offset: between,
          deadline,
          // Un passage de rattrapage ne doit pas déloger un premier passage : il sert après.
          priority: priority * 0.9,
        });
      }
    }
  }

  // L'ordre ne sert plus à arbitrer une pénurie de place - il n'y en a plus - mais à rendre
  // le plan stable : deux calculs successifs doivent poser les mêmes cartes aux mêmes jours.
  wanted.sort((left, right) => {
    if (left.priority !== right.priority) return right.priority - left.priority;
    if (left.offset !== right.offset) return left.offset - right.offset;
    return left.pass.cardId < right.pass.cardId ? -1 : 1;
  });

  const seen = new Map<number, Set<string>>();
  const placed: { pass: PlannedPass; offset: number }[] = [];

  for (const item of wanted) {
    const offset = placeOn(item.offset, item.deadline, item.pass.cardId, days.length, seen, off);
    if (offset == null) continue;
    placed.push({ pass: item.pass, offset });
    passesByExam.set(item.pass.examId, (passesByExam.get(item.pass.examId) ?? 0) + 1);
  }

  for (const { pass, offset } of placed) {
    const day = days[offset];
    if (!day) continue;
    const block = blockFor(day, pass, nameOf(upcoming, pass.examId));
    block.cardIds.push(pass.cardId);
    day.cardCount += 1;
  }

  for (const day of days) {
    let minutes = 0;
    for (const block of day.blocks) {
      if (isReviewBlock(block)) block.minutes = minutesFor(block.cardIds.length, throughput);
      minutes += block.minutes;
    }
    day.minutes = minutes;
    // Le blanc passe en tête : c'est un rendez-vous, pas un reste de session.
    day.blocks.sort((left, right) => {
      if (isMockBlock(left) !== isMockBlock(right)) return isMockBlock(left) ? -1 : 1;
      return right.minutes - left.minutes;
    });
  }

  return {
    days,
    passesByExam,
    totalPasses: placed.length,
    horizonDays: horizon,
    mocks,
    throughput,
  };
}

/** Le milieu du n-ième intervalle entre deux passages déjà posés. */
function midpoint(offsets: readonly number[], step: number): number | null {
  const index = step % Math.max(1, offsets.length - 1);
  const left = offsets[index];
  const right = offsets[index + 1];
  if (left == null || right == null || right - left < 2) return null;
  return Math.floor((left + right) / 2);
}

/**
 * Où poser ce passage : le jour demandé, sinon le plus proche avant l'épreuve.
 *
 * Il n'y a plus de budget à respecter, donc un passage tombe presque toujours pile sur le
 * jour que l'échelle a choisi. La seule raison de bouger reste la même qu'avant : **une carte
 * ne se voit pas deux fois le même jour.** On cherche alors d'abord avant la date voulue,
 * parce qu'un passage anticipé garde sa valeur, puis après jusqu'à la veille de l'épreuve.
 */
function placeOn(
  wanted: number,
  deadline: number,
  cardId: string,
  horizon: number,
  seen: Map<number, Set<string>>,
  off: ReadonlySet<number>,
): number | null {
  const limit = Math.min(deadline, horizon - 1);

  for (let distance = 0; distance <= horizon; distance += 1) {
    for (const offset of distance === 0 ? [wanted] : [wanted - distance, wanted + distance]) {
      if (offset < 0 || offset > limit) continue;
      if (off.has(offset)) continue;
      const already = seen.get(offset);
      if (already?.has(cardId)) continue;
      if (already) already.add(cardId);
      else seen.set(offset, new Set([cardId]));
      return offset;
    }
  }
  return null;
}

/**
 * Les jours qu'on accepte de laisser vides.
 *
 * Un seul garde-fou, mais il compte : si l'étudiant a posé toute la période en off, on n'en
 * garde aucun. Obéir à la lettre donnerait un plan vide, ce qui n'est pas ce qu'on nous
 * demande. Un passage qui ne trouve aucun jour ouvert avant son échéance est simplement
 * perdu, comme il l'était déjà quand la place manquait.
 */
function usableOffDays(offDays: readonly number[] | undefined, horizon: number): Set<number> {
  if (!offDays || offDays.length === 0) return new Set();
  const off = new Set(offDays.filter((offset) => offset >= 0 && offset < horizon));
  if (off.size >= horizon) return new Set();
  return off;
}

function blockFor(day: PlanDay, pass: PlannedPass, examName: string): ReviewBlock {
  const existing = day.blocks.find(
    (block): block is ReviewBlock =>
      isReviewBlock(block) && block.courseId === pass.courseId && block.examId === pass.examId,
  );
  if (existing) return existing;
  const block: ReviewBlock = {
    type: "review",
    courseId: pass.courseId,
    examId: pass.examId,
    examName,
    cardIds: [],
    minutes: 0,
  };
  day.blocks.push(block);
  return block;
}

function nameOf(exams: readonly TermExam[], id: string): string {
  return exams.find((exam) => exam.id === id)?.name ?? "";
}

/**
 * Ce qui fait passer une épreuve devant une autre.
 *
 * L'urgence domine - une échéance ne se négocie pas - et ce qui reste à apprendre la module :
 * à deux dates égales, l'épreuve la moins préparée mérite le créneau. Il n'y a **pas de
 * coefficient** : personne ne saisit fidèlement le poids de ses épreuves, et un chiffre faux
 * qui pilote un planning est pire qu'un chiffre absent.
 */
export function examPriority(
  exam: TermExam,
  cards: readonly TermCard[],
  today: Date,
): number {
  const days = Math.max(0, dayDifference(today, exam.examDate));
  const urgency = 1 / (1 + days);
  const known = cards.filter((card) => card.state === "review" && isMature(card.intervalDays));
  const mastery = cards.length === 0 ? 1 : known.length / cards.length;
  return urgency * (1.15 - mastery);
}

/** Un format retenu filtre les cartes ; aucun format retenu ne filtre rien. */
export function matchesFormat(kind: string, formats: readonly string[] | undefined): boolean {
  if (!formats || formats.length === 0) return true;
  return formats.includes(kind);
}

// MARK: - Ce que la période demande

/**
 * Ce que le plan réclame, en temps. **Ce n'est plus un verdict.**
 *
 * L'écran affichait avant « ça tient » ou « il te manque 12 min », comparé à un budget que
 * l'étudiant avait déclaré une fois pour toutes. Un budget déclaré est faux le lendemain, et
 * le déficit qu'il produisait poussait à mentir au réglage plutôt qu'à travailler. Ce qui
 * reste est la seule chose vraie : voilà le temps que la période demande, en moyenne par jour
 * et le jour le plus chargé. L'étudiant sait mieux que le produit si c'est tenable pour lui.
 */
export interface TermLoad {
  /** Charge moyenne des jours qui reçoivent du travail, en minutes. */
  averageMinutes: number;
  /** Le total de la période, en minutes. */
  totalMinutes: number;
  /** Le jour le plus chargé, en décalage depuis aujourd'hui. */
  busiest: { offset: number; minutes: number } | null;
  /** Jours de la période qui reçoivent au moins une carte. */
  workingDays: number;
}

export function termLoad(plan: TermPlan): TermLoad {
  const working = plan.days.filter((day) => day.minutes > 0);
  const totalMinutes = working.reduce((sum, day) => sum + day.minutes, 0);

  let busiest: { offset: number; minutes: number } | null = null;
  for (const day of plan.days) {
    if (!busiest || day.minutes > busiest.minutes) {
      busiest = { offset: day.offset, minutes: day.minutes };
    }
  }
  if (busiest && busiest.minutes === 0) busiest = null;

  return {
    averageMinutes: working.length === 0 ? 0 : Math.round(totalMinutes / working.length),
    totalMinutes,
    busiest,
    workingDays: working.length,
  };
}

// MARK: - Lecture du plan

/** Ce que le plan pose aujourd'hui, dans l'ordre où l'écran doit le montrer. */
export function todayBlocks(plan: TermPlan): PlanBlock[] {
  return plan.days[0]?.blocks ?? [];
}

/** Le total de cartes posées aujourd'hui par le plan. */
export function todayCardCount(plan: TermPlan): number {
  return plan.days[0]?.cardCount ?? 0;
}


/** La charge de chaque jour : ce que la période demande, jour par jour. */
export interface LoadBar {
  offset: number;
  date: Date;
  minutes: number;
  cardCount: number;
  examIds: string[];
  /** Un jour posé off : vide par choix, pas par manque de travail. */
  isOff: boolean;
}

export function loadBars(plan: TermPlan): LoadBar[] {
  return plan.days.map((day) => ({
    offset: day.offset,
    date: day.date,
    minutes: day.minutes,
    cardCount: day.cardCount,
    examIds: day.examIds,
    isOff: day.isOff,
  }));
}

/**
 * D'où l'étudiant part sur cette épreuve.
 *
 * La seule chose que le plan a besoin de savoir et qu'il ne peut pas déduire. Le journal dit
 * ce qui a été travaillé **dans l'app** ; il ne sait rien d'un cours suivi en amphi toute
 * l'année. Deux étudiants avec les mêmes cartes neuves peuvent être à des distances très
 * différentes de leur épreuve.
 */
export type StartingPoint = "cold" | "seen" | "solid";

export const STARTING_POINTS: readonly StartingPoint[] = ["cold", "seen", "solid"];

export function asStartingPoint(value: string | null | undefined): StartingPoint {
  return STARTING_POINTS.includes(value as StartingPoint) ? (value as StartingPoint) : "seen";
}

/**
 * L'intensité corrigée du point de départ.
 *
 * Découvrir un programme demande un passage de plus par carte, le réviser un de moins. On
 * décale l'intensité plutôt que d'ajouter un paramètre à l'échelle : c'est la même grandeur -
 * combien de fois chaque carte repasse - et un second réglage qui dit la même chose finirait
 * par la contredire.
 */
export function intensityFor(
  intensity: ExamIntensity,
  startingPoint: StartingPoint | undefined,
): ExamIntensity {
  const ladder: ExamIntensity[] = ["light", "standard", "intense"];
  const index = ladder.indexOf(intensity);
  const shift = startingPoint === "cold" ? 1 : startingPoint === "solid" ? -1 : 0;
  return ladder[Math.max(0, Math.min(ladder.length - 1, index + shift))] ?? intensity;
}

/** Type d'épreuve : il choisit les formats proposés, pas la replanification. */
export type ExamKind = "exam" | "midterm" | "final" | "quiz" | "oral" | "mock";

export const EXAM_KINDS: readonly ExamKind[] = [
  "exam",
  "midterm",
  "final",
  "quiz",
  "oral",
  "mock",
];

export function asExamKind(value: string | null | undefined): ExamKind {
  return EXAM_KINDS.includes(value as ExamKind) ? (value as ExamKind) : "exam";
}

/**
 * Les formats qu'un type d'épreuve suggère à la création.
 *
 * Un oral ne se prépare pas avec des QCM, un QCM se prépare avec des QCM. Ce ne sont que des
 * valeurs par défaut : l'étudiant recoche ce qu'il veut sur la fiche de l'épreuve.
 */
export function defaultFormatsFor(kind: ExamKind): string[] {
  switch (kind) {
    case "quiz":
    case "mock":
      return ["choice", "basic"];
    case "oral":
      return ["basic"];
    default:
      return [];
  }
}

/** État de carte lisible par le planificateur, réexporté pour les appelants. */
export type { CardState };
