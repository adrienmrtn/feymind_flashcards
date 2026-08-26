import "server-only";

import { type SheetBlock, normalizeSheet } from "@micabo/core";

import { createClient } from "@/lib/supabase/server";

/**
 * Les lectures de l'app web.
 *
 * **Chaque requête porte son filtre `user_id`**, alors que le cloisonnement suffirait. C'est la
 * leçon déjà payée côté iOS, et elle est recopiée ici mot pour mot : une requête qui compte sur le
 * cloisonnement pour ne pas ramasser les lignes des autres est une requête qu'une politique ajoutée
 * un jour recasse. `courses` en a déjà deux — la sienne et celle de la bibliothèque — et c'est
 * exactement ce cumul qui avait fait entrer les cours des camarades dans « Mes cours ».
 *
 * Et `deleted_at is null` partout : rien ne se supprime vraiment, un appareil hors ligne depuis
 * trois jours devant apprendre qu'un cours a disparu.
 */

export interface CourseRow {
  id: string;
  title: string;
  subject: string | null;
  summary: string;
  emoji: string | null;
  accent_hex: string | null;
  source: string;
  visibility: string;
  is_from_library: boolean;
  created_at: string;
  updated_at: string;
}

export interface CourseDetail extends CourseRow {
  raw_text: string;
  context_text: string;
  blocks: SheetBlock[];
}

export interface CardRow {
  id: string;
  course_id: string | null;
  front: string;
  back: string;
  hint: string | null;
  position: number;
  kind: string;
  choices: string[];
  correct_choice_index: number;
  is_suspended: boolean;
  state: "new" | "learning" | "review" | "relearning";
  due_date: string;
  interval_days: number;
  ease_factor: number;
  repetitions: number;
  lapses: number;
  step_index: number;
  created_at: string;
}

const COURSE_COLUMNS =
  "id, title, subject, summary, emoji, accent_hex, source, visibility, is_from_library, created_at, updated_at";

const CARD_COLUMNS =
  "id, course_id, front, back, hint, position, kind, choices, correct_choice_index, is_suspended, state, due_date, interval_days, ease_factor, repetitions, lapses, step_index, created_at";

export async function currentUserId(): Promise<string | null> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user?.id ?? null;
}

export async function listCourses(): Promise<CourseRow[]> {
  const supabase = await createClient();
  const userId = await currentUserId();
  if (!userId) return [];

  const { data } = await supabase
    .from("courses")
    .select(COURSE_COLUMNS)
    .eq("user_id", userId)
    .is("deleted_at", null)
    .order("updated_at", { ascending: false });

  return (data as CourseRow[] | null) ?? [];
}

export async function getCourse(id: string): Promise<CourseDetail | null> {
  const supabase = await createClient();
  const userId = await currentUserId();
  if (!userId) return null;

  const { data } = await supabase
    .from("courses")
    .select(`${COURSE_COLUMNS}, raw_text, context_text, sheet`)
    .eq("user_id", userId)
    .eq("id", id)
    .is("deleted_at", null)
    .maybeSingle();

  if (!data) return null;

  // La fiche est **renormalisée à la lecture**, avec le même code que le serveur au moment où il
  // l'a écrite. Une fiche enregistrée par une version plus ancienne peut porter un bloc qu'on ne
  // sait plus afficher, ou dépasser un plafond qui a bougé depuis : la passer par `normalizeSheet`
  // coûte une milliseconde et évite une page cassée.
  const raw = (data as { sheet?: unknown }).sheet;
  const blocks = raw ? normalizeSheet(raw) : [];

  return { ...(data as unknown as CourseDetail), blocks };
}

export async function listCards(courseId: string): Promise<CardRow[]> {
  const supabase = await createClient();
  const userId = await currentUserId();
  if (!userId) return [];

  const { data } = await supabase
    .from("flashcards")
    .select(CARD_COLUMNS)
    .eq("user_id", userId)
    .eq("course_id", courseId)
    .is("deleted_at", null)
    .order("position", { ascending: true });

  return (data as CardRow[] | null) ?? [];
}

/** Toutes les cartes de l'étudiant, pour construire la file d'une session. */
export async function listAllCards(): Promise<CardRow[]> {
  const supabase = await createClient();
  const userId = await currentUserId();
  if (!userId) return [];

  const { data } = await supabase
    .from("flashcards")
    .select(CARD_COLUMNS)
    .eq("user_id", userId)
    .is("deleted_at", null)
    .order("position", { ascending: true });

  return (data as CardRow[] | null) ?? [];
}

export interface ExamRow {
  id: string;
  name: string;
  exam_date: string;
  intensity: string;
  course_ids: string[];
  is_planned: boolean;
}

export interface FriendRequestRow {
  requesterId: string;
  username: string | null;
  createdAt: string;
}

/** Demandes d'amis reçues et encore en attente. L'UI les affichera quand l'ajout d'amis existera. */
export async function listPendingFriendRequests(): Promise<FriendRequestRow[]> {
  const supabase = await createClient();
  const userId = await currentUserId();
  if (!userId) return [];

  const { data, error } = await supabase
    .from("friendships")
    .select("requester_id, created_at")
    .eq("addressee_id", userId)
    .eq("status", "pending")
    .order("created_at", { ascending: false });

  if (error) return [];

  const rows = (data as { requester_id: string; created_at: string }[] | null) ?? [];
  if (rows.length === 0) return [];

  const ids = rows.map((row) => row.requester_id);
  const { data: people } = await supabase.from("directory").select("id, username").in("id", ids);
  const names = new Map(
    ((people as { id: string; username: string }[] | null) ?? []).map((person) => [
      person.id,
      person.username,
    ]),
  );

  return rows.map((row) => ({
    requesterId: row.requester_id,
    username: names.get(row.requester_id) ?? null,
    createdAt: row.created_at,
  }));
}

export async function listExams(): Promise<ExamRow[]> {
  const supabase = await createClient();
  const userId = await currentUserId();
  if (!userId) return [];

  const { data } = await supabase
    .from("exams")
    .select("id, name, exam_date, intensity, course_ids, is_planned")
    .eq("user_id", userId)
    .is("deleted_at", null)
    .order("exam_date", { ascending: true });

  return (data as ExamRow[] | null) ?? [];
}
