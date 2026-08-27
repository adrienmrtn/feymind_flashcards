import "server-only";

import { cache } from "react";

import { normalizeSheet, normalizeUsername, type SheetBlock } from "@micabo/core";

import { cachedRead, dataClient, socialTag, userTag } from "@/lib/data/cache";
import { currentAccessToken, currentUserId } from "@/lib/data/user";
import type { DirectoryPerson, Relation } from "@/lib/social";

export type { DirectoryPerson, Relation } from "@/lib/social";

/**
 * L'annuaire, les amitiés et la bibliothèque.
 *
 * C'est le pendant de `SocialService` : rien n'est recopié localement. Les cours
 * de quelqu'un d'autre changent, peuvent redevenir privés, et un ami peut se
 * retirer. La base décide, via le cloisonnement, ce qu'on a le droit de lire.
 */

export interface SharedCourse {
  id: string;
  userId: string;
  title: string;
  subject: string | null;
  summary: string;
  emoji: string | null;
  accentHex: string | null;
  visibility: string;
  updatedAt: string;
  cardCount: number;
  viewCount: number;
  adoptCount: number;
}

export interface SharedCard {
  id: string;
  front: string;
  back: string;
  hint: string | null;
  position: number;
  kind: string;
  choices: string[];
  correct_choice_index: number;
  mask_x: number;
  mask_y: number;
  mask_width: number;
  mask_height: number;
  group_id: string | null;
  image_path: string | null;
}

export interface SharedCourseDetail extends SharedCourse {
  rawText: string;
  contextText: string;
  blocks: SheetBlock[];
}

const SHARED_COLUMNS =
  "id, user_id, title, subject, summary, emoji, accent_hex, visibility, updated_at, view_count, adopt_count";

const SHARED_DETAIL_COLUMNS = `${SHARED_COLUMNS}, raw_text, sheet, context_text`;

async function reader(): Promise<{ userId: string; token: string } | null> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return null;
  return { userId, token };
}

export async function getMyDirectory(): Promise<DirectoryPerson | null> {
  const auth = await reader();
  if (!auth) return null;

  const { data } = await dataClient(auth.token)
    .from("directory")
    .select("id, username, institution_id, institution_name")
    .eq("id", auth.userId)
    .maybeSingle();

  if (!data) return null;
  return {
    id: data.id,
    username: data.username,
    institutionId: data.institution_id,
    institutionName: data.institution_name,
    relation: "me",
  };
}

export async function listSocialGraph(): Promise<{
  me: DirectoryPerson | null;
  friends: DirectoryPerson[];
  incoming: DirectoryPerson[];
  outgoing: DirectoryPerson[];
}> {
  const auth = await reader();
  if (!auth) return { me: null, friends: [], incoming: [], outgoing: [] };

  return cachedRead(auth.userId, "social-graph", [userTag(auth.userId), socialTag(auth.userId)], async () => {
    const supabase = dataClient(auth.token);
    const [{ data: mine }, { data: links }] = await Promise.all([
      supabase
        .from("directory")
        .select("id, username, institution_id, institution_name")
        .eq("id", auth.userId)
        .maybeSingle(),
      supabase.from("friendships").select("requester_id, addressee_id, status"),
    ]);

    const rows = (links as { requester_id: string; addressee_id: string; status: string }[] | null) ?? [];
    const otherIds = [...new Set(rows.map((link) => (link.requester_id === auth.userId ? link.addressee_id : link.requester_id)))];
    const people = await directoryByIds(auth.token, otherIds);

    const friends: DirectoryPerson[] = [];
    const incoming: DirectoryPerson[] = [];
    const outgoing: DirectoryPerson[] = [];

    for (const link of rows) {
      const otherId = link.requester_id === auth.userId ? link.addressee_id : link.requester_id;
      const person = people.get(otherId);
      if (!person) continue;
      if (link.status === "accepted") {
        friends.push({ ...person, relation: "friends" });
      } else if (link.addressee_id === auth.userId) {
        incoming.push({ ...person, relation: "awaitingMe" });
      } else {
        outgoing.push({ ...person, relation: "requested" });
      }
    }

    return {
      me: mine
        ? {
            id: mine.id,
            username: mine.username,
            institutionId: mine.institution_id,
            institutionName: mine.institution_name,
            relation: "me" as const,
          }
        : null,
      friends,
      incoming,
      outgoing,
    };
  });
}

export async function searchDirectory(query: string): Promise<DirectoryPerson[]> {
  const auth = await reader();
  const needle = normalizeUsername(query);
  if (!auth || needle.length < 2) return [];

  const { data } = await dataClient(auth.token)
    .from("directory")
    .select("id, username, institution_id, institution_name")
    .ilike("username", `%${needle}%`)
    .order("username", { ascending: true })
    .limit(25);

  const graph = await listSocialGraph();
  const byId = relationMap(graph);

  return ((data as DirectoryRow[] | null) ?? []).map((row) => ({
    id: row.id,
    username: row.username,
    institutionId: row.institution_id,
    institutionName: row.institution_name,
    relation: row.id === auth.userId ? "me" : (byId.get(row.id) ?? "unknown"),
  }));
}

export async function listSchoolmates(): Promise<DirectoryPerson[]> {
  const auth = await reader();
  if (!auth) return [];

  const mine = await getMyDirectory();
  if (!mine?.institutionId) return [];

  const { data } = await dataClient(auth.token)
    .from("directory")
    .select("id, username, institution_id, institution_name")
    .eq("institution_id", mine.institutionId)
    .neq("id", auth.userId)
    .order("username", { ascending: true })
    .limit(50);

  const graph = await listSocialGraph();
  const byId = relationMap(graph);

  return ((data as DirectoryRow[] | null) ?? []).map((row) => ({
    id: row.id,
    username: row.username,
    institutionId: row.institution_id,
    institutionName: row.institution_name,
    relation: byId.get(row.id) ?? "unknown",
  }));
}

export async function getDirectoryById(id: string): Promise<DirectoryPerson | null> {
  const auth = await reader();
  if (!auth) return null;

  const { data } = await dataClient(auth.token)
    .from("directory")
    .select("id, username, institution_id, institution_name")
    .eq("id", id)
    .maybeSingle();

  if (!data) return null;

  const graph = await listSocialGraph();
  return {
    id: data.id,
    username: data.username,
    institutionId: data.institution_id,
    institutionName: data.institution_name,
    relation: data.id === auth.userId ? "me" : (relationMap(graph).get(data.id) ?? "unknown"),
  };
}

export async function getDirectoryPerson(username: string): Promise<DirectoryPerson | null> {
  const auth = await reader();
  const handle = username.trim().replace(/^@/, "").toLowerCase();
  if (!auth || !handle) return null;

  const { data } = await dataClient(auth.token)
    .from("directory")
    .select("id, username, institution_id, institution_name")
    .eq("username", handle)
    .maybeSingle();

  if (!data) return null;

  const graph = await listSocialGraph();
  return {
    id: data.id,
    username: data.username,
    institutionId: data.institution_id,
    institutionName: data.institution_name,
    relation: data.id === auth.userId ? "me" : (relationMap(graph).get(data.id) ?? "unknown"),
  };
}

export async function listLibraryCourses(options: {
  search?: string;
  subject?: string | null;
} = {}): Promise<{ courses: SharedCourse[]; authors: Map<string, DirectoryPerson> }> {
  const auth = await reader();
  if (!auth) return { courses: [], authors: new Map() };

  let query = dataClient(auth.token)
    .from("courses")
    .select(SHARED_COLUMNS)
    .neq("user_id", auth.userId)
    .neq("visibility", "private")
    .is("deleted_at", null)
    .order("updated_at", { ascending: false })
    .limit(60);

  const needle = options.search?.trim();
  if (needle && needle.length >= 2) {
    query = query.or(`title.ilike.%${escapeLike(needle)}%,subject.ilike.%${escapeLike(needle)}%`);
  }
  if (options.subject?.trim()) {
    query = query.eq("subject", options.subject.trim());
  }

  const { data } = await query;
  const courses = await withCardCounts(
    auth.token,
    ((data as SharedCourseRow[] | null) ?? []).map(asShared),
  );
  const authors = await directoryByIds(
    auth.token,
    [...new Set(courses.map((course) => course.userId))],
  );
  const graph = await listSocialGraph();
  const byId = relationMap(graph);

  for (const [id, person] of authors) {
    authors.set(id, { ...person, relation: byId.get(id) ?? "unknown" });
  }

  return { courses, authors };
}

export const getSharedCourse = cache(async (id: string): Promise<SharedCourseDetail | null> => {
  const auth = await reader();
  if (!auth) return null;

  const client = dataClient(auth.token);
  await client.rpc("record_course_view", { p_course_id: id }).then(
    () => undefined,
    () => undefined,
  );

  const { data } = await client
    .from("courses")
    .select(SHARED_DETAIL_COLUMNS)
    .eq("id", id)
    .neq("user_id", auth.userId)
    .neq("visibility", "private")
    .is("deleted_at", null)
    .maybeSingle();

  if (!data) return null;

  const raw = (data as { sheet?: unknown }).sheet;
  return {
    ...asShared(data as SharedCourseRow),
    rawText: (data as { raw_text: string }).raw_text ?? "",
    contextText: (data as { context_text: string }).context_text ?? "",
    blocks: raw ? normalizeSheet(raw) : [],
  };
});

export async function listCoursesOf(userId: string): Promise<SharedCourse[]> {
  const auth = await reader();
  if (!auth || userId === auth.userId) return [];

  const { data } = await dataClient(auth.token)
    .from("courses")
    .select(SHARED_COLUMNS)
    .eq("user_id", userId)
    .neq("visibility", "private")
    .is("deleted_at", null)
    .order("updated_at", { ascending: false })
    .limit(60);

  return withCardCounts(auth.token, ((data as SharedCourseRow[] | null) ?? []).map(asShared));
}

const SHARED_CARD_COLUMNS =
  "id, front, back, hint, position, kind, choices, correct_choice_index, mask_x, mask_y, mask_width, mask_height, group_id, image_path";

export const listSharedCards = cache(async (courseId: string): Promise<SharedCard[]> => {
  const auth = await reader();
  if (!auth) return [];

  const { data } = await dataClient(auth.token)
    .from("flashcards")
    .select(SHARED_CARD_COLUMNS)
    .eq("course_id", courseId)
    .is("deleted_at", null)
    .order("position", { ascending: true })
    .limit(400);

  return ((data as SharedCard[] | null) ?? []).map((card) => ({
    ...card,
    choices: card.choices ?? [],
    hint: card.hint ?? null,
    group_id: card.group_id ?? null,
    image_path: card.image_path ?? null,
  }));
});

export async function findAdoptedCourse(title: string): Promise<string | null> {
  const auth = await reader();
  if (!auth) return null;

  const { data } = await dataClient(auth.token)
    .from("courses")
    .select("id")
    .eq("user_id", auth.userId)
    .eq("is_from_library", true)
    .eq("title", title)
    .is("deleted_at", null)
    .maybeSingle();

  return (data as { id: string } | null)?.id ?? null;
}

interface DirectoryRow {
  id: string;
  username: string;
  institution_id: string | null;
  institution_name: string | null;
}

interface SharedCourseRow {
  id: string;
  user_id: string;
  title: string;
  subject: string | null;
  summary: string;
  emoji: string | null;
  accent_hex: string | null;
  visibility: string;
  updated_at: string;
  view_count?: number | null;
  adopt_count?: number | null;
}

function asShared(row: SharedCourseRow): SharedCourse {
  return {
    id: row.id,
    userId: row.user_id,
    title: row.title,
    subject: row.subject,
    summary: row.summary,
    emoji: row.emoji,
    accentHex: row.accent_hex,
    visibility: row.visibility,
    updatedAt: row.updated_at,
    cardCount: 0,
    viewCount: Number(row.view_count ?? 0),
    adoptCount: Number(row.adopt_count ?? 0),
  };
}

async function withCardCounts(token: string, courses: SharedCourse[]): Promise<SharedCourse[]> {
  if (courses.length === 0) return courses;

  const { data } = await dataClient(token)
    .from("flashcards")
    .select("course_id")
    .in(
      "course_id",
      courses.map((course) => course.id),
    )
    .is("deleted_at", null);

  const counts = new Map<string, number>();
  for (const row of (data as { course_id: string | null }[] | null) ?? []) {
    if (!row.course_id) continue;
    counts.set(row.course_id, (counts.get(row.course_id) ?? 0) + 1);
  }

  return courses.map((course) => ({
    ...course,
    cardCount: counts.get(course.id) ?? 0,
  }));
}

async function directoryByIds(token: string, ids: string[]): Promise<Map<string, DirectoryPerson>> {
  const unique = [...new Set(ids.filter(Boolean))];
  if (unique.length === 0) return new Map();

  const { data } = await dataClient(token)
    .from("directory")
    .select("id, username, institution_id, institution_name")
    .in("id", unique);

  return new Map(
    ((data as DirectoryRow[] | null) ?? []).map((row) => [
      row.id,
      {
        id: row.id,
        username: row.username,
        institutionId: row.institution_id,
        institutionName: row.institution_name,
        relation: "unknown" as const,
      },
    ]),
  );
}

function relationMap(graph: {
  friends: DirectoryPerson[];
  incoming: DirectoryPerson[];
  outgoing: DirectoryPerson[];
}): Map<string, Relation> {
  const map = new Map<string, Relation>();
  for (const person of graph.friends) map.set(person.id, "friends");
  for (const person of graph.incoming) map.set(person.id, "awaitingMe");
  for (const person of graph.outgoing) map.set(person.id, "requested");
  return map;
}

function escapeLike(value: string): string {
  return value.replace(/[%_,]/g, " ").replace(/\s+/g, " ").trim();
}

/** Cartes passées cette semaine, soi-même et ses amis. */
export async function listWeekReviewRanking(): Promise<
  { userId: string; username: string | null; passes: number; isMe: boolean }[]
> {
  const auth = await reader();
  if (!auth) return [];

  const { data, error } = await dataClient(auth.token).rpc("week_review_ranking");
  if (error || !data) return [];
  return (
    data as { user_id: string; username: string | null; passes: number | string }[]
  ).map((row) => ({
    userId: row.user_id,
    username: row.username,
    passes: Number(row.passes) || 0,
    isMe: row.user_id === auth.userId,
  }));
}
