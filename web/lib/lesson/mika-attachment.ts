import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import { MIKA_LIMITS, normalizeSheet, notesPlainText, readThemeNotes, sheetToPlainText } from "@micabo/core";

/**
 * **La leçon jointe à Mika** : son titre, et ses notes à plat, thème après thème. Sans notes
 * (un ancien cours), le texte de ses fiches ; sans fiche, le contexte enregistré avec le cours.
 * Borné à ce que la fonction lit (`MIKA_LIMITS.attachmentCharacters`). Jumeau de
 * `LessonMikaView.attachment(for:)`.
 */
export interface LessonAttachment {
  title: string;
  text: string;
  language: string | null;
}

export async function lessonAttachment(supabase: SupabaseClient, userId: string, lessonId: string): Promise<LessonAttachment | null> {
  const [{ data: course }, { data: chapters }] = await Promise.all([
    supabase.from("courses").select("id, title, language, context_text").eq("user_id", userId).eq("id", lessonId).is("deleted_at", null).maybeSingle(),
    supabase.from("chapters").select("title, notes, sheet, position").eq("user_id", userId).eq("course_id", lessonId).is("deleted_at", null).order("position", { ascending: true }),
  ]);
  if (!course) return null;
  const row = course as { title: string; language: string | null; context_text: string | null };
  const parts = ((chapters ?? []) as { title: string; notes: unknown; sheet: unknown }[]).map((chapter) => {
    const notes = readThemeNotes(chapter.notes);
    const body = notes ? notesPlainText(notes) : chapter.sheet ? sheetToPlainText(normalizeSheet(chapter.sheet)) : "";
    return `${chapter.title}\n${body}`.trim();
  });
  const joined = parts.filter((part) => part.length > 0).join("\n\n").trim();
  const text = (joined || row.context_text || "").slice(0, MIKA_LIMITS.attachmentCharacters);
  return { title: row.title, text, language: row.language };
}
