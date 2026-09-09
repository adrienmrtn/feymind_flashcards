"use server";

import { revalidatePath } from "next/cache";

import { canMoveFolder, type FolderNode } from "@micabo/core";

import { revalidateUserData } from "@/lib/data/cache";
import { actionT } from "@/lib/i18n/action";
import { createClient } from "@/lib/supabase/server";

/**
 * **Ranger ses cours.**
 *
 * Quatre gestes, et rien d'autre : créer un dossier, le renommer, y déplacer quelque chose,
 * le supprimer. C'est le vocabulaire d'un classeur, et c'est volontairement pauvre - un
 * rangement qui demande un mode d'emploi n'est pas un rangement.
 *
 * Deux choses ne sont pas laissées à l'écran :
 *
 * **Le cycle est vérifié ici aussi.** La base le refuse par un déclencheur, ce qui est le
 * dernier rempart ; mais une action serveur qui laisse partir une requête vouée à lever
 * rend une erreur de base de données à l'étudiant, et « erreur de contrainte » n'est pas un
 * message. On refuse donc avant, avec une phrase.
 *
 * **Rien ne se supprime vraiment.** Un dossier effacé pose une date, comme un cours ; et ce
 * qu'il contenait remonte à la racine plutôt que de partir avec lui. Perdre un rangement est
 * ennuyeux ; perdre quinze cours ne l'est pas.
 */

export interface FolderResult {
  status: "ok" | "error";
  message?: string;
  id?: string;
}

/** Un nom de dossier qui tient dans une colonne, et qui n'est pas vide. */
const MAX_NAME = 60;

function cleanName(raw: string): string {
  return raw.replace(/\s+/g, " ").trim().slice(0, MAX_NAME);
}

async function session() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return { supabase, user };
}

function done(userId: string): void {
  revalidateUserData(userId, "courses");
  revalidatePath("/app/cours");
}

export async function createFolder(
  name: string,
  parentId: string | null = null,
): Promise<FolderResult> {
  const { supabase, user } = await session();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const clean = cleanName(name);
  if (clean.length === 0) return { status: "error", message: await actionT("app.folders.needName") };

  // L'identifiant est posé ici, comme pour un cours : c'est ce qui permet à l'iPhone de
  // créer un dossier hors ligne et de le remonter ensuite sans table de correspondance.
  const id = crypto.randomUUID();

  const { error } = await supabase.from("course_folders").insert({
    id,
    user_id: user.id,
    parent_id: parentId,
    name: clean,
  });

  if (error) return { status: "error", message: error.message };

  done(user.id);
  return { status: "ok", id };
}

export async function renameFolder(id: string, name: string): Promise<FolderResult> {
  const { supabase, user } = await session();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const clean = cleanName(name);
  if (clean.length === 0) return { status: "error", message: await actionT("app.folders.needName") };

  const { error } = await supabase
    .from("course_folders")
    .update({ name: clean, updated_at: new Date().toISOString() })
    .eq("user_id", user.id)
    .eq("id", id);

  if (error) return { status: "error", message: error.message };

  done(user.id);
  return { status: "ok", id };
}

/** Déplacer un dossier sous un autre, ou à la racine. */
export async function moveFolder(id: string, parentId: string | null): Promise<FolderResult> {
  const { supabase, user } = await session();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const { data } = await supabase
    .from("course_folders")
    .select("id, parent_id, name, emoji, position")
    .eq("user_id", user.id)
    .is("deleted_at", null);

  const folders: FolderNode[] = (data ?? []).map((row) => ({
    id: row.id as string,
    parentId: (row.parent_id as string | null) ?? null,
    name: (row.name as string) ?? "",
    emoji: (row.emoji as string | null) ?? null,
    position: (row.position as number) ?? 0,
  }));

  if (!folders.some((folder) => folder.id === id)) {
    return { status: "error", message: await actionT("app.folders.missing") };
  }

  if (!canMoveFolder(folders, id, parentId)) {
    return { status: "error", message: await actionT("app.folders.cannotNest") };
  }

  const { error } = await supabase
    .from("course_folders")
    .update({ parent_id: parentId, updated_at: new Date().toISOString() })
    .eq("user_id", user.id)
    .eq("id", id);

  if (error) return { status: "error", message: error.message };

  done(user.id);
  return { status: "ok", id };
}

/** Poser un cours dans un dossier, ou le rendre à la racine avec `null`. */
export async function moveCourse(
  courseId: string,
  folderId: string | null,
): Promise<FolderResult> {
  const { supabase, user } = await session();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  if (folderId) {
    const { data: folder } = await supabase
      .from("course_folders")
      .select("id")
      .eq("user_id", user.id)
      .eq("id", folderId)
      .is("deleted_at", null)
      .maybeSingle();
    if (!folder) return { status: "error", message: await actionT("app.folders.missing") };
  }

  const { error } = await supabase
    .from("courses")
    .update({ folder_id: folderId, updated_at: new Date().toISOString() })
    .eq("user_id", user.id)
    .eq("id", courseId)
    .is("deleted_at", null);

  if (error) return { status: "error", message: error.message };

  done(user.id);
  return { status: "ok", id: courseId };
}

/**
 * Supprimer un dossier.
 *
 * Ce qu'il contient **remonte d'un cran** : les cours à son parent, les sous-dossiers aussi.
 * Effacer en cascade serait plus simple à écrire et catastrophique à vivre - un clic de trop
 * sur « Physique » emporterait le semestre.
 */
export async function deleteFolder(id: string): Promise<FolderResult> {
  const { supabase, user } = await session();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };

  const { data: folder } = await supabase
    .from("course_folders")
    .select("id, parent_id")
    .eq("user_id", user.id)
    .eq("id", id)
    .is("deleted_at", null)
    .maybeSingle();

  if (!folder) return { status: "error", message: await actionT("app.folders.missing") };

  const parent = (folder.parent_id as string | null) ?? null;
  const now = new Date().toISOString();

  await supabase
    .from("courses")
    .update({ folder_id: parent, updated_at: now })
    .eq("user_id", user.id)
    .eq("folder_id", id);

  await supabase
    .from("course_folders")
    .update({ parent_id: parent, updated_at: now })
    .eq("user_id", user.id)
    .eq("parent_id", id);

  const { error } = await supabase
    .from("course_folders")
    .update({ deleted_at: now, updated_at: now, parent_id: null })
    .eq("user_id", user.id)
    .eq("id", id);

  if (error) return { status: "error", message: error.message };

  done(user.id);
  return { status: "ok", id };
}
