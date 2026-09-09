/**
 * La copie d'examen blanc : les questions, les réponses, la note.
 *
 * L'ancien blanc était **une session de cartes déguisée** : une carte à la fois, on retourne,
 * et on se déclare soi-même juste ou faux. Trois choses n'allaient pas, et elles allaient
 * ensemble.
 *
 * - **S'auto-noter n'est pas passer un examen.** On se croit juste sur une réponse qu'on
 *   n'aurait pas su écrire, et le score sortait toujours trop haut - donc la seule mesure
 *   honnête du produit mentait dans le sens le plus dangereux.
 * - **Une carte à la fois n'est pas une épreuve.** Une vraie copie se voit en entier : on
 *   saute une question, on y revient, on gère son temps. C'est une compétence, et elle se
 *   travaille.
 * - **La réponse arrivait tout de suite**, ce qui transforme l'épreuve en révision.
 *
 * La copie est donc une feuille : vingt questions posées d'un coup, aucune réponse avant la
 * remise, et rien à cocher soi-même. Deux familles de questions, et la frontière est la
 * correction.
 *
 * - **Les questions fermées** - QCM, vrai ou faux, mot caché - se corrigent ici, sans modèle,
 *   à la comparaison. C'est le socle du score, et il est reproductible.
 * - **Les questions Feynman** - « explique ceci comme à quelqu'un qui ne l'a jamais vu » - se
 *   répondent à l'oral et se corrigent par un modèle, qui dit à quel point la réponse est
 *   juste. Elles n'apparaissent que si l'étudiant a un micro : dicter une explication est le
 *   seul moyen de vérifier qu'on sait vraiment, et taper la même chose au clavier laisse le
 *   temps de la reformuler jusqu'à ce qu'elle sonne bien.
 */

export type MockQuestionKind = "choice" | "truefalse" | "gap" | "feynman";

/** Graphie unique du trou, la même que pour les cartes. */
export const MOCK_GAP = "…";

export interface MockChoiceQuestion {
  kind: "choice";
  id: string;
  prompt: string;
  choices: string[];
  answerIndex: number;
  why: string;
}

export interface MockTrueFalseQuestion {
  kind: "truefalse";
  id: string;
  prompt: string;
  answer: boolean;
  why: string;
}

export interface MockGapQuestion {
  kind: "gap";
  id: string;
  /** La phrase, avec `MOCK_GAP` à la place du terme attendu. */
  prompt: string;
  answer: string;
  /** Autres graphies acceptées : pluriel, synonyme, abréviation. */
  accepts?: string[];
  why: string;
}

export interface MockFeynmanQuestion {
  kind: "feynman";
  id: string;
  prompt: string;
  /** Ce qu'une bonne réponse contient. Sert au modèle, jamais montré avant la remise. */
  expected: string;
}

export type MockQuestion =
  | MockChoiceQuestion
  | MockTrueFalseQuestion
  | MockGapQuestion
  | MockFeynmanQuestion;

export function isClosedQuestion(
  question: MockQuestion,
): question is MockChoiceQuestion | MockTrueFalseQuestion | MockGapQuestion {
  return question.kind !== "feynman";
}

/** Ce que l'étudiant a posé sur la copie. `null` quand il a laissé blanc. */
export interface MockAnswer {
  id: string;
  /** Index coché, pour un QCM. */
  choiceIndex?: number | null;
  /** Vrai ou faux coché. */
  truth?: boolean | null;
  /** Ce qui est écrit ou dicté. */
  text?: string | null;
}

/** La correction d'une question, une fois la copie remise. */
export interface MockGrade {
  id: string;
  /** 0 à 100. Les questions fermées ne rendent que 0 ou 100. */
  score: number;
  /** Ce que la correction a à dire. Vide sur une question fermée réussie. */
  comment?: string;
}

// MARK: - La correction des questions fermées

/**
 * Deux réponses écrites sont la même quand elles disent le même mot.
 *
 * On ignore la casse, les accents, la ponctuation et les articles : un étudiant qui écrit
 * « L'évaporation. » a répondu « évaporation », et lui compter faux serait corriger sa frappe
 * plutôt que son cours. On ne va pas plus loin - accepter « evaporer » demanderait une
 * racinisation par langue, et une correction qu'on ne sait pas expliquer ne vaut rien.
 */
export function sameAnswer(said: string, expected: string): boolean {
  const left = normalizeAnswer(said);
  return left.length > 0 && left === normalizeAnswer(expected);
}

export function normalizeAnswer(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\b(le|la|les|l|un|une|des|du|de|d|the|a|an|el|los|las|der|die|das|ein|eine)\b/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/** La note d'une question fermée : juste ou faux, sans nuance et sans modèle. */
export function gradeClosed(
  question: MockChoiceQuestion | MockTrueFalseQuestion | MockGapQuestion,
  answer: MockAnswer | undefined,
): MockGrade {
  if (question.kind === "choice") {
    const picked = answer?.choiceIndex;
    return {
      id: question.id,
      score: picked != null && picked === question.answerIndex ? 100 : 0,
      comment: question.why,
    };
  }

  if (question.kind === "truefalse") {
    const picked = answer?.truth;
    return {
      id: question.id,
      score: picked != null && picked === question.answer ? 100 : 0,
      comment: question.why,
    };
  }

  const said = answer?.text?.trim() ?? "";
  const accepted = [question.answer, ...(question.accepts ?? [])];
  return {
    id: question.id,
    score: accepted.some((candidate) => sameAnswer(said, candidate)) ? 100 : 0,
    comment: question.why,
  };
}

/**
 * La note de la copie : la moyenne des questions, sur cent.
 *
 * Une question Feynman pèse comme une question fermée. Elle est plus longue à répondre, mais
 * elle mesure la même chose - est-ce que je sais - et la surpondérer ferait dépendre le score
 * d'un jugement de modèle plutôt que d'un socle vérifiable.
 */
export function paperScore(grades: readonly MockGrade[]): number {
  if (grades.length === 0) return 0;
  const total = grades.reduce((sum, grade) => sum + clampScore(grade.score), 0);
  return Math.round(total / grades.length);
}

/** Le nombre de bonnes réponses, au sens où on le raconte : une question à 60 % est acquise. */
export const PASS_MARK = 60;

export function correctCount(grades: readonly MockGrade[]): number {
  return grades.filter((grade) => clampScore(grade.score) >= PASS_MARK).length;
}

export function clampScore(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(100, Math.round(value)));
}

// MARK: - La composition de la copie

/** Ce que la copie contient, par famille. Vingt questions, comme une vraie épreuve courte. */
export const MOCK_PAPER_SIZE = 20;

export interface PaperQuota {
  choice: number;
  truefalse: number;
  gap: number;
  feynman: number;
}

/**
 * La composition demandée au modèle.
 *
 * Sans micro, les trois questions ouvertes deviennent des questions fermées : la copie garde
 * ses vingt questions, et le score reste comparable d'une fois sur l'autre. C'est ce qui
 * permet de dire « 54 puis 71 » sans avoir à préciser dans quelles conditions.
 */
export function paperQuota(withAudio: boolean, size: number = MOCK_PAPER_SIZE): PaperQuota {
  const total = Math.max(4, Math.round(size));
  const feynman = withAudio ? Math.max(1, Math.round(total * 0.15)) : 0;
  const rest = total - feynman;
  const choice = Math.round(rest * 0.5);
  const gap = Math.round(rest * 0.25);
  return { choice, truefalse: rest - choice - gap, gap, feynman };
}

export function quotaSize(quota: PaperQuota): number {
  return quota.choice + quota.truefalse + quota.gap + quota.feynman;
}

/** Le temps imparti : une minute par question fermée, deux par question orale. */
export function paperMinutes(questions: readonly MockQuestion[]): number {
  const closed = questions.filter(isClosedQuestion).length;
  const spoken = questions.length - closed;
  return Math.max(5, Math.round(closed + spoken * 2));
}

// MARK: - Le débriefing

/** Ce que le modèle rend une fois la copie corrigée. */
export interface MockDebrief {
  /** Une phrase qui dit où on en est. */
  headline: string;
  /** Ce qui est tenu. */
  strengths: string[];
  /** Ce qui ne l'est pas. */
  gaps: string[];
  /** Quoi faire d'ici le jour J. */
  advice: string;
}

export function isMockDebrief(value: unknown): value is MockDebrief {
  if (!value || typeof value !== "object") return false;
  const debrief = value as Partial<MockDebrief>;
  return (
    typeof debrief.headline === "string" &&
    Array.isArray(debrief.strengths) &&
    Array.isArray(debrief.gaps) &&
    typeof debrief.advice === "string"
  );
}
