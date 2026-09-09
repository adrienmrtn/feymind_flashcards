import "server-only";

import {
  throughputFrom,
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
  planned_for: string | null;
  minutes: number;
  question_count: number;
  correct_count: number;
  answers: { card: string; correct: boolean }[];
  started_at: string;
  finished_at: string | null;
}

const MOCK_COLUMNS =
  "id, exam_id, planned_for, minutes, question_count, correct_count, answers, started_at, finished_at";

/** Les blancs terminés. Une session ouverte ne mesure encore rien. */
export async function listMockResults(): Promise<MockResult[]> {
  const rows = await listMockSessions();
  return rows
    .filter((row) => row.finished_at && row.question_count > 0)
    .map((row) => ({
      id: row.id,
      examId: row.exam_id,
      questionCount: row.question_count,
      correctCount: row.correct_count,
      finishedAt: new Date(row.finished_at as string),
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
