import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import {
  CLOZE_GAP,
  DEFAULT_VISIBILITY,
  LESSON_SOURCES,
  courseSourceFor,
  emptyProgress,
  nextTone,
  normalizeClozeGap,
  pathFromPlan,
  readLessonPath,
  readPlanResponse,
  readQuizQuestion,
  readTone,
  readThemeNotes,
  type LessonSource,
  type QuizQuestion,
  type ThemeQuiz,
} from "@micabo/core";
import { revalidatePath } from "next/cache";

import { saveExam } from "@/lib/actions/exams";
import { revalidateUserData } from "@/lib/data/cache";
import { actionT } from "@/lib/i18n/action";
import { lessonAudience } from "@/lib/lesson/audience";
import { readableFunctionError } from "@/lib/lesson/errors";
import { createClient } from "@/lib/supabase/server";

/**
 * **Construit les leçons, et les écrit pendant qu'on les lit.** Jumeau de `LessonBuilder`
 * côté Swift ; voir `docs/refonte-web.md` § 4.
 *
 * Une leçon naît en deux temps. Le plan d'abord (`planLesson`), en une dizaine de secondes :
 * la leçon est créée avec ses thèmes en préparation, son chemin s'affiche et l'Intro se lit.
 * Puis chaque thème (`writeTheme`), que le navigateur demande quatre à la fois : son rond
 * passe de « en préparation » à « prêt » quand ses notes, ses questions et ses flashcards
 * arrivent. Un thème qui échoue passe en `failed` ; « Réessayer » le relance.
 *
 * Chaque écriture porte son filtre `user_id`. La porte du gratuit est tenue par le serveur
 * (`begin_lesson`) : le refus revient avec son code, et l'écran ouvre le paywall.
 */

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** Le texte envoyé au plan, coupé comme l'iPhone le coupe (`SupabaseLessonService.plan`). */
const MAX_TEXT = 120_000;
/** Le texte de référence d'un thème, même coupe que `SupabaseLessonService.theme`. */
const MAX_CONTEXT = 60_000;
const MAX_TOPIC = 400;
const MAX_IMAGES = 6;
const MAX_IMAGE_CHARS = 4_000_000;

export interface PlanInput {
  lessonId: string;
  topic?: string;
  text?: string;
  images?: string[];
  source: LessonSource;
  sourceName?: string;
  /** Le jour J, en `AAAA-MM-JJ`, quand l'élève a un examen. */
  examDate?: string | null;
  /** La leçon du parcours d'accueil : la leçon offerte, même depuis un support. */
  onboarding?: boolean;
}

export interface PlanOutcome {
  status: "ok" | "error";
  lessonId?: string;
  /** Le nombre de thèmes à écrire. */
  themes?: number;
  message?: string;
  code?: string;
}

export interface ThemeOutcome {
  status: "ok" | "error";
  message?: string;
  code?: string;
}

async function session() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return { supabase, user };
}

function acceptedImages(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  let total = 0;
  for (const item of raw) {
    if (typeof item !== "string" || !item.startsWith("data:image/")) continue;
    total += item.length;
    if (total > MAX_IMAGE_CHARS) break;
    out.push(item);
    if (out.length >= MAX_IMAGES) break;
  }
  return out;
}

async function fingerprint(text: string): Promise<string> {
  const normalized = text.toLowerCase().replace(/\s+/g, " ").trim().slice(0, 4_000);
  if (!normalized) return "";
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(normalized));
  return Array.from(new Uint8Array(digest))
    .slice(0, 16)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

/** « l'examen « Bac », le 2027-06-15 » : la date à l'ISO, le serveur la lit dans toutes les langues. */
export function examLine(name: string | null, date: string): string {
  const title = name?.trim() ? `« ${name.trim()} »` : "";
  return title ? `l'examen ${title}, le ${date}` : `un examen, le ${date}`;
}

/**
 * D'où vient le texte d'un thème, **dans les mots du serveur** : `LessonSourceKind(courseSource:)`
 * côté Swift. Un cours de bibliothèque, d'exemple ou un paquet se lit comme du texte ; envoyer
 * `library` ou `deck` tel quel laissait le serveur sans consigne de lecture connue.
 */
export function themeSource(source: string | null | undefined): string {
  switch (source) {
    case "pdf":
    case "photo":
    case "docx":
    case "youtube":
      return source;
    default:
      return "text";
  }
}

function refuse(message: string, code?: string): PlanOutcome {
  return { status: "error", message, ...(code ? { code } : {}) };
}

/** **Écrit le plan et crée la leçon** : le cours, ses thèmes en préparation, son examen. */
export async function planLesson(input: PlanInput): Promise<PlanOutcome> {
  const { supabase, user } = await session();
  if (!user) return refuse(await actionT("app.errors.signIn"));
  if (!UUID.test(input.lessonId)) return refuse(await actionT("app.common.errorGeneric"));

  const topic = typeof input.topic === "string" ? input.topic.trim().slice(0, MAX_TOPIC) : undefined;
  const text = (input.text ?? "").trim().slice(0, MAX_TEXT);
  const images = acceptedImages(input.images);
  const fromScratch = topic !== undefined && text.length === 0 && images.length === 0;
  if (fromScratch && (topic ?? "").length < 2) return refuse(await actionT("lesson.error.generic"));
  if (!fromScratch && text.length < 40 && images.length === 0) return refuse(await actionT("app.errors.textTooShort"));

  const source: LessonSource = fromScratch ? "topic" : (LESSON_SOURCES as readonly string[]).includes(input.source) ? input.source : "text";
  const examDate = input.examDate && /^\d{4}-\d{2}-\d{2}$/.test(input.examDate) ? input.examDate : null;
  const audience = await lessonAudience({ exam: examDate ? examLine(null, examDate) : undefined });

  const { data, error } = await supabase.functions.invoke("generate-lesson", {
    body: {
      ...audience,
      stage: "plan",
      lessonId: input.lessonId,
      ...(fromScratch ? { topic } : { text, images: images.length > 0 ? images : undefined }),
      source,
      sourceName: input.sourceName?.trim().slice(0, 200) ?? "",
      // Le drapeau ne part que vrai, comme `SupabaseLessonService.plan`.
      ...(input.onboarding === true ? { onboarding: true } : {}),
    },
  });
  if (error) {
    const refusal = await readableFunctionError(error);
    return refuse(refusal.message, refusal.code);
  }
  const plan = readPlanResponse(data);
  if (!plan) return refuse(await actionT("lesson.error.generic"));

  // Le ton de la dernière leçon créée, pour que la suivante n'ait pas le même.
  const { data: last } = await supabase
    .from("courses")
    .select("tone")
    .eq("user_id", user.id)
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  const previous = (last as { tone?: string | null } | null)?.tone;
  const now = new Date().toISOString();

  const { error: insertError } = await supabase.from("courses").insert({
    id: input.lessonId,
    user_id: user.id,
    title: plan.title,
    subject: plan.subject || null,
    summary: "",
    emoji: null,
    source: courseSourceFor(source),
    source_file_name: input.sourceName?.trim().slice(0, 200) || null,
    fingerprint: await fingerprint(text),
    raw_text: text,
    sheet: null,
    context_text: plan.contextText,
    visibility: DEFAULT_VISIBILITY,
    language: audience.language,
    tone: nextTone(previous ? readTone(previous) : null),
    icon: plan.icon,
    last_opened_at: now,
    path: pathFromPlan(plan),
    progress: emptyProgress(),
  });
  if (insertError) return refuse(insertError.message);

  const { error: chaptersError } = await supabase.from("chapters").insert(
    plan.themes.map((theme, index) => ({
      id: crypto.randomUUID(),
      user_id: user.id,
      course_id: input.lessonId,
      position: index,
      title: theme.title,
      icon: theme.icon,
      status: "pending",
    })),
  );
  if (chaptersError) return refuse(chaptersError.message);

  if (examDate) {
    // L'examen porte le nom de la leçon ; son échec n'empêche pas la leçon.
    await saveExam({ name: plan.title, examDate, courseIds: [input.lessonId] }).catch(() => undefined);
  }

  revalidateUserData(user.id, "courses");
  revalidatePath("/app");
  return { status: "ok", lessonId: input.lessonId, themes: plan.themes.length };
}

interface LessonForTheme {
  id: string;
  title: string;
  subject: string | null;
  language: string | null;
  context_text: string;
  source: string;
  path: unknown;
}

interface ChapterForTheme {
  id: string;
  position: number;
  title: string;
  status: string | null;
}

/** L'examen à venir qui porte sur cette leçon (`LessonBuilder.examLine(for:in:)`). */
export async function examLineFor(supabase: SupabaseClient, userId: string, lessonId: string): Promise<string | undefined> {
  const today = new Date().toISOString().slice(0, 10);
  const { data } = await supabase
    .from("exams")
    .select("name, exam_date, course_ids")
    .eq("user_id", userId)
    .is("deleted_at", null)
    .gte("exam_date", today)
    .order("exam_date", { ascending: true });
  const exam = ((data ?? []) as { name: string; exam_date: string; course_ids: string[] | null }[]).find((row) =>
    (row.course_ids ?? []).includes(lessonId),
  );
  return exam ? examLine(exam.name, exam.exam_date) : undefined;
}

/**
 * **Écrit un thème** : ses notes, sa question de fin, sa réserve de questions, ses
 * flashcards. `retry` relance un thème en échec. Un thème déjà prêt ne s'écrit pas deux fois.
 */
export async function writeTheme(lessonId: string, themeIndex: number, options: { retry?: boolean } = {}): Promise<ThemeOutcome> {
  const { supabase, user } = await session();
  if (!user) return { status: "error", message: await actionT("app.errors.signIn") };
  if (!UUID.test(lessonId) || !Number.isInteger(themeIndex) || themeIndex < 0) return { status: "error", message: await actionT("app.common.errorGeneric") };

  const [{ data: course }, { data: rows }] = await Promise.all([
    supabase
      .from("courses")
      .select("id, title, subject, language, context_text, source, path")
      .eq("user_id", user.id)
      .eq("id", lessonId)
      .is("deleted_at", null)
      .maybeSingle(),
    supabase
      .from("chapters")
      .select("id, position, title, status")
      .eq("user_id", user.id)
      .eq("course_id", lessonId)
      .is("deleted_at", null)
      .order("position", { ascending: true }),
  ]);
  const lesson = course as LessonForTheme | null;
  const chapters = (rows ?? []) as ChapterForTheme[];
  const chapter = chapters[themeIndex];
  if (!lesson || !chapter) return { status: "error", message: await actionT("app.errors.courseMissing") };
  if (chapter.status === "ready") return { status: "ok" };
  if (chapter.status === "failed" && !options.retry) return { status: "ok" };

  const path = readLessonPath(lesson.path);
  // L'audience est relue à chaque thème, comme `LessonBuilder` relit `audience()` : la langue
  // est celle du profil, pas celle gardée sur la leçon.
  const audience = await lessonAudience({ exam: await examLineFor(supabase, user.id, lessonId) });
  const points = path?.points ?? [];
  const objectives = path?.intro.lines ?? [];
  const { data, error } = await supabase.functions.invoke("generate-lesson", {
    body: {
      ...audience,
      stage: "theme",
      lessonId,
      lessonTitle: lesson.title,
      themeIndex,
      themes: chapters.map((entry) => entry.title),
      context: (lesson.context_text ?? "").slice(0, MAX_CONTEXT),
      subject: lesson.subject ?? "",
      // Comme l'app : les notions, les objectifs et la source ne partent que s'il y en a.
      ...(points.length > 0 ? { points } : {}),
      ...(objectives.length > 0 ? { objectives } : {}),
      source: themeSource(lesson.source),
    },
  });

  const now = new Date().toISOString();
  if (error) {
    const refusal = await readableFunctionError(error);
    await supabase.from("chapters").update({ status: "failed", updated_at: now }).eq("user_id", user.id).eq("id", chapter.id);
    revalidateUserData(user.id, "courses");
    return { status: "error", message: refusal.message, ...(refusal.code ? { code: refusal.code } : {}) };
  }

  const theme = (data as { theme?: { notes?: unknown; questions?: unknown; flashcards?: unknown } } | null)?.theme;
  const notes = theme ? readThemeNotes(theme.notes) : null;
  const questions: QuizQuestion[] = (Array.isArray(theme?.questions) ? theme!.questions : [])
    .map((question, index) => readQuizQuestion({ ...(question as Record<string, unknown>), id: `${chapter.id}:${index}` }))
    .filter((question): question is QuizQuestion => question !== null);
  if (!notes) {
    await supabase.from("chapters").update({ status: "failed", updated_at: now }).eq("user_id", user.id).eq("id", chapter.id);
    revalidateUserData(user.id, "courses");
    return { status: "error", message: await actionT("lesson.error.generic") };
  }

  const quiz: ThemeQuiz = { questions };
  const { error: updateError } = await supabase
    .from("chapters")
    .update({ notes, quiz, status: "ready", updated_at: now })
    .eq("user_id", user.id)
    .eq("id", chapter.id);
  if (updateError) return { status: "error", message: updateError.message };

  const cards = (Array.isArray(theme?.flashcards) ? theme!.flashcards : []) as { front?: unknown; back?: unknown; kind?: unknown }[];
  // Comme `LessonBuilder` : le recto d'une carte à trou est ramené à « … », et elle ne reste à
  // trou que si le trou y est. C'est ce marqueur que l'iPhone et Android relisent.
  const drafts = cards
    .map((card) => {
      const raw = typeof card.front === "string" ? card.front.trim() : "";
      const front = card.kind === "cloze" ? normalizeClozeGap(raw) : raw;
      return { front, back: typeof card.back === "string" ? card.back.trim() : "", kind: card.kind === "cloze" && front.includes(CLOZE_GAP) ? "cloze" : "basic" };
    })
    .filter((card) => card.front && card.back);
  if (drafts.length > 0) {
    const { count } = await supabase
      .from("flashcards")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .eq("course_id", lessonId)
      .is("deleted_at", null);
    await supabase.from("flashcards").insert(
      drafts.map((card, offset) => ({
        id: crypto.randomUUID(),
        user_id: user.id,
        course_id: lessonId,
        chapter_id: chapter.id,
        front: card.front,
        back: card.back,
        position: (count ?? 0) + offset,
        kind: card.kind,
        state: "new",
        due_date: now,
      })),
    );
  }

  await finishIfComplete(supabase, user.id, lessonId, path);
  revalidateUserData(user.id, "courses");
  revalidateUserData(user.id, "cards");
  revalidatePath(`/app/lecons/${lessonId}`);
  return { status: "ok" };
}

/** Le dernier thème arrivé : le chemin passe de « en cours d'écriture » à prêt. */
async function finishIfComplete(supabase: SupabaseClient, userId: string, lessonId: string, path: ReturnType<typeof readLessonPath>): Promise<void> {
  if (!path || path.status !== "generating") return;
  const { data } = await supabase.from("chapters").select("status").eq("user_id", userId).eq("course_id", lessonId).is("deleted_at", null);
  const statuses = ((data ?? []) as { status: string | null }[]).map((row) => row.status);
  if (statuses.includes("pending")) return;
  await supabase
    .from("courses")
    .update({ path: { ...path, status: "ready" }, updated_at: new Date().toISOString() })
    .eq("user_id", userId)
    .eq("id", lessonId);
}
