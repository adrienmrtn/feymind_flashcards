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

  if (existing) return { status: "ok", courseId: existing.id };

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

  revalidateUserData(user.id, "courses");
  revalidatePath("/app/cours");
  revalidatePath("/app");
  return { status: "ok", courseId: id };
}

function touchSocial(userId: string) {
  revalidateUserData(userId, "social");
  revalidatePath("/app");
  revalidatePath("/app/amis");
  revalidatePath("/app/cours");
  revalidatePath("/app/u", "layout");
}
