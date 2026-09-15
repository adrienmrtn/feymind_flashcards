/**
 * **L'agenda d'un examen : tous ses rendez-vous de mesure, passés et à venir.**
 *
 * C'est ce que le mini-calendrier de la page d'examen affiche, et ce que « Au programme » lit
 * pour savoir qu'un test tombe aujourd'hui.
 *
 * ## Dérivé, et surchargé seulement là où l'étudiant a touché
 *
 * Aucun rendez-vous n'est écrit en base à la création d'un examen. Les blancs se déduisent de
 * `MOCK_OFFSETS`, les parcours de `parcoursOffsets`, et les deux se recalculent à chaque
 * lecture depuis la date de l'épreuve. Déplacer l'examen d'une semaine déplace tout l'agenda
 * sans migrer une ligne, et changer la cadence n'oblige pas à réécrire l'historique.
 *
 * Ce qui se persiste, c'est **l'exception** : quand l'étudiant déplace un rendez-vous, on
 * garde la date qu'il a choisie, et elle seule. Un agenda est donc une dérivation plus une
 * poignée de surcharges.
 *
 * ## Le rang est l'identité
 *
 * Une surcharge doit désigner un rendez-vous, et une date ne peut pas le faire : c'est
 * précisément ce qui change. C'est donc le **rang dans sa série** qui l'identifie - le blanc
 * numéro 0 est celui de J-7, le parcours numéro 3 est le quatrième en partant de l'épreuve.
 * Ce rang se compte depuis l'épreuve et non depuis aujourd'hui, donc il ne bouge pas quand les
 * jours passent : c'est ce qui permet à une surcharge de survivre à la nuit.
 *
 * ## Un rendez-vous manqué reste affiché
 *
 * Il ne se rattrape pas et ne se repose pas ailleurs : il se marque `missed`, à sa date. Un
 * étudiant qui a sauté le test de mardi doit le voir, sinon la seule trace de ce qu'il n'a pas
 * fait est son impression. Le rattrapage automatique avait l'inconvénient inverse : trois
 * jours d'absence et le plan se remplissait de tests en cascade.
 */

import { addDays, dayDifference, startOfDay } from "./exam";
import {
  MOCK_OFFSETS,
  MOCK_SLOT_SLACK,
  mockMinutes,
  mockQuestionCount,
  wantsMock,
} from "./mock";
import {
  PARCOURS_MINUTES,
  PARCOURS_QUESTION_COUNT,
  parcoursOffsets,
} from "./parcours";
import type { ExamKind } from "./term";

export type AgendaKind = "mock" | "parcours";

/**
 * Où en est un rendez-vous.
 *
 * `missed` n'est pas une punition, c'est un fait : le jour est passé et rien n'a été mesuré.
 */
export type AgendaStatus = "done" | "missed" | "upcoming";

/** Un rendez-vous de mesure, à sa date, avec son état. */
export interface AgendaEvent {
  examId: string;
  examName: string;
  kind: AgendaKind;
  /** Rang dans sa série, compté depuis l'épreuve. C'est ce qu'une surcharge désigne. */
  slot: number;
  date: Date;
  /** Jours depuis aujourd'hui. Négatif pour un rendez-vous passé. */
  offset: number;
  questionCount: number;
  minutes: number;
  status: AgendaStatus;
  /** Vrai quand la date vient d'une surcharge et non de la dérivation. */
  moved: boolean;
}

/** Une date choisie par l'étudiant, qui remplace celle que la dérivation proposait. */
export interface AgendaOverride {
  examId: string;
  kind: AgendaKind;
  slot: number;
  date: Date;
}

/** Une mesure déjà passée, telle qu'elle revient de `mock_sessions`. */
export interface AgendaDone {
  examId: string;
  kind: AgendaKind;
  finishedAt: Date;
}

export interface AgendaExam {
  id: string;
  name: string;
  examDate: Date;
  kind?: ExamKind;
  cardCount: number;
}

export interface AgendaInput {
  exams: readonly AgendaExam[];
  done?: readonly AgendaDone[];
  overrides?: readonly AgendaOverride[];
  now?: Date;
}

/**
 * De combien de jours une session peut manquer son rendez-vous et l'honorer quand même.
 *
 * Le blanc garde sa tolérance de trois jours : il y en a deux, ils sont loin l'un de l'autre,
 * et celui de J-7 passé le week-end d'avant reste celui de J-7. Les parcours, eux, sont posés
 * tous les deux ou trois jours : une tolérance de trois jours les ferait se voler leurs
 * sessions l'un à l'autre, et un seul test coché en effacerait trois.
 */
const SLACK: Record<AgendaKind, number> = {
  mock: MOCK_SLOT_SLACK,
  parcours: 1,
};

export function examAgenda(input: AgendaInput): AgendaEvent[] {
  const today = startOfDay(input.now ?? new Date());
  const events: AgendaEvent[] = [];

  for (const exam of input.exams) {
    const examDay = startOfDay(exam.examDate);
    const daysRemaining = dayDifference(today, examDay);

    const planned: AgendaEvent[] = [];

    // Les blancs : deux rendez-vous, et seulement pour les épreuves qui s'y prêtent - on ne
    // s'entraîne pas à un oral avec un QCM.
    const questionCount = mockQuestionCount(exam.cardCount);
    if (wantsMock(exam.kind ?? "exam") && questionCount > 0) {
      for (const [slot, before] of MOCK_OFFSETS.entries()) {
        planned.push(
          seed(exam, "mock", slot, addDays(examDay, -before), questionCount, mockMinutes(questionCount)),
        );
      }
    }

    // Les parcours : la cadence les pose, quel que soit le type d'épreuve. Cinq QCM et cinq
    // questions orales servent un oral autant qu'un écrit.
    for (const [slot, before] of parcoursOffsets(daysRemaining).entries()) {
      planned.push(
        seed(exam, "parcours", slot, addDays(examDay, -before), PARCOURS_QUESTION_COUNT, PARCOURS_MINUTES),
      );
    }

    applyOverrides(planned, input.overrides ?? []);
    separate(planned, examDay);
    settle(planned, input.done ?? [], today);

    events.push(...planned);
  }

  return events.sort((left, right) => left.date.getTime() - right.date.getTime());
}

function seed(
  exam: AgendaExam,
  kind: AgendaKind,
  slot: number,
  date: Date,
  questionCount: number,
  minutes: number,
): AgendaEvent {
  return {
    examId: exam.id,
    examName: exam.name,
    kind,
    slot,
    date,
    offset: 0,
    questionCount,
    minutes,
    status: "upcoming",
    moved: false,
  };
}

/** La date choisie par l'étudiant remplace celle de la dérivation, et se signale comme telle. */
function applyOverrides(planned: AgendaEvent[], overrides: readonly AgendaOverride[]): void {
  for (const event of planned) {
    const override = overrides.find((candidate) =>
      candidate.examId === event.examId &&
      candidate.kind === event.kind &&
      candidate.slot === event.slot
    );
    if (!override) continue;
    event.date = startOfDay(override.date);
    event.moved = true;
  }
}

/**
 * **Deux mesures ne partagent pas un jour.**
 *
 * Enchaîner un blanc et un parcours ne mesure plus rien : la seconde moitié se passe sur un
 * étudiant déjà fatigué, et son score dit la fatigue plutôt que le programme. Le parcours
 * s'écarte donc du blanc, et c'est toujours le parcours qui bouge - le blanc est le rendez-vous
 * qui compte.
 *
 * Il s'écarte **vers l'arrière**, en s'éloignant de l'épreuve. Vers l'avant il finirait la
 * veille ou le jour même, or ces jours-là il ne reste plus le temps de corriger ce que le test
 * révélerait. Un rendez-vous déplacé à la main ne bouge pas : l'étudiant a tranché.
 */
function separate(planned: AgendaEvent[], examDay: Date): void {
  const mocks = new Set(
    planned.filter((event) => event.kind === "mock").map((event) => event.date.getTime()),
  );
  const taken = new Set(mocks);

  for (const event of planned) {
    if (event.kind !== "parcours") continue;
    if (event.moved) {
      taken.add(event.date.getTime());
      continue;
    }

    let date = event.date;
    // On ne remonte pas indéfiniment : passé une semaine de recul, le rendez-vous n'a plus
    // rien à voir avec celui que la cadence avait posé.
    for (let step = 0; step < 7 && taken.has(date.getTime()); step += 1) {
      date = addDays(date, -1);
    }

    event.date = date;
    taken.add(date.getTime());
  }

  // Un parcours poussé au-delà du jour de l'épreuve n'a plus de sens.
  for (const event of planned) {
    if (event.date.getTime() > examDay.getTime()) event.date = examDay;
  }
}

/**
 * Attribue les sessions passées à leurs rendez-vous, et tranche l'état de chacun.
 *
 * Une session honore le rendez-vous de sa sorte dont elle est la plus proche, et seulement si
 * elle en est assez proche. Un entraînement lancé loin de tout n'en honore aucun : c'est ce
 * qui évitait déjà qu'un blanc passé par curiosité trois semaines avant efface le blanc de
 * J-7, et la règle vaut pour les parcours.
 */
function settle(planned: AgendaEvent[], done: readonly AgendaDone[], today: Date): void {
  const honoured = new Set<AgendaEvent>();

  for (const session of done) {
    const day = startOfDay(session.finishedAt);
    let best: AgendaEvent | null = null;
    let smallest = Infinity;

    for (const event of planned) {
      if (event.examId !== session.examId || event.kind !== session.kind) continue;
      if (honoured.has(event)) continue;
      const gap = Math.abs(dayDifference(event.date, day));
      if (gap < smallest) {
        smallest = gap;
        best = event;
      }
    }

    if (best && smallest <= SLACK[best.kind]) honoured.add(best);
  }

  for (const event of planned) {
    event.offset = dayDifference(today, event.date);
    event.status = honoured.has(event)
      ? "done"
      : event.offset < 0
      ? "missed"
      : "upcoming";
  }
}

/** Les rendez-vous d'un jour donné, pour « Au programme » et pour une case du calendrier. */
export function agendaOn(events: readonly AgendaEvent[], day: Date): AgendaEvent[] {
  const wanted = startOfDay(day).getTime();
  return events.filter((event) => event.date.getTime() === wanted);
}
