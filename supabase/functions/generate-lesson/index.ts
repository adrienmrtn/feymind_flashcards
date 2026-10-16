/**
 * **`generate-lesson`** : la leçon-chemin, en trois temps. Voir `docs/refonte-parcours.md` § 9.
 *
 * - `stage: "plan"` (≈ 5 à 10 s) — les supports ou le sujet → le titre, l'icône, les thèmes, les
 *   paliers, l'intro, la conclusion, et le texte de référence. L'app crée la leçon, le chemin
 *   s'affiche, l'Intro se lit.
 * - `stage: "theme"` — un thème → ses notes, sa question de fin, trois QCM de réserve, trois
 *   flashcards. L'app en lance quatre à la fois ; chaque cercle Notes se remplit quand le sien
 *   arrive.
 * - `stage: "convert"` — un ancien cours → ce qui lui manque pour devenir un chemin, sans
 *   réécrire ses notes : icônes, intro, conclusion, noms de paliers, questions.
 *
 * Déployer : `supabase functions deploy generate-lesson`, après la migration
 * `lesson_generations` (la porte du gratuit), ou par `pin.sh`.
 */
import { consumeQuota, readCaller, withCors } from "../_shared/caller.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { callModel, errorResponse, FalError, jsonResponse } from "../_shared/fal.ts";
import { CircuitOpenError } from "../_shared/circuit.ts";
import { parseModelJSON } from "../_shared/json.ts";
import { type ModelUsage, totalUsage } from "../_shared/usage.ts";
import { detectDiscipline, disciplineBrief } from "../_shared/discipline.ts";
import { languageBrief } from "../_shared/language.ts";
import { sanitizeMeta, wrapUntrusted } from "../_shared/prompt-boundary.ts";
import { normalizeIcon } from "../_shared/icons.ts";
import { audienceBrief, readingBrief, VISION_SYSTEM_PROMPT } from "../generate-course/prompt.ts";
import {
  CONVERT_SYSTEM_PROMPT,
  convertBrief,
  convertTokens,
  iconsSection,
  PLAN_SYSTEM_PROMPT,
  PLAN_TOKENS,
  planShapeBrief,
  PROMPT_VERSION,
  stageBrief,
  THEME_SYSTEM_PROMPT,
  THEME_TOKENS,
  themeBrief,
} from "./prompt.ts";
import {
  cleanText,
  clampWords,
  estimateMinutes,
  groupThemes,
  LIMITS,
  MAX_SOURCE,
  readFlashcards,
  readNotes,
  readPlan,
  readQuestions,
  SHORT_SOURCE,
} from "./schema.ts";
import {
  admitThemeCall,
  beginLesson,
  isLessonId,
  LessonGateError,
  normalizeSource,
} from "./gate.ts";

interface RequestBody {
  stage?: string;
  /** L'identifiant de la leçon, créé par l'app : c'est celui du cours SwiftData. */
  lessonId?: string;
  language?: string;
  level?: string;
  country?: string;
  /** L'étape précise : « 4e », « Terminale », « L2 »… */
  schoolStage?: string;
  subject?: string;

  // Plan
  text?: string;
  images?: string[];
  topic?: string;
  source?: string;
  sourceName?: string;
  /** La leçon du parcours d'accueil : la leçon offerte peut alors venir d'un support. */
  onboarding?: boolean;

  // Thème
  lessonTitle?: string;
  themeIndex?: number;
  themes?: string[];
  context?: string;

  // Conversion
  title?: string;
  chapters?: { title?: string; text?: string; needsCards?: boolean }[];
}

const MAX_IMAGES = 6;
const MAX_IMAGE_CHARS = 4_000_000;
const MAX_TOPIC = 400;
/** Le fusible des thèmes : une leçon en a douze au plus, « Réessayer » compris. */
const THEME_DAILY_CEILING = 60;
const CONVERT_CHAPTER_TEXT = 3_000;
const CONVERT_TOTAL_TEXT = 40_000;

function acceptedImages(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  let total = 0;
  for (const item of raw) {
    if (typeof item !== "string") continue;
    const url = item.trim();
    if (!url.startsWith("https://") && !url.startsWith("data:image/")) continue;
    total += url.length;
    if (total > MAX_IMAGE_CHARS) break;
    out.push(url);
    if (out.length >= MAX_IMAGES) break;
  }
  return out;
}

/** Un appel au modèle qui rend un objet JSON, ou `null` quand la réponse est illisible. */
async function ask(
  options: { prompt: string; system: string; temperature: number; maxTokens: number; meter: ModelUsage[] },
): Promise<Record<string, unknown> | null> {
  try {
    const output = await callModel({
      prompt: options.prompt,
      systemPrompt: options.system,
      temperature: options.temperature,
      maxTokens: options.maxTokens,
      meter: options.meter,
    });
    const parsed = parseModelJSON<unknown>(output);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? parsed as Record<string, unknown>
      : null;
  } catch (error) {
    // Une panne du fournisseur n'est pas une réponse illisible : la retenter tout de suite
    // paierait un second appel pour le même refus.
    if (error instanceof FalError || error instanceof CircuitOpenError) throw error;
    return null;
  }
}

/** Ce qui précède toujours : la langue d'abord, puis pour qui on écrit. */
function audienceSections(body: RequestBody, sample: string): string[] {
  const sections = [languageBrief(body.language), audienceBrief(body.level, body.country)];
  const stage = stageBrief(body.schoolStage);
  if (stage) sections.push(stage);
  const discipline = disciplineBrief(detectDiscipline(sample, body.lessonTitle ?? body.title, body.subject));
  if (discipline) sections.push(discipline);
  return sections;
}

// MARK: - Le plan

async function plan(request: Request, body: RequestBody): Promise<Response> {
  const caller = readCaller(request);
  if (!isLessonId(body.lessonId)) throw new FalError("Identifiant de leçon manquant.", 400);

  const fromScratch = typeof body.topic === "string";
  const raw = (body.text ?? "").trim();
  const shortened = raw.length > MAX_SOURCE;
  const text = raw.slice(0, MAX_SOURCE);
  const images = acceptedImages(body.images);
  const topic = sanitizeMeta(body.topic, MAX_TOPIC);

  if (fromScratch && topic.length < 2) {
    throw new FalError("Dis-moi ce que tu veux apprendre.", 400);
  }
  if (!fromScratch && text.length < 40 && images.length === 0) {
    throw new FalError("Le document ne contient pas assez de contenu à analyser.", 400);
  }

  const source = normalizeSource(body.source, fromScratch);
  await beginLesson(caller, {
    lessonId: body.lessonId,
    kind: "create",
    source,
    themes: 0,
    onboarding: body.onboarding === true,
  });
  await consumeQuota(caller, "generate-lesson");

  const meter: ModelUsage[] = [];

  let visualNotes = "";
  if (images.length > 0) {
    try {
      visualNotes = await callModel({
        prompt: "Voici les pages d'un document de cours. Décris précisément les éléments visuels utiles à la compréhension.",
        systemPrompt: VISION_SYSTEM_PROMPT,
        imageUrls: images,
        temperature: 0.2,
        maxTokens: 1_600,
        meter,
      });
    } catch (_error) {
      visualNotes = "";
    }
  }

  const reference = [text, visualNotes].filter(Boolean).join("\n\n").slice(0, MAX_SOURCE);
  const shortSource = !fromScratch && reference.length < SHORT_SOURCE;

  const sections = audienceSections(body, fromScratch ? topic : reference);
  sections.push(planShapeBrief({ shortSource, fromScratch }));
  sections.push(iconsSection());
  if (fromScratch) {
    sections.push(`SUJET DEMANDÉ PAR L'ÉLÈVE\n${topic}`);
  } else {
    const reading = readingBrief(body.source, text.length);
    if (reading) sections.push(reading);
    const name = sanitizeMeta(body.sourceName, 200);
    if (name) sections.push(`Nom du fichier : ${name}`);
    sections.push(wrapUntrusted("SUPPORTS DE L'ÉLÈVE", reference));
  }
  sections.push("Écris maintenant le JSON du plan.");
  const prompt = sections.join("\n\n");

  const fallbackTitle = fromScratch ? clampWords(topic, LIMITS.lessonTitleWords) : "Ma leçon";
  const read = (parsed: Record<string, unknown> | null) =>
    parsed ? readPlan(parsed, { shortSource, shortened, fallbackTitle }) : null;

  let lessonPlan = read(await ask({ prompt, system: PLAN_SYSTEM_PROMPT, temperature: 0.3, maxTokens: PLAN_TOKENS, meter }));
  if (!lessonPlan) {
    lessonPlan = read(await ask({
      prompt: `${prompt}\n\nTa réponse précédente était illisible ou incomplète. Rends le JSON complet, avec au moins 4 thèmes.`,
      system: PLAN_SYSTEM_PROMPT,
      temperature: 0.15,
      maxTokens: PLAN_TOKENS,
      meter,
    }));
  }
  if (!lessonPlan) {
    throw new FalError("Le plan de la leçon n'a pas pu s'écrire. Réessaie.", 502);
  }

  // La leçon connaît maintenant son nombre de thèmes : c'est lui qui borne les « Réessayer ».
  await beginLesson(caller, {
    lessonId: body.lessonId,
    kind: "create",
    source,
    themes: lessonPlan.themes.length,
  });

  return jsonResponse({
    plan: lessonPlan,
    // Le texte de référence de chaque thème. Vide en mode « sujet » : chaque thème s'écrit
    // alors depuis ce que le modèle sait.
    contextText: fromScratch ? "" : reference,
    meta: { promptVersion: PROMPT_VERSION, usage: totalUsage(meter) },
  });
}

// MARK: - Un thème

async function theme(request: Request, body: RequestBody): Promise<Response> {
  const caller = readCaller(request);
  if (!isLessonId(body.lessonId)) throw new FalError("Identifiant de leçon manquant.", 400);

  const themes = (Array.isArray(body.themes) ? body.themes : [])
    .map((title) => sanitizeMeta(typeof title === "string" ? title : "", 120))
    .filter(Boolean)
    .slice(0, 30);
  const index = typeof body.themeIndex === "number" ? Math.round(body.themeIndex) : -1;
  if (index < 0 || index >= themes.length) throw new FalError("Thème inconnu.", 400);

  await admitThemeCall(caller, body.lessonId);
  await consumeQuota(caller, "generate-lesson-theme", 1, THEME_DAILY_CEILING);

  const context = (body.context ?? "").trim().slice(0, MAX_SOURCE);
  const lessonTitle = sanitizeMeta(body.lessonTitle, 200) || themes[index]!;
  const meter: ModelUsage[] = [];

  const sections = audienceSections(body, context || lessonTitle);
  sections.push(themeBrief({ lessonTitle, themeTitle: themes[index]!, themeIndex: index, themes }));
  if (context) {
    sections.push(
      "Appuie-toi sur les supports de l'élève ci-dessous : ce qu'ils disent passe avant ce que tu sais. Ne recopie pas, réécris en notes.",
    );
    sections.push(wrapUntrusted("SUPPORTS DE L'ÉLÈVE", context));
  } else {
    sections.push("Il n'y a pas de document : écris depuis ce que tu sais, au niveau de l'élève, sans rien inventer de douteux.");
  }
  sections.push("Écris maintenant le JSON de ce thème.");
  const prompt = sections.join("\n\n");
  const seed = `${body.lessonId}:${index}`;

  const read = (parsed: Record<string, unknown> | null) => {
    if (!parsed) return null;
    const notes = readNotes(parsed);
    const questions = readQuestions(parsed.questions, seed);
    if (!notes || questions.length < 2) return null;
    return { notes, questions, flashcards: readFlashcards(parsed.flashcards) };
  };

  let written = read(await ask({ prompt, system: THEME_SYSTEM_PROMPT, temperature: 0.35, maxTokens: THEME_TOKENS, meter }));
  if (!written) {
    written = read(await ask({
      prompt: `${prompt}\n\nTa réponse précédente était illisible ou incomplète. Rends le JSON complet : notes, 4 questions, 3 flashcards.`,
      system: THEME_SYSTEM_PROMPT,
      temperature: 0.2,
      maxTokens: THEME_TOKENS,
      meter,
    }));
  }
  if (!written) {
    throw new FalError("Ce thème n'a pas pu s'écrire. Réessaie.", 502);
  }

  return jsonResponse({
    theme: written,
    meta: { promptVersion: PROMPT_VERSION, usage: totalUsage(meter) },
  });
}

// MARK: - La conversion

async function convert(request: Request, body: RequestBody): Promise<Response> {
  const caller = readCaller(request);
  if (!isLessonId(body.lessonId)) throw new FalError("Identifiant de leçon manquant.", 400);

  let budget = CONVERT_TOTAL_TEXT;
  const chapters = (Array.isArray(body.chapters) ? body.chapters : [])
    .slice(0, 30)
    .map((chapter, index) => {
      const title = sanitizeMeta(chapter?.title, 120) || `Chapitre ${index + 1}`;
      const share = Math.min(CONVERT_CHAPTER_TEXT, Math.max(0, budget));
      const text = (chapter?.text ?? "").trim().slice(0, share);
      budget -= text.length;
      return { title, text, needsCards: chapter?.needsCards === true };
    });
  if (chapters.length === 0) throw new FalError("Ce cours n'a aucun chapitre.", 400);

  await beginLesson(caller, { lessonId: body.lessonId, kind: "convert", source: "convert", themes: chapters.length });
  await consumeQuota(caller, "generate-lesson");

  const title = sanitizeMeta(body.title, 200) || chapters[0]!.title;
  const groups = groupThemes(chapters.length);
  const meter: ModelUsage[] = [];

  const sample = chapters.map((chapter) => chapter.text).join("\n").slice(0, 6_000);
  const sections = audienceSections({ ...body, title }, sample);
  sections.push(iconsSection());
  sections.push(convertBrief({ title, groups, chapters }));
  sections.push(wrapUntrusted(
    "NOTES DES CHAPITRES",
    chapters.map((chapter, index) => `CHAPITRE ${index + 1} : ${chapter.title}\n${chapter.text}`).join("\n\n"),
  ));
  sections.push("Écris maintenant le JSON.");
  const prompt = sections.join("\n\n");

  const read = (parsed: Record<string, unknown> | null) => {
    if (!parsed) return null;
    const rawChapters = Array.isArray(parsed.chapters) ? parsed.chapters : [];
    const converted = chapters.map((chapter, index) => {
      const entry = (rawChapters[index] ?? {}) as Record<string, unknown>;
      return {
        icon: normalizeIcon(entry.icon),
        questions: readQuestions(entry.questions, `${body.lessonId}:${index}`),
        flashcards: chapter.needsCards ? readFlashcards(entry.flashcards) : [],
      };
    });
    const answered = converted.filter((chapter) => chapter.questions.length >= 2).length;
    if (answered * 2 < chapters.length) return null;
    const rawGroups = Array.isArray(parsed.groups) ? parsed.groups : [];
    const intro = (parsed.intro ?? {}) as Record<string, unknown>;
    return {
      icon: normalizeIcon(parsed.icon),
      intro: {
        lines: (Array.isArray(intro.lines) ? intro.lines : [])
          .map((line) => clampWords(cleanText(line, 200).replace(/\*\*/g, ""), 16))
          .filter(Boolean)
          .slice(0, LIMITS.introLines),
        minutes: estimateMinutes(chapters.length, groups.length),
      },
      takeaways: (Array.isArray(parsed.takeaways) ? parsed.takeaways : [])
        .map((line) => clampWords(cleanText(line, 300), 22))
        .filter(Boolean)
        .slice(0, LIMITS.lessonTakeaways),
      groups: groups.map((themes, index) => {
        const entry = (rawGroups[index] ?? {}) as Record<string, unknown>;
        return { name: clampWords(cleanText(entry.name, 80).replace(/\*\*/g, ""), 5), themes };
      }),
      chapters: converted,
    };
  };

  let conversion = read(await ask({ prompt, system: CONVERT_SYSTEM_PROMPT, temperature: 0.3, maxTokens: convertTokens(chapters.length), meter }));
  if (!conversion) {
    conversion = read(await ask({
      prompt: `${prompt}\n\nTa réponse précédente était illisible ou incomplète. Rends le JSON complet, une entrée par chapitre.`,
      system: CONVERT_SYSTEM_PROMPT,
      temperature: 0.15,
      maxTokens: convertTokens(chapters.length),
      meter,
    }));
  }
  if (!conversion) {
    throw new FalError("La leçon n'a pas pu se préparer. Réessaie.", 502);
  }

  return jsonResponse({
    conversion,
    meta: { promptVersion: PROMPT_VERSION, usage: totalUsage(meter) },
  });
}

Deno.serve((request: Request) =>
  withCors(request, async () => {
    try {
      const body = (await request.json()) as RequestBody;
      switch (body.stage) {
        case "plan":
          return await plan(request, body);
        case "theme":
          return await theme(request, body);
        case "convert":
          return await convert(request, body);
        default:
          throw new FalError("Étape inconnue.", 400);
      }
    } catch (error) {
      if (error instanceof LessonGateError) {
        return jsonResponse({ error: error.message, code: error.code }, error.status);
      }
      return errorResponse(error);
    }
  })
);
