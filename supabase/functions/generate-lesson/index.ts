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
 * - `stage: "exam"` — un examen blanc chronométré sur une ou plusieurs leçons, au format de
 *   l'examen visé ; un gratuit, puis Pro (`begin_extra`, `exam`).
 * - `stage: "practice"` — de nouvelles questions d'entraînement sur une leçon déjà écrite,
 *   loin de celles déjà posées, surtout sur les thèmes ratés. Un lot gratuit, puis Pro
 *   (`begin_extra`, migration `lesson_extras`).
 *
 * Le volume (thèmes, questions, cartes) et le registre suivent la marche d'études et le pays
 * de l'élève (`_shared/learner.ts`). La structure du plan suit la nature du support (un
 * chapitre, une copie, un sujet d'examen, une vidéo…), qui voyage jusqu'aux thèmes en tête du
 * texte de référence (`material.ts`). Les questions prennent cinq formes (`schema.ts`) ; une
 * app qui ne déclare pas les formes qu'elle sait afficher (`kinds`) ne reçoit que des QCM.
 *
 * Déployer : `supabase functions deploy generate-lesson`, après les migrations
 * `lesson_generations` et `lesson_gate_hardening` (la porte du gratuit) et `anon_ai_budget`
 * (le budget des appels sans compte), ou par `pin.sh`. La porte ferme quand la base ne
 * répond pas : déployée avant ses migrations, elle refuserait en 503.
 */
import {
  ANON_DAILY_CEILING,
  type Caller,
  consumeQuota,
  readCaller,
  requireAccount,
  withCors,
} from "../_shared/caller.ts";
import { deadlineIn, earliest } from "../_shared/deadline.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { callModel, errorResponse, FalError, jsonResponse } from "../_shared/fal.ts";
import { CircuitOpenError } from "../_shared/circuit.ts";
import { describeModelOutput, parseModelJSON } from "../_shared/json.ts";
import { type ModelUsage, totalUsage } from "../_shared/usage.ts";
import { detectDiscipline, disciplineBrief, lessonShapesBrief } from "../_shared/discipline.ts";
import { languageBrief } from "../_shared/language.ts";
import { sanitizeMeta, wrapUntrusted } from "../_shared/prompt-boundary.ts";
import { normalizeIcon } from "../_shared/icons.ts";
import { readingBrief, VISION_SYSTEM_PROMPT } from "../generate-course/prompt.ts";
import { depthOf, learnerBrief, readLearner, volumeOf } from "../_shared/learner.ts";
import { assessmentBrief, disciplineName, hasVariedKinds } from "../_shared/assessment.ts";
import {
  CONVERT_SYSTEM_PROMPT,
  convertBrief,
  EXAM_SYSTEM_PROMPT,
  EXAM_TOKENS,
  examBrief,
  examNotes,
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
  fairShares,
  fallbackLessonTitle,
  finalFirst,
  groupThemes,
  LIMITS,
  MAX_SOURCE,
  noteLimits,
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
  refundExtra,
  releaseLesson,
} from "./gate.ts";
import {
  allowedRole,
  guessMaterial,
  guessRole,
  isExamOriented,
  type Material,
  materialHeader,
  planMaterialBrief,
  readMaterial,
  readMaterialHeader,
  readRole,
} from "./material.ts";
import { excerptForTheme, GAP as EXCERPT_GAP } from "./excerpt.ts";

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
  /** Le niveau actuel de l'élève, de 0 à 100 sur l'échelle de l'app (`learner.ts`). */
  currentScore?: number;
  /** Son objectif, de 0 à 100. */
  targetScore?: number;
  /** La note actuelle telle qu'il la dit : « 12/20 », « B+ ». */
  scoreLabel?: string;
  /** L'objectif tel qu'il le dit : « 16/20 », « A ». */
  targetLabel?: string;
  /** Ce qui le freine : examStress, hardLessons, homework, forgetting, noStart, motivation. */
  worries?: string[];
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
  /**
   * Le texte de référence rendu par le plan (`contextText`). Il commence par la nature du
   * support et les rôles des thèmes (`materialHeader`) : c'est par lui qu'ils arrivent ici.
   */
  context?: string;
  /** La nature du support, pour une app qui la renverrait d'elle-même ; facultative. */
  material?: string;
  /** Le rôle de ce thème, pour une app qui le renverrait d'elle-même ; facultatif. */
  role?: string;

  // Un examen blanc
  examTitle?: string;
  minutes?: number;
  lessons?: { title?: string; subject?: string; themes?: { title?: string; notes?: string }[] }[];

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
/**
 * Le budget commun des thèmes sans compte (`consumeQuota`) : une leçon en coûte une dizaine,
 * le plan une seule. Le même rapport qu'entre `THEME_DAILY_CEILING` et `DAILY_CEILING`.
 */
const ANON_THEME_CEILING = ANON_DAILY_CEILING * 3;
/** La passe visuelle du plan : elle ne doit pas laisser le plan lui-même sans temps. */
const VISION_BUDGET_MS = 60_000;
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

/**
 * Un appel au modèle qui rend un objet JSON, ou `null` quand la réponse est illisible.
 *
 * **Une réponse illisible laisse sa forme dans les journaux.** Le 21 octobre 2026,
 * quarante-cinq thèmes ont fini en « Ce thème n'a pas pu s'écrire » sans qu'une ligne dise si
 * le modèle avait répondu en prose, tronqué son JSON ou rendu un tableau : ce chemin-ci ne
 * passait pas par `extractJSON`, le seul qui décrivait la sortie. `etape` nomme l'appel.
 */
async function ask(
  options: {
    prompt: string;
    system: string;
    temperature: number;
    maxTokens: number;
    meter: ModelUsage[];
    model?: string;
    step?: string;
    /** L'échéance de la requête : voir `_shared/deadline.ts`. */
    deadline?: number;
  },
): Promise<Record<string, unknown> | null> {
  let output: string;
  try {
    output = await callModel({
      prompt: options.prompt,
      systemPrompt: options.system,
      temperature: options.temperature,
      maxTokens: options.maxTokens,
      meter: options.meter,
      model: options.model ?? WRITING_MODEL,
      deadline: options.deadline,
    });
  } catch (error) {
    // Une panne du fournisseur n'est pas une réponse illisible : la retenter tout de suite
    // paierait un second appel pour le même refus.
    if (error instanceof FalError || error instanceof CircuitOpenError) throw error;
    console.error(JSON.stringify({ json: "panne", etape: options.step ?? null }));
    return null;
  }

  let parsed: unknown;
  try {
    parsed = parseModelJSON<unknown>(output);
  } catch (error) {
    const detail = error instanceof Error ? error.message : "";
    console.error(JSON.stringify({
      json: detail.includes("n'a pas renvoyé de JSON") ? "absent" : "illisible",
      etape: options.step ?? null,
      ...describeModelOutput(output, error),
    }));
    return null;
  }
  if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
    return parsed as Record<string, unknown>;
  }
  console.error(JSON.stringify({
    json: "forme",
    etape: options.step ?? null,
    type: Array.isArray(parsed) ? "tableau" : typeof parsed,
  }));
  return null;
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

async function plan(request: Request, body: RequestBody, deadline: number): Promise<Response> {
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
  try {
    return await writePlan(body, { caller, fromScratch, shortened, text, images, topic, source, deadline });
  } catch (error) {
    // Aucun plan n'est parti : la leçon réservée est rendue. Sans cela, une panne du modèle
    // au premier essai coûtait la leçon offerte, et l'élève tombait sur le paywall sans
    // avoir rien reçu. L'échéance (`deadline`) est ce qui garantit qu'on arrive ici : sans
    // elle, la passe visuelle, le plan et son second essai dépassaient l'horloge de la
    // plateforme, qui tuait la fonction avant ce `catch`.
    await releaseLesson(caller, body.lessonId);
    throw error;
  }
}

/** Le plan lui-même, une fois la leçon réservée : tout ce qui peut échouer est ici. */
async function writePlan(
  body: RequestBody,
  options: {
    caller: Caller;
    fromScratch: boolean;
    shortened: boolean;
    text: string;
    images: string[];
    topic: string;
    source: string;
    deadline: number;
  },
): Promise<Response> {
  const { caller, fromScratch, shortened, text, images, topic, source, deadline } = options;
  const lessonId = body.lessonId!;
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
        // La passe visuelle est un complément : elle ne prend pas au plan le temps qu'il lui
        // faut. Coupée, le plan s'écrit sur le texte seul, comme quand elle échoue.
        deadline: earliest(deadline, Date.now() + VISION_BUDGET_MS),
      });
    } catch (_error) {
      visualNotes = "";
    }
  }

  const reference = [text, visualNotes].filter(Boolean).join("\n\n").slice(0, MAX_SOURCE);
  const shortSource = !fromScratch && reference.length < SHORT_SOURCE;

  const learner = readLearner(body);
  const volume = volumeOf(learner.tier);
  const examOriented = isExamOriented(learner);
  // Une première lecture du support : le modèle la corrige, sauf quand elle ne fait pas de
  // doute (pas de document, ou une vidéo et sa transcription).
  const guess: Material = fromScratch ? "topic" : guessMaterial(reference, source);
  const forcedMaterial: Material | undefined = guess === "topic" || guess === "lecture" ? guess : undefined;
  const sections = audienceSections(body, fromScratch ? topic : reference);
  sections.push(planShapeBrief({ shortSource, fromScratch, topicThemes: volume.topicThemes, maxThemes: volume.maxThemes }));
  sections.push(planMaterialBrief({ guess, fromScratch, register: depthOf(learner.tier).register, examOriented }));
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

  // Le titre de repli s'affiche en tête du chemin : il est dans la langue de l'app.
  const fallbackTitle = fromScratch ? clampWords(topic, LIMITS.lessonTitleWords) : fallbackLessonTitle(body.language);
  const read = (parsed: Record<string, unknown> | null) =>
    parsed
      ? readPlan(parsed, {
        shortSource,
        shortened,
        fallbackTitle,
        maxThemes: volume.maxThemes,
        fallbackMaterial: guess,
        forcedMaterial,
        examOriented,
      })
      : null;

  let parsedPlan = await ask({ prompt, system: PLAN_SYSTEM_PROMPT, temperature: 0.3, maxTokens: PLAN_TOKENS, meter, step: "plan", deadline });
  let lessonPlan = read(parsedPlan);
  if (!lessonPlan) {
    if (parsedPlan) console.error(JSON.stringify({ plan: "invalide", cles: Object.keys(parsedPlan).slice(0, 12) }));
    parsedPlan = await ask({
      prompt: `${prompt}\n\nTa réponse précédente était illisible ou incomplète. Rends le JSON complet, avec au moins 4 thèmes.`,
      system: PLAN_SYSTEM_PROMPT,
      temperature: 0.15,
      maxTokens: PLAN_TOKENS,
      meter,
      step: "plan",
      deadline,
    });
    lessonPlan = read(parsedPlan);
  }
  if (!lessonPlan) {
    if (parsedPlan) console.error(JSON.stringify({ plan: "invalide", cles: Object.keys(parsedPlan).slice(0, 12) }));
    throw new FalError(
      "Le plan de la leçon n'a pas pu s'écrire. Réessaie.",
      502,
      undefined,
      parsedPlan ? "invalid_content" : "invalid_json",
    );
  }

  // La leçon connaît maintenant son nombre de thèmes : c'est lui qui borne les « Réessayer ».
  await beginLesson(caller, {
    lessonId,
    kind: "create",
    source,
    themes: lessonPlan.themes.length,
  });

  // Le texte de référence de chaque thème, précédé de la nature du support et des rôles des
  // thèmes : les apps le renvoient tel quel à chaque thème, c'est par là qu'ils voyagent. Vide en
  // mode « sujet » (chaque thème s'écrit depuis ce que le modèle sait, et se sait « topic »).
  const header = materialHeader(lessonPlan.material, lessonPlan.themes.map((entry) => entry.role));
  return jsonResponse({
    plan: lessonPlan,
    contextText: fromScratch ? "" : header + reference.slice(0, MAX_SOURCE - header.length),
    meta: { promptVersion: PROMPT_VERSION, usage: totalUsage(meter) },
  });
}

// MARK: - Un thème

async function theme(request: Request, body: RequestBody, deadline: number): Promise<Response> {
  const caller = readCaller(request);
  if (!isLessonId(body.lessonId)) throw new FalError("Identifiant de leçon manquant.", 400);

  const themes = (Array.isArray(body.themes) ? body.themes : [])
    .map((title) => sanitizeMeta(typeof title === "string" ? title : "", 120))
    .filter(Boolean)
    .slice(0, 30);
  const index = typeof body.themeIndex === "number" ? Math.round(body.themeIndex) : -1;
  if (index < 0 || index >= themes.length) throw new FalError("Thème inconnu.", 400);

  await admitThemeCall(caller, body.lessonId);
  await consumeQuota(caller, "generate-lesson-theme", 1, THEME_DAILY_CEILING, undefined, ANON_THEME_CEILING);

  // L'en-tête du texte de référence dit la nature du support et le rôle de chaque thème ; une
  // leçon d'avant n'en a pas, et les deux se devinent alors sur le texte et sur le titre.
  const carried = readMaterialHeader((body.context ?? "").trim());
  const context = carried.text.trim().slice(0, MAX_SOURCE);
  const material: Material = readMaterial(body.material) ?? carried.material ??
    (context ? guessMaterial(context, body.source) : "topic");
  const carriedRole = carried.roles?.length === themes.length ? carried.roles[index] : undefined;
  const lessonTitle = sanitizeMeta(body.lessonTitle, 200) || themes[index]!;
  const meter: ModelUsage[] = [];
  const learner = readLearner(body);
  const volume = volumeOf(learner.tier);
  // Jusqu'où expliquer : le nombre de blocs et leur longueur suivent la marche, et un examen
  // nommé appelle toujours une question à son format.
  const tierDepth = depthOf(learner.tier);
  const depth = learner.exam ? { ...tierDepth, examFormat: true } : tierDepth;
  const limits = noteLimits(depth);
  const examOriented = isExamOriented(learner);
  const role = allowedRole(
    typeof body.role === "string" ? readRole(body.role) : carriedRole ?? guessRole(themes[index]!, material),
    material,
    examOriented || (material === "topic" && themes.some((title) => guessRole(title, material) === "decrypt")),
  );
  const kinds = readKinds(body.kinds);
  const points = (Array.isArray(body.points) ? body.points : []).slice(0, themes.length).map((list) =>
    (Array.isArray(list) ? list : []).map((point) => sanitizeMeta(typeof point === "string" ? point : "", 100)).filter(Boolean).slice(0, LIMITS.pointsPerTheme)
  );
  const objectives = (Array.isArray(body.objectives) ? body.objectives : [])
    .map((line) => sanitizeMeta(typeof line === "string" ? line : "", 160))
    .filter(Boolean)
    .slice(0, LIMITS.introLines);

  const sample = context || lessonTitle;
  const sections = audienceSections(body, sample);
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
    depth,
    material,
    role,
    examOriented,
  }));
  // Les formes de bloc que la matière appelle : sans elles, chaque thème avait le même squelette.
  sections.push(lessonShapesBrief(detectDiscipline(sample, body.lessonTitle ?? body.title, body.subject)));
  // Les questions du thème sont celles de tous les quiz de la leçon : elles suivent la même
  // consigne de formes que l'entraînement et l'examen blanc, selon la matière et la marche.
  // Sans elle, un collégien et un étudiant en santé recevaient le même mélange de formes.
  sections.push(assessmentBrief({
    tier: learner.tier,
    disciplines: [detectDiscipline(sample, body.lessonTitle, body.subject)],
    count: volume.questions,
  }));
  if (context) {
    const reading = readingBrief(body.source, context.length);
    if (reading) sections.push(reading);
    // Le passage du thème, pas tout le document : voir `excerpt.ts`. Les points que le plan
    // lui a donnés désignent ses passages mieux que son titre seul.
    const excerpt = excerptForTheme(context, themes, index, points);
    const cut = excerpt.length < context.length;
    if (cut) {
      console.log(JSON.stringify({
        extrait: { theme: index, avant: context.length, apres: excerpt.length },
      }));
    }
    sections.push(
      (cut
        ? `Les supports ci-dessous sont des EXTRAITS du document de l'élève, choisis pour ce thème ; ${EXCERPT_GAP} marque un passage retiré. `
        : "") +
        "Appuie-toi sur les supports de l'élève ci-dessous : ce qu'ils disent passe avant ce que tu sais. Ne recopie pas, réécris en notes. Ne traite que ce qui concerne CE thème, mais traite-le en entier : ce que le support en dit (ses auteurs, ses dates, ses chiffres, ses exemples) se retrouve dans les notes, condensé, jamais omis.",
    );
    sections.push(wrapUntrusted("SUPPORTS DE L'ÉLÈVE", excerpt));
  } else {
    sections.push(SCRATCH_RULES);
  }
  sections.push("Écris maintenant le JSON de ce thème.");
  const prompt = sections.join("\n\n");
  const seed = `${body.lessonId}:${index}`;

  const read = (parsed: Record<string, unknown> | null) => {
    if (!parsed) return null;
    const notes = readNotes(parsed, limits);
    const questions = finalFirst(readQuestions(parsed.questions, seed, { kinds, language: body.language, max: volume.questions }));
    if (!notes || questions.length < LIMITS.minQuestions) {
      // Le JSON se lisait, c'est son contenu qui ne passe pas : des notes vides, ou trop peu
      // de questions. Le dire sépare ce cas de la réponse illisible, que `ask` a déjà décrite.
      console.error(JSON.stringify({
        theme: "invalide",
        index,
        notes: Boolean(notes),
        questions: questions.length,
        cles: Object.keys(parsed).slice(0, 12),
      }));
      return null;
    }
    return { notes, questions, flashcards: readFlashcards(parsed.flashcards, volume.flashcards) };
  };

  let parsedTheme = await ask({ prompt, system: THEME_SYSTEM_PROMPT, temperature: 0.35, maxTokens: THEME_TOKENS, meter, step: "theme", deadline });
  let written = read(parsedTheme);
  if (!written) {
    parsedTheme = await ask({
      prompt: `${prompt}\n\nTa réponse précédente était illisible ou incomplète. Rends le JSON complet : notes, ${volume.questions} questions, ${volume.flashcards} flashcards.`,
      system: THEME_SYSTEM_PROMPT,
      temperature: 0.2,
      maxTokens: THEME_TOKENS,
      meter,
      step: "theme",
      deadline,
    });
    written = read(parsedTheme);
  }
  if (!written) {
    throw new FalError(
      "Ce thème n'a pas pu s'écrire. Réessaie.",
      502,
      undefined,
      parsedTheme ? "invalid_content" : "invalid_json",
    );
  }

  return jsonResponse({
    theme: written,
    meta: { promptVersion: PROMPT_VERSION, usage: totalUsage(meter) },
  });
}

// MARK: - La conversion

async function convert(request: Request, body: RequestBody, deadline: number): Promise<Response> {
  const caller = readCaller(request);
  // La conversion lit trente chapitres d'un coup : c'est une étape lourde, que la clé
  // publiable ne paye pas. Le refus dit de mettre l'app à jour ; le cours reste ouvrable
  // sans le modèle (`convertOffline` sur l'iPhone et le site).
  requireAccount(caller);
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
        questions: finalFirst(readQuestions(entry.questions, `${body.lessonId}:${index}`, {
          kinds: readKinds(body.kinds).filter((kind) => kind === "choice" || kind === "truefalse"),
          language: body.language,
          max: 5,
        })),
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

  let conversion = read(await ask({ prompt, system: CONVERT_SYSTEM_PROMPT, temperature: 0.3, maxTokens: convertTokens(chapters.length), meter, step: "convert", deadline }));
  if (!conversion) {
    conversion = read(await ask({
      prompt: `${prompt}\n\nTa réponse précédente était illisible ou incomplète. Rends le JSON complet, une entrée par chapitre.`,
      system: CONVERT_SYSTEM_PROMPT,
      temperature: 0.15,
      maxTokens: convertTokens(chapters.length),
      meter,
      step: "convert",
      deadline,
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

async function practice(request: Request, body: RequestBody, deadline: number): Promise<Response> {
  const caller = readCaller(request);
  if (!isLessonId(body.lessonId)) throw new FalError("Identifiant de leçon manquant.", 400);

  const rawThemes = (Array.isArray(body.practiceThemes) ? body.practiceThemes : [])
    .slice(0, 30)
    .map((entry, index) => ({
      title: sanitizeMeta(entry?.title, 120) || `${index + 1}`,
      notes: (typeof entry?.notes === "string" ? entry.notes : "").trim().slice(0, PRACTICE_THEME_NOTES),
    }));
  // Le budget se partage entre tous les thèmes, pas dans l'ordre : les derniers ont leurs
  // notes, et donc leurs questions.
  const practiceShares = fairShares(rawThemes.map((theme) => theme.notes.length), PRACTICE_TOTAL_NOTES);
  const themes = rawThemes.map((theme, index) => ({ title: theme.title, notes: theme.notes.slice(0, practiceShares[index]) }));
  // Les rangs restent ceux de l'app, même pour un thème sans notes : c'est par eux qu'une
  // question retrouve son thème.
  if (!themes.some((theme) => theme.notes.length > 0)) throw new FalError("Cette leçon n'a pas encore de notes.", 400);

  const extra = { kind: "practice", lessonId: body.lessonId } as const;
  await beginExtra(caller, extra);
  try {
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
    sections.push(assessmentBrief({
      tier: readLearner(body).tier,
      disciplines: [detectDiscipline(themes.map((theme) => theme.notes).join("\n"), lessonTitle, body.subject)],
      count,
    }));
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

    let questions = read(await ask({ prompt, system: PRACTICE_SYSTEM_PROMPT, temperature: 0.7, maxTokens: PRACTICE_TOKENS, meter, step: "practice", deadline }));
    if (!questions) {
      questions = read(await ask({
        prompt: `${prompt}\n\nTa réponse précédente était illisible ou incomplète. Rends le JSON complet, avec ${count} questions.`,
        system: PRACTICE_SYSTEM_PROMPT,
        temperature: 0.5,
        maxTokens: PRACTICE_TOKENS,
        meter,
        step: "practice",
        deadline,
      }));
    }
    if (!questions) {
      throw new FalError("Les nouvelles questions n'ont pas pu s'écrire. Réessaie.", 502);
    }

    return jsonResponse({
      questions,
      meta: { promptVersion: PROMPT_VERSION, usage: totalUsage(meter) },
    });
  } catch (error) {
    // Rien ne s'est écrit : le supplément est rendu, l'essai gratuit ne se perd pas.
    await refundExtra(caller, extra);
    throw error;
  }
}

// MARK: - L'examen blanc

const EXAM_LESSON_NOTES = 8_000;
const EXAM_TOTAL_NOTES = 48_000;

async function exam(request: Request, body: RequestBody, deadline: number): Promise<Response> {
  const caller = readCaller(request);
  if (!isLessonId(body.lessonId)) throw new FalError("Identifiant d'examen manquant.", 400);

  const rawLessons = (Array.isArray(body.lessons) ? body.lessons : []).slice(0, 8).map((lesson) => ({
    lesson,
    themes: (Array.isArray(lesson?.themes) ? lesson.themes : []).slice(0, 14).map((theme, rank) => ({
      title: sanitizeMeta(theme?.title, 120) || `${rank + 1}`,
      notes: (typeof theme?.notes === "string" ? theme.notes : "").trim(),
    })),
  }));
  // Le budget se partage équitablement : entre les leçons, puis entre les thèmes de chacune.
  // Coupé dans l'ordre, il laissait sans notes la fin de chaque leçon, et l'examen blanc
  // n'interrogeait que sur ses premiers thèmes.
  const lessonShares = fairShares(
    rawLessons.map((entry) => Math.min(EXAM_LESSON_NOTES, entry.themes.reduce((sum, theme) => sum + theme.notes.length, 0))),
    EXAM_TOTAL_NOTES,
  );
  const lessons = rawLessons.map(({ lesson, themes: rawThemes }, index) => {
    const shares = fairShares(rawThemes.map((theme) => theme.notes.length), lessonShares[index]!);
    const themes = rawThemes.map((theme, rank) => ({ title: theme.title, notes: theme.notes.slice(0, shares[rank]) }));
    const title = sanitizeMeta(lesson?.title, 160) || `${index + 1}`;
    const notes = themes.map((theme) => theme.notes).join("\n");
    // La matière de chaque leçon : un examen sur l'histoire et les maths ne se compose pas
    // comme un seul sujet.
    const discipline = detectDiscipline(notes, title, sanitizeMeta(lesson?.subject, 80));
    return { title, discipline, themes };
  });
  if (!lessons.some((lesson) => lesson.themes.some((theme) => theme.notes.length > 0))) {
    throw new FalError("Ces leçons n'ont pas encore de notes.", 400);
  }

  const extra = { kind: "exam", lessonId: body.lessonId } as const;
  await beginExtra(caller, extra);
  try {
    await consumeQuota(caller, "generate-lesson-exam");

    const kinds = readKinds(body.kinds);
    const minutes = Math.min(120, Math.max(10, Math.round(typeof body.minutes === "number" ? body.minutes : 30)));
    const count = Math.min(LIMITS.examMax, Math.max(6, Math.round(typeof body.count === "number" ? body.count : minutes / 1.5)));
    const title = sanitizeMeta(body.examTitle, 120);
    const meter: ModelUsage[] = [];

    const learner = readLearner(body);
    // Pas la consigne de matière des notes : celle des questions, matière par matière, au
    // niveau de l'élève (`assessment.ts`).
    const sections = [languageBrief(body.language), learnerBrief(learner)];
    sections.push(examBrief({
      title,
      lessons: lessons.map((lesson) => ({
        title: lesson.title,
        subject: disciplineName(lesson.discipline),
        themes: lesson.themes.map((theme) => theme.title),
      })),
      count,
      minutes,
      kinds,
    }));
    sections.push(assessmentBrief({ tier: learner.tier, disciplines: lessons.map((lesson) => lesson.discipline), count }));
    sections.push(wrapUntrusted("NOTES DES LEÇONS", examNotes(lessons)));
    sections.push("Écris maintenant le JSON de l'examen blanc.");
    const prompt = sections.join("\n\n");
    const seed = `${body.lessonId}:exam`;

    const read = (parsed: Record<string, unknown> | null) => {
      if (!parsed) return null;
      const questions = readQuestions(parsed.questions, seed, { kinds, language: body.language, max: count })
        .map((question) => {
          const lesson = question.lesson !== undefined && question.lesson >= 0 && question.lesson < lessons.length ? question.lesson : 0;
          const themeCount = lessons[lesson]!.themes.length;
          const theme = question.theme !== undefined && question.theme >= 0 && question.theme < themeCount ? question.theme : 0;
          return { ...question, lesson, theme };
        });
      if (questions.length < Math.min(6, count)) return null;
      return {
        title: clampWords(cleanText(parsed.title, 160).replace(/\*\*/g, ""), 10) || title,
        questions,
      };
    };

    let written = read(await ask({ prompt, system: EXAM_SYSTEM_PROMPT, temperature: 0.5, maxTokens: EXAM_TOKENS, meter, step: "exam", deadline }));
    // Une copie illisible, ou qui ne fait que des QCM, se réécrit une fois. La seconde copie
    // ne remplace la première que si elle se lit.
    if (!written || !hasVariedKinds(written.questions.map((question) => question.kind), kinds.length)) {
      const note = written
        ? `Ta copie ne variait pas assez ses formes. Réécris-la avec au moins trois formes différentes parmi ${kinds.join(", ")}, ${count} questions.`
        : `Ta réponse précédente était illisible ou incomplète. Rends le JSON complet, avec ${count} questions.`;
      written = read(await ask({
        prompt: `${prompt}\n\n${note}`,
        system: EXAM_SYSTEM_PROMPT,
        temperature: 0.4,
        maxTokens: EXAM_TOKENS,
        meter,
        step: "exam",
        deadline,
      })) ?? written;
    }
    if (!written) {
      throw new FalError("L'examen blanc n'a pas pu se composer. Réessaie.", 502);
    }

    return jsonResponse({
      exam: written,
      meta: { promptVersion: PROMPT_VERSION, usage: totalUsage(meter) },
    });
  } catch (error) {
    // Rien ne s'est écrit : le supplément est rendu, l'essai gratuit ne se perd pas.
    await refundExtra(caller, extra);
    throw error;
  }
}

Deno.serve((request: Request) =>
  withCors(request, async () => {
    // L'échéance de toute la requête, posée à son entrée : voir `_shared/deadline.ts`.
    const deadline = deadlineIn();
    try {
      const body = (await request.json()) as RequestBody;
      switch (body.stage) {
        case "plan":
          return await plan(request, body, deadline);
        case "theme":
          return await theme(request, body, deadline);
        case "convert":
          return await convert(request, body, deadline);
        case "practice":
          return await practice(request, body, deadline);
        case "exam":
          return await exam(request, body, deadline);
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
