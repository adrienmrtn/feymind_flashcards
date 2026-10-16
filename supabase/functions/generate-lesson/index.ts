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
 * - `stage: "practice"` — de nouvelles questions d'entraînement sur une leçon déjà écrite,
 *   loin de celles déjà posées, surtout sur les thèmes ratés. Un lot gratuit, puis Pro
 *   (`begin_extra`, migration `lesson_extras`).
 *
 * Le volume (thèmes, questions, cartes) et le registre suivent la marche d'études et le pays
 * de l'élève (`_shared/learner.ts`). Les questions prennent cinq formes (`schema.ts`) ; une
 * app qui ne déclare pas les formes qu'elle sait afficher (`kinds`) ne reçoit que des QCM.
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
import { readingBrief, VISION_SYSTEM_PROMPT } from "../generate-course/prompt.ts";
import { learnerBrief, readLearner, volumeOf } from "../_shared/learner.ts";
import {
  CONVERT_SYSTEM_PROMPT,
  convertBrief,
  convertTokens,
  iconsSection,
  PLAN_SYSTEM_PROMPT,
  PLAN_TOKENS,
  planShapeBrief,
  practiceBrief,
  practiceNotes,
  PRACTICE_SYSTEM_PROMPT,
  PRACTICE_TOKENS,
  PROMPT_VERSION,
  symbolsSection,
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
  readKinds,
  readNotes,
  readPlan,
  readQuestions,
  SHORT_SOURCE,
} from "./schema.ts";
import {
  admitThemeCall,
  beginExtra,
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
  /** Le palier tel que le pays le nomme : « Lycée », « Lise, YKS »… */
  schoolStage?: string;
  /** La marche d'études (`EducationTier`) : lowerSecondary, upperSecondary… */
  tier?: string;
  /** La filière : « Lycée général », « Gymnasium »… */
  track?: string;
  /** La classe ou l'année : « Terminale », « 4e », « Master 1 », « TYT »… */
  year?: string;
  /** L'examen visé : « Bac de français, le 2027-06-15 ». */
  exam?: string;
  subject?: string;
  /** Les formes de question que l'app sait afficher. Absent : des QCM seulement. */
  kinds?: string[];

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
  /** Les notions de chaque thème, données par le plan. */
  points?: string[][];
  /** Ce que l'élève saura faire à la fin (l'intro du plan). */
  objectives?: string[];
  context?: string;

  // De nouvelles questions
  practiceThemes?: { title?: string; notes?: string }[];
  focus?: number[];
  avoid?: string[];
  count?: number;

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
const PRACTICE_THEME_NOTES = 2_000;
const PRACTICE_TOTAL_NOTES = 24_000;
const PRACTICE_AVOID = 80;

/**
 * **Le modèle de l'écriture** : les notes et les questions sont ce que l'élève apprend par
 * cœur. Flash coûte quelques centimes de plus par leçon que Flash-Lite, et ne se trompe pas
 * de bonne réponse aussi souvent. Les replis de `fal.ts` restent les mêmes.
 */
const WRITING_MODEL = "google/gemini-2.5-flash";

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
  options: { prompt: string; system: string; temperature: number; maxTokens: number; meter: ModelUsage[]; model?: string },
): Promise<Record<string, unknown> | null> {
  try {
    const output = await callModel({
      prompt: options.prompt,
      systemPrompt: options.system,
      temperature: options.temperature,
      maxTokens: options.maxTokens,
      meter: options.meter,
      model: options.model ?? WRITING_MODEL,
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
  const sections = [languageBrief(body.language), learnerBrief(readLearner(body))];
  const discipline = disciplineBrief(detectDiscipline(sample, body.lessonTitle ?? body.title, body.subject));
  if (discipline) sections.push(discipline);
  return sections;
}

/**
 * Sans document, le modèle écrit depuis ce qu'il sait : il doit le dire moins plutôt que
 * l'inventer. Une leçon apprise par cœur ne se corrige plus.
 */
const SCRATCH_RULES =
  "Il n'y a pas de document : écris depuis ce que tu sais, au niveau de l'élève et selon son programme. Si tu n'es pas certain d'un fait, d'une date, d'un chiffre ou d'une définition, ÉCRIS-EN MOINS : une notion de moins vaut mieux qu'une notion fausse, que l'élève apprendrait par cœur. N'invente ni référence, ni citation, ni statistique.";

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

  const volume = volumeOf(readLearner(body).tier);
  const sections = audienceSections(body, fromScratch ? topic : reference);
  sections.push(planShapeBrief({ shortSource, fromScratch, topicThemes: volume.topicThemes, maxThemes: volume.maxThemes }));
  sections.push(iconsSection());
  sections.push(symbolsSection());
  if (fromScratch) {
    sections.push(SCRATCH_RULES);
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
    parsed ? readPlan(parsed, { shortSource, shortened, fallbackTitle, maxThemes: volume.maxThemes }) : null;

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
  const volume = volumeOf(readLearner(body).tier);
  const kinds = readKinds(body.kinds);
  const points = (Array.isArray(body.points) ? body.points : []).slice(0, themes.length).map((list) =>
    (Array.isArray(list) ? list : []).map((point) => sanitizeMeta(typeof point === "string" ? point : "", 100)).filter(Boolean).slice(0, LIMITS.pointsPerTheme)
  );
  const objectives = (Array.isArray(body.objectives) ? body.objectives : [])
    .map((line) => sanitizeMeta(typeof line === "string" ? line : "", 160))
    .filter(Boolean)
    .slice(0, LIMITS.introLines);

  const sections = audienceSections(body, context || lessonTitle);
  sections.push(themeBrief({
    lessonTitle,
    themeTitle: themes[index]!,
    themeIndex: index,
    themes,
    points,
    objectives,
    questions: volume.questions,
    flashcards: volume.flashcards,
    kinds,
  }));
  if (context) {
    const reading = readingBrief(body.source, context.length);
    if (reading) sections.push(reading);
    sections.push(
      "Appuie-toi sur les supports de l'élève ci-dessous : ce qu'ils disent passe avant ce que tu sais. Ne recopie pas, réécris en notes. Ne traite que ce qui concerne CE thème.",
    );
    sections.push(wrapUntrusted("SUPPORTS DE L'ÉLÈVE", context));
  } else {
    sections.push(SCRATCH_RULES);
  }
  sections.push("Écris maintenant le JSON de ce thème.");
  const prompt = sections.join("\n\n");
  const seed = `${body.lessonId}:${index}`;

  const read = (parsed: Record<string, unknown> | null) => {
    if (!parsed) return null;
    const notes = readNotes(parsed);
    const questions = readQuestions(parsed.questions, seed, { kinds, language: body.language, max: volume.questions });
    if (!notes || questions.length < LIMITS.minQuestions) return null;
    return { notes, questions, flashcards: readFlashcards(parsed.flashcards, volume.flashcards) };
  };

  let written = read(await ask({ prompt, system: THEME_SYSTEM_PROMPT, temperature: 0.35, maxTokens: THEME_TOKENS, meter }));
  if (!written) {
    written = read(await ask({
      prompt: `${prompt}\n\nTa réponse précédente était illisible ou incomplète. Rends le JSON complet : notes, ${volume.questions} questions, ${volume.flashcards} flashcards.`,
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
        questions: readQuestions(entry.questions, `${body.lessonId}:${index}`, {
          kinds: readKinds(body.kinds).filter((kind) => kind === "choice" || kind === "truefalse"),
          language: body.language,
          max: 5,
        }),
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

// MARK: - De nouvelles questions

async function practice(request: Request, body: RequestBody): Promise<Response> {
  const caller = readCaller(request);
  if (!isLessonId(body.lessonId)) throw new FalError("Identifiant de leçon manquant.", 400);

  let budget = PRACTICE_TOTAL_NOTES;
  const themes = (Array.isArray(body.practiceThemes) ? body.practiceThemes : [])
    .slice(0, 30)
    .map((entry, index) => {
      const title = sanitizeMeta(entry?.title, 120) || `${index + 1}`;
      const share = Math.min(PRACTICE_THEME_NOTES, Math.max(0, budget));
      const notes = (typeof entry?.notes === "string" ? entry.notes : "").trim().slice(0, share);
      budget -= notes.length;
      return { title, notes };
    });
  // Les rangs restent ceux de l'app, même pour un thème sans notes : c'est par eux qu'une
  // question retrouve son thème.
  if (!themes.some((theme) => theme.notes.length > 0)) throw new FalError("Cette leçon n'a pas encore de notes.", 400);

  await beginExtra(caller, { kind: "practice", lessonId: body.lessonId });
  await consumeQuota(caller, "generate-lesson-practice");

  const kinds = readKinds(body.kinds);
  const count = Math.min(LIMITS.practiceMax, Math.max(4, Math.round(typeof body.count === "number" ? body.count : 10)));
  const avoid = (Array.isArray(body.avoid) ? body.avoid : [])
    .map((prompt) => sanitizeMeta(typeof prompt === "string" ? prompt : "", 200))
    .filter(Boolean)
    .slice(-PRACTICE_AVOID);
  const focus = (Array.isArray(body.focus) ? body.focus : [])
    .filter((n): n is number => typeof n === "number" && Number.isFinite(n))
    .map((n) => Math.round(n))
    .slice(0, 12);
  const lessonTitle = sanitizeMeta(body.lessonTitle, 200) || themes[0]!.title;
  const meter: ModelUsage[] = [];

  const sections = audienceSections(body, themes.map((theme) => theme.notes).join("\n").slice(0, 6_000));
  sections.push(practiceBrief({ lessonTitle, themes, focus, avoid, count, kinds }));
  sections.push(wrapUntrusted("NOTES DE LA LEÇON", practiceNotes(themes)));
  sections.push("Écris maintenant le JSON des nouvelles questions.");
  const prompt = sections.join("\n\n");
  const seed = `${body.lessonId}:practice:${Date.now()}`;

  const read = (parsed: Record<string, unknown> | null) => {
    if (!parsed) return null;
    const questions = readQuestions(parsed.questions, seed, { kinds, language: body.language, max: count, avoid })
      .map((question) => ({
        ...question,
        theme: question.theme !== undefined && question.theme >= 0 && question.theme < themes.length ? question.theme : 0,
      }));
    return questions.length >= 3 ? questions : null;
  };

  let questions = read(await ask({ prompt, system: PRACTICE_SYSTEM_PROMPT, temperature: 0.7, maxTokens: PRACTICE_TOKENS, meter }));
  if (!questions) {
    questions = read(await ask({
      prompt: `${prompt}\n\nTa réponse précédente était illisible ou incomplète. Rends le JSON complet, avec ${count} questions.`,
      system: PRACTICE_SYSTEM_PROMPT,
      temperature: 0.5,
      maxTokens: PRACTICE_TOKENS,
      meter,
    }));
  }
  if (!questions) {
    throw new FalError("Les nouvelles questions n'ont pas pu s'écrire. Réessaie.", 502);
  }

  return jsonResponse({
    questions,
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
        case "practice":
          return await practice(request, body);
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
