import "server-only";

import { cache } from "react";

import { type SheetBlock, normalizeSheet } from "@micabo/core";

import {
  cachedRead,
  cardsTag,
  courseTag,
  coursesTag,
  dataClient,
  examsTag,
  socialTag,
  userTag,
} from "@/lib/data/cache";
import { currentAccessToken, currentUserId } from "@/lib/data/user";
import { createClient } from "@/lib/supabase/server";

/**
 * Les lectures de l'app web.
 *
 * **Chaque requête porte son filtre `user_id`**, alors que le cloisonnement suffirait. C'est la
 * leçon déjà payée côté iOS, et elle est recopiée ici mot pour mot : une requête qui compte sur le
 * cloisonnement pour ne pas ramasser les lignes des autres est une requête qu'une politique ajoutée
 * un jour recasse. `courses` en a déjà deux - la sienne et celle de la bibliothèque - et c'est
 * exactement ce cumul qui avait fait entrer les cours des camarades dans « Mes cours ».
 *
 * Et `deleted_at is null` partout : rien ne se supprime vraiment, un appareil hors ligne depuis
 * trois jours devant apprendre qu'un cours a disparu.
 *
 * Les listes stables (cours, examens, fiche, compteurs) passent par le cache de Next, tagué
 * par étudiant. La file de révision, non : ses échéances bougent à chaque note, et un cache
 * ici referait le « Tout est à jour » qu'on vient de corriger.
 */

export { currentUserId } from "@/lib/data/user";

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
  view_count: number;
  adopt_count: number;
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
  mask_x: number;
  mask_y: number;
  mask_width: number;
  mask_height: number;
  group_id: string | null;
  image_path: string | null;
  is_reversed: boolean;
}

/** Ce qu'il faut pour compter, pas pour réviser. */
export type CardSnapshotRow = Pick<
  CardRow,
  | "id"
  | "course_id"
  | "front"
  | "kind"
  | "is_suspended"
  | "state"
  | "due_date"
  | "position"
  | "created_at"
  | "interval_days"
  | "ease_factor"
  | "lapses"
>;

const COURSE_COLUMNS =
  "id, title, subject, summary, emoji, accent_hex, source, visibility, is_from_library, view_count, adopt_count, created_at, updated_at";

const CARD_COLUMNS =
  "id, course_id, front, back, hint, position, kind, choices, correct_choice_index, is_suspended, state, due_date, interval_days, ease_factor, repetitions, lapses, step_index, created_at, mask_x, mask_y, mask_width, mask_height, group_id, image_path, is_reversed";

const CARD_SNAPSHOT_COLUMNS =
  "id, course_id, front, kind, is_suspended, state, due_date, position, created_at, interval_days, ease_factor, lapses";

async function reader(): Promise<{ userId: string; token: string } | null> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return null;
  return { userId, token };
}

export async function listCourses(): Promise<CourseRow[]> {
  const auth = await reader();
  if (!auth) return [];

  return cachedRead(
    auth.userId,
    "courses",
    [userTag(auth.userId), coursesTag(auth.userId)],
    async () => {
      const { data } = await dataClient(auth.token)
        .from("courses")
        .select(COURSE_COLUMNS)
        .eq("user_id", auth.userId)
        .is("deleted_at", null)
        .order("updated_at", { ascending: false });
      return (data as CourseRow[] | null) ?? [];
    },
  );
}

/** Titre, matière, tuile - pas la fiche. C'est ce dont la barre et la liste ont besoin. */
export const getCourseMeta = cache(async (id: string): Promise<CourseRow | null> => {
  const auth = await reader();
  if (!auth) return null;

  return cachedRead(
    auth.userId,
    `course-meta:${id}`,
    [userTag(auth.userId), coursesTag(auth.userId), courseTag(auth.userId, id)],
    async () => {
      const { data } = await dataClient(auth.token)
        .from("courses")
        .select(COURSE_COLUMNS)
        .eq("user_id", auth.userId)
        .eq("id", id)
        .is("deleted_at", null)
        .maybeSingle();
      return (data as CourseRow | null) ?? null;
    },
    60,
  );
});

export const getCourse = cache(async (id: string): Promise<CourseDetail | null> => {
  const auth = await reader();
  if (!auth) return null;

  return cachedRead(
    auth.userId,
    `course:${id}`,
    [userTag(auth.userId), coursesTag(auth.userId), courseTag(auth.userId, id)],
    async () => {
      const { data } = await dataClient(auth.token)
        .from("courses")
        .select(`${COURSE_COLUMNS}, raw_text, context_text, sheet`)
        .eq("user_id", auth.userId)
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
    },
    60,
  );
});

export async function listCards(courseId: string): Promise<CardRow[]> {
  const auth = await reader();
  if (!auth) return [];

  return cachedRead(
    auth.userId,
    `cards:${courseId}`,
    [userTag(auth.userId), cardsTag(auth.userId)],
    async () => {
      const { data } = await dataClient(auth.token)
        .from("flashcards")
        .select(CARD_COLUMNS)
        .eq("user_id", auth.userId)
        .eq("course_id", courseId)
        .is("deleted_at", null)
        .order("position", { ascending: true });
      return (data as CardRow[] | null) ?? [];
    },
  );
}

/**
 * Toutes les cartes, **pour la session.** Pas de cache inter-requêtes : une note vient
 * de déplacer l'échéance, et la file doit le savoir tout de suite.
 */
export const listAllCards = cache(async (): Promise<CardRow[]> => {
  const userId = await currentUserId();
  if (!userId) return [];

  const supabase = await createClient();
  const { data } = await supabase
    .from("flashcards")
    .select(CARD_COLUMNS)
    .eq("user_id", userId)
    .is("deleted_at", null)
    .order("position", { ascending: true });

  return (data as CardRow[] | null) ?? [];
});

/** Compteurs du tableau de bord, de l'étagère, du profil : le recto suffit. */
export async function listCardSnapshots(): Promise<CardSnapshotRow[]> {
  const auth = await reader();
  if (!auth) return [];

  return cachedRead(
    auth.userId,
    "card-snapshots",
    [userTag(auth.userId), cardsTag(auth.userId)],
    async () => {
      const { data } = await dataClient(auth.token)
        .from("flashcards")
        .select(CARD_SNAPSHOT_COLUMNS)
        .eq("user_id", auth.userId)
        .is("deleted_at", null)
        .order("position", { ascending: true });
      return (data as CardSnapshotRow[] | null) ?? [];
    },
  );
}

export interface ExamRow {
  id: string;
  name: string;
  exam_date: string;
  intensity: string;
  target_score: number | null;
  course_ids: string[];
  is_planned: boolean;
}

export interface FriendRequestRow {
  requesterId: string;
  username: string | null;
  createdAt: string;
}

/** Demandes d'amis reçues et encore en attente. */
export async function listPendingFriendRequests(): Promise<FriendRequestRow[]> {
  const auth = await reader();
  if (!auth) return [];

  return cachedRead(auth.userId, "friends", [userTag(auth.userId), socialTag(auth.userId)], async () => {
    const supabase = dataClient(auth.token);
    const { data, error } = await supabase
      .from("friendships")
      .select("requester_id, created_at")
      .eq("addressee_id", auth.userId)
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
  });
}

export async function listExams(): Promise<ExamRow[]> {
  const auth = await reader();
  if (!auth) return [];

  return cachedRead(auth.userId, "exams", [userTag(auth.userId), examsTag(auth.userId)], async () => {
    const { data } = await dataClient(auth.token)
      .from("exams")
      .select("id, name, exam_date, intensity, target_score, course_ids, is_planned")
      .eq("user_id", auth.userId)
      .is("deleted_at", null)
      .order("exam_date", { ascending: true });
    return (data as ExamRow[] | null) ?? [];
  });
}
