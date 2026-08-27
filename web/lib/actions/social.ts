"use server";

import { revalidatePath } from "next/cache";

import {
  USERNAME_MESSAGES,
  displayUsername,
  normalizeSheet,
  resolveEmoji,
  sheetToPlainText,
  validateUsername,
} from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { searchDirectory } from "@/lib/data/social";
import type { DirectoryPerson } from "@/lib/social";
import { createClient } from "@/lib/supabase/server";
import type { SupabaseClient } from "@supabase/supabase-js";

export interface SocialResult {
  status: "ok" | "error";
  message?: string;
  courseId?: string;
  username?: string;
}

export async function searchPeople(query: string): Promise<DirectoryPerson[]> {
  return searchDirectory(query);
}

export async function setUsername(raw: string): Promise<SocialResult> {
  const parsed = validateUsername(raw);
  if (!parsed.ok) return { status: "error", message: USERNAME_MESSAGES[parsed.problem] };

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  // Le nom part **seul**, sans le reste du profil : CloudSync envoie le profil
  // entier, et un appareil en retard écraserait le @ qu'on vient de changer ici.
  const { error } = await supabase
    .from("profiles")
    .update({ username: parsed.value, updated_at: new Date().toISOString() })
    .eq("id", user.id);

  if (error) {
    if (error.code === "23505") {
      return { status: "error", message: `${displayUsername(parsed.value)} est déjà pris.` };
    }
    return { status: "error", message: error.message };
  }

  revalidateUserData(user.id, "profile");
  revalidateUserData(user.id, "social");
  revalidatePath("/app/profil");
  revalidatePath("/app/amis");
  return { status: "ok", username: parsed.value };
}

export async function requestFriend(personId: string): Promise<SocialResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };
  if (personId === user.id) return { status: "error", message: "C'est toi." };

  const { data: incoming } = await supabase
    .from("friendships")
    .select("requester_id")
    .eq("requester_id", personId)
    .eq("addressee_id", user.id)
    .eq("status", "pending")
    .maybeSingle();

  if (incoming) return acceptFriend(personId);

  const { error } = await supabase.from("friendships").insert({
    requester_id: user.id,
    addressee_id: personId,
    status: "pending",
  });

  if (error) {
    if (error.code === "23505") return { status: "error", message: "Cette demande existe déjà." };
    return { status: "error", message: error.message };
  }

  touchSocial(user.id);
  return { status: "ok" };
}

export async function acceptFriend(personId: string): Promise<SocialResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  const { error } = await supabase
    .from("friendships")
    .update({ status: "accepted", responded_at: new Date().toISOString() })
    .eq("requester_id", personId)
    .eq("addressee_id", user.id);

  if (error) return { status: "error", message: error.message };

  touchSocial(user.id);
  return { status: "ok" };
}

export async function removeFriend(personId: string): Promise<SocialResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  const { error } = await supabase
    .from("friendships")
    .delete()
    .or(
      `and(requester_id.eq.${user.id},addressee_id.eq.${personId}),and(requester_id.eq.${personId},addressee_id.eq.${user.id})`,
    );

  if (error) return { status: "error", message: error.message };

  touchSocial(user.id);
  return { status: "ok" };
}

export async function adoptSharedCourse(courseId: string): Promise<SocialResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Connecte-toi." };

  const { data: shared } = await supabase
    .from("courses")
    .select(
      "id, user_id, title, subject, summary, emoji, accent_hex, raw_text, sheet, context_text, visibility",
    )
    .eq("id", courseId)
    .neq("user_id", user.id)
    .neq("visibility", "private")
    .is("deleted_at", null)
    .maybeSingle();

  if (!shared) return { status: "error", message: "Ce cours n'est plus partagé." };

  const title = (shared.title as string)?.trim() || "Cours repris";

  const { data: existing } = await supabase
    .from("courses")
    .select("id")
    .eq("user_id", user.id)
    .eq("is_from_library", true)
    .eq("title", title)
    .is("deleted_at", null)
    .maybeSingle();

  if (existing) {
    await copySharedCards(supabase, {
      sourceCourseId: courseId,
      targetCourseId: existing.id,
      userId: user.id,
    }).catch(() => undefined);
    revalidateUserData(user.id, "courses");
    revalidateUserData(user.id, "cards");
    revalidatePath(`/app/c/${existing.id}`);
    revalidatePath("/app/cours");
    return { status: "ok", courseId: existing.id };
  }

  const { data: author } = await supabase
    .from("directory")
    .select("username")
    .eq("id", shared.user_id)
    .maybeSingle();

  const blocks = shared.sheet ? normalizeSheet(shared.sheet) : [];
  const id = crypto.randomUUID();

  const { error } = await supabase.from("courses").insert({
    id,
    user_id: user.id,
    title,
    subject: shared.subject ?? null,
    summary: shared.summary ?? "",
    emoji: resolveEmoji(shared.emoji, shared.subject, title),
    accent_hex: shared.accent_hex ?? null,
    source: "library",
    source_file_name: author?.username ? `@${author.username}` : null,
    raw_text: shared.raw_text ?? "",
    sheet: blocks.length > 0 ? { blocks } : shared.sheet,
    context_text: shared.context_text || sheetToPlainText(blocks),
    visibility: "private",
    is_from_library: true,
  });

  if (error) return { status: "error", message: error.message };

  await supabase.rpc("record_course_adopt", { p_course_id: courseId }).then(
    () => undefined,
    () => undefined,
  );

  await copySharedCards(supabase, {
    sourceCourseId: courseId,
    targetCourseId: id,
    userId: user.id,
  }).catch(() => undefined);

  revalidateUserData(user.id, "courses");
  revalidateUserData(user.id, "cards");
  revalidatePath(`/app/c/${id}`);
  revalidatePath("/app/cours");
  revalidatePath("/app");
  return { status: "ok", courseId: id };
}

const SHARED_CARD_COPY =
  "id, front, back, hint, position, kind, choices, correct_choice_index, mask_x, mask_y, mask_width, mask_height, group_id, image_path";

async function copySharedCards(
  supabase: SupabaseClient,
  input: { sourceCourseId: string; targetCourseId: string; userId: string },
) {
  const { data: existing } = await supabase
    .from("flashcards")
    .select("id, front")
    .eq("user_id", input.userId)
    .eq("course_id", input.targetCourseId)
    .is("deleted_at", null);

  const already = new Set(
    ((existing as { front: string }[] | null) ?? []).map((card) => card.front),
  );

  const { data: source } = await supabase
    .from("flashcards")
    .select(SHARED_CARD_COPY)
    .eq("course_id", input.sourceCourseId)
    .is("deleted_at", null)
    .order("position", { ascending: true });

  const rows = ((source as SharedCopyRow[] | null) ?? []).filter(
    (card) => card.front.trim().length > 0 && !already.has(card.front),
  );
  if (rows.length === 0) return;

  const groups = new Map<string, string>();
  const now = new Date().toISOString();

  const { error } = await supabase.from("flashcards").insert(
    rows.map((card, index) => {
      const groupId = card.group_id
        ? groups.get(card.group_id) ??
          (() => {
            const next = crypto.randomUUID();
            groups.set(card.group_id!, next);
            return next;
          })()
        : null;

      return {
        id: crypto.randomUUID(),
        user_id: input.userId,
        course_id: input.targetCourseId,
        front: card.front,
        back: card.back,
        hint: card.hint ?? null,
        position: already.size + index,
        kind: card.kind ?? "basic",
        choices: card.choices ?? [],
        correct_choice_index: card.correct_choice_index ?? 0,
        mask_x: card.mask_x ?? 0,
        mask_y: card.mask_y ?? 0,
        mask_width: card.mask_width ?? 0,
        mask_height: card.mask_height ?? 0,
        group_id: groupId,
        image_path: card.image_path ?? null,
        state: "new",
        due_date: now,
        interval_days: 0,
        ease_factor: 2.5,
        repetitions: 0,
        lapses: 0,
        step_index: 0,
        last_reviewed_at: null,
        is_suspended: false,
      };
    }),
  );

  if (error) throw new Error(error.message);
}

interface SharedCopyRow {
  id: string;
  front: string;
  back: string;
  hint: string | null;
  position: number;
  kind: string;
  choices: string[] | null;
  correct_choice_index: number;
  mask_x: number;
  mask_y: number;
  mask_width: number;
  mask_height: number;
  group_id: string | null;
  image_path: string | null;
}

function touchSocial(userId: string) {
  revalidateUserData(userId, "social");
  revalidatePath("/app");
  revalidatePath("/app/amis");
  revalidatePath("/app/cours");
  revalidatePath("/app/u", "layout");
}
