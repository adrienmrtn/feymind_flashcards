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

import { capacityWindow, type Availability } from "./availability";
import {
  DEFAULT_THROUGHPUT,
  cardsIn,
  minutesFor,
  realisticCapacity,
  type Adherence,
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
  capacityMinutes: number;
  cardCount: number;
  minutes: number;
  blocks: PlanBlock[];
  /** Les épreuves qui tombent ce jour-là. */
  examIds: string[];
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
  /** Les passages qui n'ont trouvé aucun jour avant leur échéance. */
  overflow: PlannedPass[];
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
  availability: Availability;
  now?: Date;
  /** Le débit de cet étudiant. Absent, on retombe sur la constante d'avant. */
  throughput?: Throughput;
  /** Ce qu'il tient réellement de son temps déclaré. Absente, on croit le déclaré. */
  adherence?: Adherence;
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

  // La capacité déclarée dit ce qu'on s'est promis ; l'observance dit ce qu'on tient. On
  // planifie sur le second, pour que le déficit se voie pendant qu'il est absorbable.
  const declared = capacityWindow(input.availability, today, horizon);
  const capacities = input.adherence
    ? declared.map((minutes) => realisticCapacity(minutes, input.adherence!))
    : declared;

  const days: PlanDay[] = capacities.map((capacityMinutes, offset) => ({
    offset,
    date: addDays(today, offset),
    capacityMinutes,
    cardCount: 0,
    minutes: 0,
    blocks: [],
    examIds: [],
  }));

  for (const exam of upcoming) {
    const offset = dayDifference(today, exam.examDate);
    if (offset >= 0 && offset < days.length) days[offset]!.examIds.push(exam.id);
  }

  // Les blancs se posent **avant** les révisions, et leur temps est retiré du budget du jour.
  // L'inverse - caler le blanc dans ce qui reste - reviendrait à le sacrifier dès que la
  // période est chargée, c'est-à-dire exactement quand il sert le plus.
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
    capacities,
    now,
  });

  const reserved = capacities.map(() => 0);
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
    reserved[mock.offset] = (reserved[mock.offset] ?? 0) + mock.minutes;
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
      intensity: exam.intensity,
      capacities,
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

  // L'ordre de service décide qui garde sa place quand un jour déborde : priorité d'épreuve
  // d'abord, puis le jour demandé, pour que le début de fenêtre se remplisse en premier.
  wanted.sort((left, right) => {
    if (left.priority !== right.priority) return right.priority - left.priority;
    if (left.offset !== right.offset) return left.offset - right.offset;
    return left.pass.cardId < right.pass.cardId ? -1 : 1;
  });

  // Ce qui reste aux révisions une fois les blancs servis. Jamais négatif : un jour dont le
  // blanc dépasse la capacité ne reçoit simplement plus de révision.
  const budget = capacities.map((minutes, offset) =>
    Math.max(0, minutes - (reserved[offset] ?? 0)),
  );
  const spent = capacities.map(() => 0);
  const seen = new Map<number, Set<string>>();
  const overflow: PlannedPass[] = [];
  const placed: { pass: PlannedPass; offset: number }[] = [];

  for (const item of wanted) {
    const offset = placeOn(
      item.offset,
      item.deadline,
      item.pass.cardId,
      budget,
      spent,
      seen,
      throughput,
    );
    if (offset == null) {
      overflow.push(item.pass);
      continue;
    }
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
    overflow,
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
 * Où poser ce passage : le jour demandé, sinon le plus proche qui reste ouvert.
 *
 * On cherche d'abord **avant** la date voulue, parce qu'un passage anticipé garde sa valeur,
 * puis après jusqu'à la veille de l'épreuve. Une carte ne se voit pas deux fois le même jour :
 * c'est ce que `seen` protège.
 */
function placeOn(
  wanted: number,
  deadline: number,
  cardId: string,
  budget: number[],
  spent: number[],
  seen: Map<number, Set<string>>,
  throughput: Throughput,
): number | null {
  const limit = Math.min(deadline, budget.length - 1);
  const cost = 1;

  for (let distance = 0; distance <= budget.length; distance += 1) {
    for (const offset of distance === 0 ? [wanted] : [wanted - distance, wanted + distance]) {
      if (offset < 0 || offset > limit) continue;
      const capacityCards = cardsIn(budget[offset] ?? 0, throughput);
      if (capacityCards <= 0) continue;
      if ((spent[offset] ?? 0) + cost > capacityCards) continue;
      const already = seen.get(offset);
      if (already?.has(cardId)) continue;
      spent[offset] = (spent[offset] ?? 0) + cost;
      if (already) already.add(cardId);
      else seen.set(offset, new Set([cardId]));
      return offset;
    }
  }
  return null;
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

// MARK: - Le verdict

export type VerdictLevel = "clear" | "tight" | "short";

export interface TermVerdict {
  level: VerdictLevel;
  /** Minutes qu'il faudrait ajouter pour que tout rentre. Zéro quand ça tient. */
  deficitMinutes: number;
  /** Charge moyenne des jours ouverts, en minutes. */
  averageMinutes: number;
  /** Le jour le plus chargé, en décalage depuis aujourd'hui. */
  busiest: { offset: number; minutes: number } | null;
  /** Le premier jour où la capacité est saturée. */
  firstSaturated: number | null;
  /** Passages qui n'ont trouvé aucune place avant leur échéance. */
  overflowPasses: number;
  /** Épreuves concernées par le débordement, pour nommer le problème. */
  examIds: string[];
}

/**
 * Ce que le plan vaut, en une lecture.
 *
 * `short` signifie que des passages n'ont trouvé aucune place avant leur échéance : ce n'est
 * pas un avertissement de confort, c'est une promesse que le produit ne peut pas tenir, et
 * l'écran doit proposer les arbitrages plutôt que d'afficher un plan complet imaginaire.
 */
export function feasibility(plan: TermPlan): TermVerdict {
  const open = plan.days.filter((day) => day.capacityMinutes > 0);
  const usedMinutes = plan.days.reduce((sum, day) => sum + day.minutes, 0);
  const averageMinutes = open.length === 0 ? 0 : Math.round(usedMinutes / open.length);

  let busiest: { offset: number; minutes: number } | null = null;
  let firstSaturated: number | null = null;
  for (const day of plan.days) {
    if (!busiest || day.minutes > busiest.minutes) {
      busiest = { offset: day.offset, minutes: day.minutes };
    }
    if (
      firstSaturated == null &&
      day.capacityMinutes > 0 &&
      day.minutes >= day.capacityMinutes
    ) {
      firstSaturated = day.offset;
    }
  }
  if (busiest && busiest.minutes === 0) busiest = null;

  const deficitMinutes = minutesFor(plan.overflow.length, plan.throughput);
  const examIds = [...new Set(plan.overflow.map((pass) => pass.examId))];

  const level: VerdictLevel =
    plan.overflow.length > 0 ? "short" : firstSaturated != null ? "tight" : "clear";

  return {
    level,
    deficitMinutes,
    averageMinutes,
    busiest,
    firstSaturated,
    overflowPasses: plan.overflow.length,
    examIds,
  };
}

// MARK: - Les leviers

export type LeverKind = "capacity" | "target" | "scope";

export interface TermLever {
  kind: LeverKind;
  /** Minutes que ce levier récupère, estimées. */
  recoveredMinutes: number;
  /** L'épreuve visée, quand le levier en vise une. */
  examId?: string;
}

/**
 * Les trois façons de combler un déficit, chiffrées.
 *
 * Elles ne sont pas décoratives : chacune correspond à une écriture que l'écran sait faire -
 * ouvrir du temps, baisser une note visée, retirer des cartes du programme. On les rend
 * ordonnées par ce qu'elles rapportent, et l'écran n'a qu'à les afficher.
 */
export function levers(plan: TermPlan, verdict: TermVerdict): TermLever[] {
  if (verdict.deficitMinutes <= 0) return [];

  const openDays = plan.days.filter((day) => day.capacityMinutes > 0).length || 1;
  const perDay = Math.max(5, Math.ceil(verdict.deficitMinutes / openDays / 5) * 5);

  const list: TermLever[] = [
    { kind: "capacity", recoveredMinutes: perDay * openDays },
  ];

  // Baisser la note visée retire un passage par carte de l'épreuve la plus en débordement.
  const worst = mostOverflowing(plan);
  if (worst) {
    const passes = plan.passesByExam.get(worst) ?? 0;
    list.push({
      kind: "target",
      recoveredMinutes: minutesFor(Math.round(passes / 3), plan.throughput),
      examId: worst,
    });
    list.push({
      kind: "scope",
      recoveredMinutes: minutesFor(Math.round(passes / 4), plan.throughput),
      examId: worst,
    });
  }

  return list.sort((left, right) => right.recoveredMinutes - left.recoveredMinutes);
}

function mostOverflowing(plan: TermPlan): string | null {
  const counts = new Map<string, number>();
  for (const pass of plan.overflow) {
    counts.set(pass.examId, (counts.get(pass.examId) ?? 0) + 1);
  }
  let best: string | null = null;
  let bestCount = 0;
  for (const [examId, count] of counts) {
    if (count > bestCount) {
      best = examId;
      bestCount = count;
    }
  }
  return best;
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


/** La charge de chaque jour, pour la frise : ce qui est demandé et ce qui est disponible. */
export interface LoadBar {
  offset: number;
  date: Date;
  minutes: number;
  capacityMinutes: number;
  /** Part de la capacité consommée, bornée à 1. Zéro quand le jour est fermé. */
  fill: number;
  isClosed: boolean;
  isOver: boolean;
  examIds: string[];
}

export function loadBars(plan: TermPlan): LoadBar[] {
  return plan.days.map((day) => ({
    offset: day.offset,
    date: day.date,
    minutes: day.minutes,
    capacityMinutes: day.capacityMinutes,
    fill:
      day.capacityMinutes <= 0 ? 0 : Math.min(1, day.minutes / Math.max(1, day.capacityMinutes)),
    isClosed: day.capacityMinutes <= 0,
    isOver: day.capacityMinutes > 0 && day.minutes > day.capacityMinutes,
    examIds: day.examIds,
  }));
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
