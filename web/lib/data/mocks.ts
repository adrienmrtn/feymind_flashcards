import "server-only";

import {
  throughputFrom,
  type AgendaDone,
  type AgendaKind,
  type AgendaOverride,
  type MockAnswer,
  type MockDebrief,
  type MockGrade,
  type MockQuestion,
  type MockResult,
  type Throughput,
  type ThroughputSample,
} from "@micabo/core";

import { cachedRead, cardsTag, dataClient, examsTag, userTag } from "@/lib/data/cache";
import { currentAccessToken, currentUserId } from "@/lib/data/user";

/**
 * Les examens blancs passés, et le débit de cet étudiant.
 *
 * Les deux alimentent le même écran et se lisent ensemble : le score dit où l'on en est
 * vraiment, le débit dit ce qui tient dans une soirée. Aucun des deux n'est demandé à
 * l'étudiant - ils sortent de ce qu'il a déjà fait.
 */

export interface MockSessionRow {
  id: string;
  exam_id: string | null;
  /** Ce que la session mesure. Null sur les lignes écrites avant les parcours : c'est un blanc. */
  kind: string | null;
  planned_for: string | null;
  minutes: number;
  question_count: number;
  correct_count: number;
  /** La copie posée à l'ouverture. Immuable pendant la passation. */
  questions: MockQuestion[] | null;
  /** Ce que l'étudiant a posé. */
  answers: MockAnswer[] | null;
  /** La correction, une fois la copie remise. */
  grades: MockGrade[] | null;
  debrief: MockDebrief | null;
  with_audio: boolean;
  started_at: string;
  finished_at: string | null;
}

const MOCK_COLUMNS =
  "id, exam_id, kind, planned_for, minutes, question_count, correct_count, questions, answers, grades, debrief, with_audio, started_at, finished_at";

/**
 * La sorte d'une session, telle qu'on ose la lire.
 *
 * Toutes les lignes antérieures aux parcours sont des blancs et n'ont pas de colonne `kind` -
 * la migration leur en donne une avec `default 'mock'`, mais une lecture faite pendant le
 * déploiement peut encore rendre `null`.
 */
export function asAgendaKind(value: string | null | undefined): AgendaKind {
  return value === "parcours" ? "parcours" : "mock";
}

/** Les blancs terminés. Une session ouverte ne mesure encore rien. */
export async function listMockResults(): Promise<MockResult[]> {
  const rows = await listMockSessions();
  return rows
    .filter((row) => row.finished_at && row.question_count > 0)
    .map((row) => ({
      id: row.id,
      examId: row.exam_id,
      kind: asAgendaKind(row.kind),
      questionCount: row.question_count,
      correctCount: row.correct_count,
      finishedAt: new Date(row.finished_at as string),
    }));
}

/**
 * Les mesures passées, sous la forme que l'agenda lit.
 *
 * Trois colonnes et sa propre requête, plutôt que `listMockSessions` : celle-ci ramène les
 * copies entières - questions, réponses, corrections - et se borne à soixante lignes pour ne
 * pas peser. L'agenda n'a besoin d'aucun de ces champs, et il en a besoin de **toutes** les
 * lignes : une session tombée hors de la fenêtre ferait passer pour manqué un rendez-vous
 * honoré, et le site contredirait le téléphone sur un test que l'étudiant a bien passé.
 *
 * Contrairement à `listMockResults`, une copie où rien n'a été juste compte : elle a été
 * passée, donc le rendez-vous l'a été aussi.
 */
export async function listMeasuresDone(): Promise<AgendaDone[]> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return [];

  const rows = await cachedRead(
    userId,
    "measures-done",
    [userTag(userId), examsTag(userId)],
    async () => {
      const { data } = await dataClient(token)
        .from("mock_sessions")
        .select("exam_id, kind, finished_at")
        .eq("user_id", userId)
        .not("exam_id", "is", null)
        .not("finished_at", "is", null)
        .order("finished_at", { ascending: false })
        .limit(500);
      return (
        (data as { exam_id: string; kind: string | null; finished_at: string }[] | null) ?? []
      );
    },
  );

  return rows.map((row) => ({
    examId: row.exam_id,
    kind: asAgendaKind(row.kind),
    finishedAt: new Date(row.finished_at),
  }));
}

/**
 * Les rendez-vous que l'étudiant a déplacés lui-même.
 *
 * C'est la seule part de l'agenda qui soit écrite : le reste se dérive de la date de l'épreuve
 * à chaque lecture. Sans cette lecture, le site reposerait les rendez-vous à leur date de
 * dérivation et l'étudiant verrait sa semaine bouger en passant du téléphone au navigateur.
 */
export async function listExamOverrides(): Promise<AgendaOverride[]> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return [];

  const rows = await cachedRead(
    userId,
    "exam-plan-overrides",
    [userTag(userId), examsTag(userId)],
    async () => {
      const { data } = await dataClient(token)
        .from("exam_plan_overrides")
        .select("exam_id, kind, slot, scheduled_for")
        .eq("user_id", userId)
        .limit(200);
      return (
        (data as { exam_id: string; kind: string; slot: number; scheduled_for: string }[] | null) ??
        []
      );
    },
  );

  return rows.map((row) => ({
    examId: row.exam_id,
    kind: asAgendaKind(row.kind),
    slot: row.slot,
    // Midi : une date nue se lit en UTC, et minuit UTC retombe la veille à l'ouest de Greenwich.
    date: new Date(`${row.scheduled_for}T12:00:00`),
  }));
}

export async function listMockSessions(): Promise<MockSessionRow[]> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return [];

  return cachedRead(
    userId,
    "mock-sessions",
    [userTag(userId), examsTag(userId)],
    async () => {
      const { data } = await dataClient(token)
        .from("mock_sessions")
        .select(MOCK_COLUMNS)
        .eq("user_id", userId)
        .order("started_at", { ascending: false })
        .limit(60);
      return (data as MockSessionRow[] | null) ?? [];
    },
  );
}

/** Une session précise, ouverte ou finie. Lue hors cache : elle change à chaque réponse. */
export async function readMockSession(id: string): Promise<MockSessionRow | null> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return null;

  const { data } = await dataClient(token)
    .from("mock_sessions")
    .select(MOCK_COLUMNS)
    .eq("user_id", userId)
    .eq("id", id)
    .maybeSingle();

  return (data as MockSessionRow | null) ?? null;
}

/**
 * Le débit de cet étudiant, déduit des écarts entre passages.
 *
 * Tagué avec les cartes : une session finie le fait bouger, et il n'a aucune raison d'être
 * relu entre deux.
 */
export async function loadThroughput(): Promise<Throughput> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return throughputFrom(null);

  const sample = await cachedRead(
    userId,
    "throughput",
    [userTag(userId), cardsTag(userId)],
    async () => {
      const { data } = await dataClient(token).rpc("review_throughput", { since_days: 60 });
      const row = (data as { cards: number; cards_per_minute: number | null }[] | null)?.[0];
      if (!row) return null;
      return {
        cards: Number(row.cards ?? 0),
        cardsPerMinute: row.cards_per_minute == null ? null : Number(row.cards_per_minute),
      } satisfies ThroughputSample;
    },
  );

  return throughputFrom(sample);
}
