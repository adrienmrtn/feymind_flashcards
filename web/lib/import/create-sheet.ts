import "server-only";

import {
  DEFAULT_VISIBILITY,
  SOURCE_LANGUAGE,
  clampBlocks,
  countryFor,
  entitlement,
  isChoosableVisibility,
  isGenerationLanguage,
  isSheetLength,
  lengthContaining,
  normalizeSheet,
  resolveEmoji,
  sheetToPlainText,
  type CourseVisibility,
  type GenerationLanguage,
  type SheetBlock,
  type SheetLength,
} from "@micabo/core";

import { listCourses } from "@/lib/data/courses";
import { readEntitlement } from "@/lib/data/entitlement";
import { actionT } from "@/lib/i18n/action";
import { createClient } from "@/lib/supabase/server";

/**
 * Écrire une fiche **sans Server Action**.
 *
 * Appelée depuis `/api/import-course`. La même logique vivait dans un
 * `"use server"` : même invoquée par une route, Next la traitait comme une
 * action et relançait un vol RSC de la page d'import — « This page
 * couldn't load » pendant que le cours était déjà en base.
 */

export interface ImportResult {
  status: "ok" | "error" | "paywall";
  courseId?: string;
  message?: string;
}

interface GeneratedCourse {
  title?: string;
  subject?: string;
  emoji?: string;
  summary?: string;
  sheet?: { blocks?: unknown };
  contextText?: string;
}

const MINIMUM_TEXT = 40;
const MAXIMUM_TEXT = 60_000;
const MAXIMUM_INSTRUCTIONS = 2_000;
const MAX_IMPORT_IMAGES = 6;
const MAX_IMPORT_IMAGE_CHARS = 4_000_000;

export async function createSheetFromImport(input: {
  text: string;
  hintTitle?: string;
  sourceName?: string;
  source?: "text" | "pdf" | "docx" | "youtube";
  visibility?: CourseVisibility;
  blocks?: number;
  length?: SheetLength;
  language?: GenerationLanguage;
  instructions?: string;
  images?: string[];
}): Promise<ImportResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: await actionT("app.errors.signInImport") };

  const blocked = await refuseSecondCourse();
  if (blocked) return blocked;

  const text = input.text.trim().slice(0, MAXIMUM_TEXT);
  const images = acceptedImportImages(input.images);
  if (text.length < MINIMUM_TEXT && images.length === 0) {
    return { status: "error", message: await actionT("app.errors.textTooShort") };
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("study_level, country_code, sheet_length, sheet_language")
    .eq("id", user.id)
    .maybeSingle();

  const country = countryFor(profile?.country_code);
  const language = isGenerationLanguage(input.language) ? input.language : SOURCE_LANGUAGE;

  const stored = isSheetLength(profile?.sheet_length) ? profile.sheet_length : "standard";
  const wantedBlocks = input.blocks ? clampBlocks(input.blocks) : undefined;
  const length = wantedBlocks ? lengthContaining(wantedBlocks) : (input.length ?? stored);

  const { data, error } = await supabase.functions.invoke("generate-course", {
    body: {
      text,
      images: images.length > 0 ? images : undefined,
      hintTitle: input.hintTitle,
      sourceName: input.sourceName,
      level: profile?.study_level ?? undefined,
      country: country.code,
      language,
      length,
      blocks: wantedBlocks,
      source: input.source ?? "text",
      instructions: (input.instructions ?? "").trim().slice(0, MAXIMUM_INSTRUCTIONS) || undefined,
    },
  });

  if (error) return { status: "error", message: await readableError(error) };

  const course = (data as { course?: GeneratedCourse } | null)?.course;
  if (!course) return { status: "error", message: await actionT("app.errors.sheetWriteFailed") };

  // **Aucune image ne rentre dans la fiche.** Les pages du PDF partent encore au modèle,
  // parce que c'est ce qui rend un scan lisible ; ce qui a été retiré, c'est le recadrage
  // d'un morceau de page posé dans la fiche à côté de sa légende. Une capture de polycopié
  // au milieu d'un texte réécrit ne se relit pas : elle est floue, elle porte la mise en
  // page d'un autre document, et elle est presque toujours moins claire que la phrase qui
  // la légende. Le format ne connaît plus les figures du tout : la normalisation n'en garde
  // que la légende, en paragraphe.
  const blocks: SheetBlock[] = normalizeSheet(course.sheet ?? { blocks: [] });
  if (blocks.length === 0) {
    return { status: "error", message: await actionT("app.errors.sheetUnusable") };
  }

  const title = (course.title ?? input.hintTitle ?? "Cours sans titre").trim();
  const id = crypto.randomUUID();

  const { error: insertError } = await supabase.from("courses").insert({
    id,
    user_id: user.id,
    title,
    subject: course.subject ?? null,
    summary: course.summary ?? "",
    emoji: resolveEmoji(course.emoji, course.subject, title),
    source: input.source ?? "text",
    source_file_name: input.sourceName ?? null,
    fingerprint: await fingerprint(text.length >= 40 ? text : (images[0] ?? text)),
    raw_text: text,
    sheet: { blocks },
    context_text: course.contextText ?? sheetToPlainText(blocks),
    visibility: isChoosableVisibility(input.visibility) ? input.visibility : DEFAULT_VISIBILITY,
  });

  if (insertError) return { status: "error", message: insertError.message };

  return { status: "ok", courseId: id };
}

async function readableError(error: unknown): Promise<string> {
  const context = (error as { context?: Response }).context;
  if (context && typeof context.json === "function") {
    try {
      const body = (await context.json()) as { error?: string };
      if (body?.error) return body.error;
    } catch {
      // Corps illisible : le message du transport vaut mieux que rien.
    }
  }
  return error instanceof Error ? error.message : "Micabo n'a pas pu écrire cette fiche.";
}

function acceptedImportImages(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  let total = 0;
  for (const item of raw) {
    if (typeof item !== "string") continue;
    const url = item.trim();
    if (!url.startsWith("data:image/")) continue;
    total += url.length;
    if (total > MAX_IMPORT_IMAGE_CHARS) break;
    out.push(url);
    if (out.length >= MAX_IMPORT_IMAGES) break;
  }
  return out;
}

async function refuseSecondCourse(): Promise<ImportResult | null> {
  const [right, courses] = await Promise.all([readEntitlement(), listCourses()]);
  if (
    entitlement.canImportCourse(
      right,
      courses.map((course) => ({ isFromLibrary: course.is_from_library })),
    )
  ) {
    return null;
  }
  return { status: "paywall", message: await actionT("app.errors.secondCoursePro") };
}

async function fingerprint(text: string): Promise<string> {
  const normalized = text.toLowerCase().replace(/\s+/g, " ").trim().slice(0, 4_000);
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(normalized));
  return Array.from(new Uint8Array(digest))
    .slice(0, 16)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
