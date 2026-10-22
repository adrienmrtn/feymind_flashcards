/**
 * **Les formats de la leçon**, tels que le serveur les écrit et que les deux clients les
 * lisent. Jumeaux de `Micabo/Models/Lesson.swift` ; voir `docs/refonte-parcours.md` § 8.
 *
 * Tout ce qui est ici se lit depuis du JSON **sans jamais échouer** : un bloc illisible
 * disparaît, une question d'avant les formes est un QCM, une progression absente est vide.
 * Une leçon écrite par une version plus récente du serveur se lit avec ce qu'on sait lire,
 * plutôt que de tomber en entier.
 */

// MARK: - Le plan

export type LessonPathStatus = "generating" | "ready" | "failed";

export interface LessonIntro {
  /** Trois lignes : ce que tu vas apprendre. */
  lines: string[];
  /** « Temps estimé : 25 min ». */
  minutes: number;
}

/** Un palier : un groupe de thèmes, et son nom (« Les causes »). Son quiz suit ses thèmes. */
export interface LessonGroup {
  name: string;
  /** Les rangs des thèmes du groupe, dans l'ordre. */
  themes: number[];
}

export interface LessonPath {
  version: number;
  /** L'icône 3D de la leçon, par son nom dans la base. */
  icon: string;
  intro: LessonIntro;
  /** « À retenir » : cinq phrases clés. */
  takeaways: string[];
  groups: LessonGroup[];
  /** Les supports dépassaient 60 000 caractères et ont été coupés. */
  shortened: boolean;
  /** Leçon très courte : un seul quiz pour tous les thèmes. */
  singleQuiz: boolean;
  status: LessonPathStatus;
  /** Le pictogramme de chaque thème sur le chemin, dans l'ordre. Absent sur une leçon d'avant. */
  symbols?: string[];
  /** Les notions que chaque thème doit couvrir, données par le plan. */
  points?: string[][];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringList(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function trimmed(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/** Le plan, lu depuis `courses.path`. `null` sans plan, ou sans ce qu'il faut pour un chemin. */
export function readLessonPath(raw: unknown): LessonPath | null {
  const source = typeof raw === "string" ? safeParse(raw) : raw;
  if (!isRecord(source)) return null;
  const intro = isRecord(source.intro) ? source.intro : null;
  if (typeof source.icon !== "string" || !intro) return null;
  const groups: LessonGroup[] = [];
  for (const entry of Array.isArray(source.groups) ? source.groups : []) {
    if (!isRecord(entry)) continue;
    const themes = Array.isArray(entry.themes)
      ? entry.themes.filter((item): item is number => Number.isInteger(item))
      : [];
    groups.push({ name: trimmed(entry.name), themes });
  }
  const status = source.status;
  const points = Array.isArray(source.points) ? source.points.map(stringList) : undefined;
  return {
    version: typeof source.version === "number" ? source.version : 1,
    icon: source.icon,
    intro: {
      lines: stringList(intro.lines),
      minutes: typeof intro.minutes === "number" ? intro.minutes : 0,
    },
    takeaways: stringList(source.takeaways),
    groups,
    shortened: source.shortened === true,
    singleQuiz: source.singleQuiz === true,
    status: status === "ready" || status === "failed" ? status : "generating",
    ...(Array.isArray(source.symbols) ? { symbols: stringList(source.symbols) } : {}),
    ...(points ? { points } : {}),
  };
}

function safeParse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

// MARK: - Les notes d'un thème

/** Le genre d'un encadré des notes. Voir `supabase/functions/generate-lesson/schema.ts`. */
export type CalloutKind = "why" | "mistake" | "tip" | "remember";
export const CALLOUT_KINDS: readonly CalloutKind[] = ["why", "mistake", "tip", "remember"];

export interface DateItem {
  date: string;
  text: string;
}

/**
 * Un bloc des notes. Le balisage en ligne ne garde que `**mot-clé**` (gras violet) et
 * `$latex$`. Les formes `steps`, `table` et `quote` arrivent avec un `text` de repli pour
 * les versions qui ne les connaissent pas : on l'ignore, sauf si le bloc est incomplet.
 */
export type NoteBlock =
  | { type: "subtitle"; text: string }
  | { type: "paragraph"; text: string }
  | { type: "list"; items: string[] }
  | { type: "definition"; term: string; text: string }
  | { type: "dates"; items: DateItem[] }
  | { type: "formula"; latex: string; caption: string | null }
  | { type: "example"; text: string }
  | { type: "steps"; items: string[] }
  | { type: "table"; columns: string[]; rows: string[][] }
  | { type: "quote"; text: string; author: string | null }
  | { type: "callout"; kind: CalloutKind; title: string | null; text: string };

export interface ThemeNotes {
  oneLiner: string;
  blocks: NoteBlock[];
  takeaways: string[];
}

function fallbackParagraph(source: Record<string, unknown>): NoteBlock | null {
  const text = trimmed(source.text);
  return text ? { type: "paragraph", text: source.text as string } : null;
}

/** Un bloc, lu sans jamais échouer : `null` quand il est illisible. */
export function readNoteBlock(raw: unknown): NoteBlock | null {
  if (!isRecord(raw) || typeof raw.type !== "string") return null;
  const text = typeof raw.text === "string" ? raw.text : null;
  switch (raw.type) {
    case "subtitle":
      return text === null ? null : { type: "subtitle", text };
    case "paragraph":
      return text === null ? null : { type: "paragraph", text };
    case "list":
      return Array.isArray(raw.items) ? { type: "list", items: stringList(raw.items) } : null;
    case "definition":
      return typeof raw.term === "string" && text !== null
        ? { type: "definition", term: raw.term, text }
        : null;
    case "dates": {
      if (!Array.isArray(raw.items)) return null;
      const items: DateItem[] = [];
      for (const item of raw.items) {
        if (isRecord(item) && typeof item.date === "string" && typeof item.text === "string") {
          items.push({ date: item.date, text: item.text });
        }
      }
      return { type: "dates", items };
    }
    case "formula": {
      if (typeof raw.latex !== "string") return null;
      const normalized = normalizeFormula(raw.latex, typeof raw.caption === "string" ? raw.caption : null);
      return { type: "formula", latex: normalized.latex, caption: normalized.caption };
    }
    case "example":
      return text === null ? null : { type: "example", text };
    case "steps": {
      const items = stringList(raw.items);
      return items.length > 0 ? { type: "steps", items } : fallbackParagraph(raw);
    }
    case "table": {
      const columns = stringList(raw.columns);
      const rows = Array.isArray(raw.rows) ? raw.rows.map(stringList) : [];
      return columns.length > 0 && rows.length > 0
        ? { type: "table", columns, rows }
        : fallbackParagraph(raw);
    }
    case "quote": {
      if (text === null) return null;
      const author = trimmed(raw.author);
      return { type: "quote", text, author: author || null };
    }
    case "callout": {
      if (text === null) return null;
      const kind = (CALLOUT_KINDS as readonly string[]).includes(raw.kind as string)
        ? (raw.kind as CalloutKind)
        : "tip";
      const title = trimmed(raw.title);
      return { type: "callout", kind, title: title || null, text };
    }
    default:
      // Un bloc d'une version plus récente du serveur se lit comme un paragraphe.
      return fallbackParagraph(raw);
  }
}

/**
 * **La flèche étiquetée d'amsmath**, que le moteur ne compose pas, redevient une flèche ; son
 * étiquette passe en légende. Avec ou sans l'antislash qu'une ancienne leçon a pu perdre.
 * Jumeau de `SheetText.normalizedFormula` côté Swift.
 */
export function normalizeFormula(latex: string, caption: string | null): { latex: string; caption: string | null } {
  const labels: string[] = [];
  const cleaned = latex.replace(/\\?xrightarrow\s*\{([^}]*)\}/g, (_all, label: string) => {
    const trimmedLabel = label.trim();
    if (trimmedLabel) labels.push(trimmedLabel);
    return "\\rightarrow";
  });
  if (labels.length === 0) return { latex, caption };
  const existing = caption?.trim() ?? "";
  const joined = labels.join(" · ");
  return { latex: cleaned, caption: existing ? `${existing} · ${joined}` : joined };
}

const STEP_MARKER = /(?:^|(?<=[\s:;]))(\d{1,2})[.)]\s+/g;

/**
 * **Des étapes écrites d'une traite dans un paragraphe.** Trois numéros au moins, qui se
 * suivent depuis 1 : ce qui précède le premier reste une introduction, le reste devient des
 * étapes. Une date (« en 1945. ») ou un « 2 » isolé ne font pas une méthode.
 */
export function inlineSteps(text: string): { lead: string; items: string[] } | null {
  const sequence: { index: number; length: number }[] = [];
  for (const match of text.matchAll(STEP_MARKER)) {
    if (Number(match[1]) === sequence.length + 1) {
      sequence.push({ index: match.index, length: match[0].length });
    }
  }
  if (sequence.length < 3) return null;
  const items = sequence.map((marker, position) => {
    const start = marker.index + marker.length;
    const end = position + 1 < sequence.length ? sequence[position + 1]!.index : text.length;
    let item = text.slice(start, end).trim();
    if (item.endsWith(";") || item.endsWith(",")) item = item.slice(0, -1).trim();
    return item;
  });
  if (!items.every((item) => item.length >= 2)) return null;
  return { lead: text.slice(0, sequence[0]!.index).trim(), items };
}

function repaired(block: NoteBlock): NoteBlock[] {
  if (block.type !== "paragraph") return [block];
  const split = inlineSteps(block.text);
  if (!split) return [block];
  const lead: NoteBlock[] = split.lead ? [{ type: "paragraph", text: split.lead }] : [];
  return [...lead, { type: "steps", items: split.items }];
}

/** Vrai pour un bloc qui n'a rien à montrer : il laisserait un trou blanc. */
export function blockIsEmpty(block: NoteBlock): boolean {
  switch (block.type) {
    case "subtitle":
    case "paragraph":
    case "callout":
      return block.text.trim().length === 0;
    default:
      return false;
  }
}

/** Vrai pour les blocs qui se dessinent dans un encadré : deux encadrés ne se suivent pas. */
export function blockIsBoxed(block: NoteBlock): boolean {
  switch (block.type) {
    case "definition":
    case "formula":
    case "example":
    case "steps":
    case "table":
    case "quote":
    case "callout":
      return true;
    default:
      return false;
  }
}

function words(text: string): number {
  return text.split(/\s+/).filter(Boolean).length;
}

/** Le nombre de mots que le bloc donne à lire. */
export function blockWordCount(block: NoteBlock): number {
  switch (block.type) {
    case "subtitle":
    case "paragraph":
    case "example":
      return words(block.text);
    case "list":
    case "steps":
      return block.items.reduce((sum, item) => sum + words(item), 0);
    case "definition":
      return words(block.term) + words(block.text);
    case "dates":
      return block.items.reduce((sum, item) => sum + words(item.date) + words(item.text), 0);
    case "formula":
      return words(block.caption ?? "");
    case "table":
      return [...block.columns, ...block.rows.flat()].reduce((sum, cell) => sum + words(cell), 0);
    case "quote":
      return words(block.text) + words(block.author ?? "");
    case "callout":
      return words(block.title ?? "") + words(block.text);
  }
}

/** Les notes d'un thème, lues depuis `chapters.notes`. `null` sans notes. */
export function readThemeNotes(raw: unknown): ThemeNotes | null {
  const source = typeof raw === "string" ? safeParse(raw) : raw;
  if (!isRecord(source) || typeof source.oneLiner !== "string" || !Array.isArray(source.blocks)) return null;
  const blocks = source.blocks
    .map(readNoteBlock)
    .filter((block): block is NoteBlock => block !== null)
    .flatMap(repaired)
    .filter((block) => !blockIsEmpty(block));
  return { oneLiner: source.oneLiner, blocks, takeaways: stringList(source.takeaways) };
}

/** Le texte à plat, pour le contexte de Mika et la relecture. */
export function notesPlainText(notes: ThemeNotes): string {
  const lines: string[] = [notes.oneLiner];
  for (const block of notes.blocks) {
    switch (block.type) {
      case "subtitle":
      case "paragraph":
      case "example":
        lines.push(block.text);
        break;
      case "list":
        lines.push(...block.items.map((item) => `- ${item}`));
        break;
      case "definition":
        lines.push(`${block.term} : ${block.text}`);
        break;
      case "dates":
        lines.push(...block.items.map((item) => `${item.date} : ${item.text}`));
        break;
      case "formula":
        lines.push([block.latex, block.caption].filter(Boolean).join(" — "));
        break;
      case "steps":
        lines.push(...block.items.map((item, index) => `${index + 1}. ${item}`));
        break;
      case "table":
        lines.push(block.columns.join(" | "));
        lines.push(...block.rows.map((row) => row.join(" | ")));
        break;
      case "quote":
        lines.push([`« ${block.text} »`, block.author].filter(Boolean).join(" — "));
        break;
      case "callout":
        lines.push([block.title, block.text].filter(Boolean).join(" : "));
        break;
    }
  }
  lines.push(...notes.takeaways);
  return lines.join("\n").replaceAll("**", "");
}

// MARK: - Les questions

export type QuizKind = "choice" | "truefalse" | "gap" | "order" | "match";
export const QUIZ_KINDS: readonly QuizKind[] = ["choice", "truefalse", "gap", "order", "match"];

/** Le marqueur du trou d'une phrase à compléter, le même que sur le serveur et l'app. */
export const CLOZE_GAP = "____";

/**
 * **Une question** : la question de fin d'un thème, une de réserve qui fait les quiz, ou une
 * question d'entraînement. Cinq formes, une difficulté de 1 (reconnaître) à 3 (appliquer).
 */
export interface QuizQuestion {
  /** Stable : `<id du thème>:<rang>`. C'est lui qu'on retient pour « ratée ». */
  id: string;
  kind: QuizKind;
  prompt: string;
  choices: string[];
  answer: number;
  why: string;
  /** Pour `match` : les réponses de droite, dans le même ordre que `choices`. */
  matches: string[];
  difficulty: number;
}

function clampDifficulty(value: unknown): number {
  const n = typeof value === "number" ? Math.round(value) : 2;
  return Math.min(3, Math.max(1, n));
}

/** Une question lue depuis le JSON ; d'avant les formes, c'est un QCM. `null` sans énoncé. */
export function readQuizQuestion(raw: unknown, fallbackId?: string): QuizQuestion | null {
  if (!isRecord(raw)) return null;
  const id = typeof raw.id === "string" ? raw.id : fallbackId;
  if (!id || typeof raw.prompt !== "string") return null;
  const kind = (QUIZ_KINDS as readonly string[]).includes(raw.kind as string) ? (raw.kind as QuizKind) : "choice";
  return {
    id,
    kind,
    prompt: raw.prompt,
    choices: stringList(raw.choices),
    answer: typeof raw.answer === "number" ? raw.answer : 0,
    why: typeof raw.why === "string" ? raw.why : "",
    matches: stringList(raw.matches),
    difficulty: clampDifficulty(raw.difficulty),
  };
}

export function questionIsValid(question: QuizQuestion): boolean {
  if (question.prompt.trim().length === 0) return false;
  switch (question.kind) {
    case "choice":
    case "truefalse":
    case "gap":
      return question.choices.length >= 2 && question.answer >= 0 && question.answer < question.choices.length;
    case "order":
      return question.choices.length >= 3;
    case "match":
      return question.choices.length >= 2 && question.matches.length === question.choices.length;
  }
}

/** La bonne réponse, en clair : pour le corrigé et pour une carte faite d'une question ratée. */
export function answerText(question: QuizQuestion): string {
  switch (question.kind) {
    case "choice":
    case "truefalse":
    case "gap":
      return question.choices[question.answer] ?? "";
    case "order":
      return question.choices.join(" → ");
    case "match":
      return question.choices.map((left, index) => `${left} : ${question.matches[index] ?? ""}`).join(" · ");
  }
}

/** Les questions d'un thème : la première est celle de fin, les autres font la réserve. */
export interface ThemeQuiz {
  questions: QuizQuestion[];
}

export function readThemeQuiz(raw: unknown): ThemeQuiz | null {
  const source = typeof raw === "string" ? safeParse(raw) : raw;
  if (!isRecord(source) || !Array.isArray(source.questions)) return null;
  const questions = source.questions
    .map((entry) => readQuizQuestion(entry))
    .filter((question): question is QuizQuestion => question !== null);
  return { questions };
}

export function finalQuestion(quiz: ThemeQuiz): QuizQuestion | null {
  return quiz.questions[0] ?? null;
}

export function reserveQuestions(quiz: ThemeQuiz): QuizQuestion[] {
  return quiz.questions.slice(1);
}

// MARK: - La progression

export type LessonActivity = "notes" | "quiz" | "flashcards";
export const LESSON_ACTIVITIES: readonly LessonActivity[] = ["notes", "quiz", "flashcards"];

/** L'état de génération d'un thème. */
export type ThemeStatus = "pending" | "ready" | "failed";

export function readThemeStatus(raw: unknown): ThemeStatus {
  return raw === "pending" || raw === "failed" ? raw : "ready";
}

/** **Où en est l'élève dans sa leçon.** Encodé en JSON dans `courses.progress`. */
export interface LessonProgress {
  /** Les étapes cochées, par identifiant (`PathCircle.id`). */
  done: string[];
  /** Où on en est **dans** l'étape en cours, entre 0 et 1 : l'anneau autour d'elle. */
  inCircle: number;
  /** Les scores des quiz : identifiant de l'étape → [bonnes réponses, questions]. */
  quizScores: Record<string, [number, number]>;
  /** Les questions ratées (`QuizQuestion.id`), les plus récentes à la fin. */
  missed: string[];
  /** Le temps passé, en secondes, par activité. */
  seconds: Partial<Record<LessonActivity, number>>;
  /** Le jour où la leçon est devenue « apprise », en ISO 8601. */
  finishedAt: string | null;
}

export const MISSED_CAP = 200;

export function emptyProgress(): LessonProgress {
  return { done: [], inCircle: 0, quizScores: {}, missed: [], seconds: {}, finishedAt: null };
}

/** La progression, lue depuis `courses.progress` ; vide quand il n'y en a pas. */
export function readLessonProgress(raw: unknown): LessonProgress {
  const source = typeof raw === "string" ? safeParse(raw) : raw;
  if (!isRecord(source)) return emptyProgress();
  const quizScores: Record<string, [number, number]> = {};
  if (isRecord(source.quizScores)) {
    for (const [key, value] of Object.entries(source.quizScores)) {
      if (Array.isArray(value) && value.length === 2 && value.every((item) => typeof item === "number")) {
        quizScores[key] = [value[0] as number, value[1] as number];
      }
    }
  }
  const seconds: Partial<Record<LessonActivity, number>> = {};
  if (isRecord(source.seconds)) {
    for (const activity of LESSON_ACTIVITIES) {
      const value = source.seconds[activity];
      if (typeof value === "number" && Number.isFinite(value)) seconds[activity] = value;
    }
  }
  const finishedAt = typeof source.finishedAt === "string" && !Number.isNaN(Date.parse(source.finishedAt))
    ? source.finishedAt
    : null;
  const inCircle = typeof source.inCircle === "number" ? Math.min(1, Math.max(0, source.inCircle)) : 0;
  return {
    done: [...new Set(stringList(source.done))],
    inCircle,
    quizScores,
    missed: stringList(source.missed),
    seconds,
    finishedAt,
  };
}

export function totalSeconds(progress: LessonProgress): number {
  return Object.values(progress.seconds).reduce((sum, value) => sum + (value ?? 0), 0);
}

/** Le score moyen des quiz, en pour cent ; `null` sans quiz fait. */
export function averageQuizPercent(progress: LessonProgress): number | null {
  const scores = Object.values(progress.quizScores).filter(([, total]) => total > 0);
  if (scores.length === 0) return null;
  const right = scores.reduce((sum, [value]) => sum + value, 0);
  const total = scores.reduce((sum, [, value]) => sum + value, 0);
  return Math.round((right / total) * 100);
}

/** Un temps négatif ou absurde (plus de six heures d'un coup) ne compte pas. */
export function addTime(progress: LessonProgress, seconds: number, activity: LessonActivity): LessonProgress {
  if (!(seconds > 0) || seconds >= 6 * 3600) return progress;
  return { ...progress, seconds: { ...progress.seconds, [activity]: (progress.seconds[activity] ?? 0) + seconds } };
}

export function noteMissed(progress: LessonProgress, id: string): LessonProgress {
  const missed = [...progress.missed.filter((item) => item !== id), id];
  return { ...progress, missed: missed.length > MISSED_CAP ? missed.slice(missed.length - MISSED_CAP) : missed };
}

export function noteRight(progress: LessonProgress, id: string): LessonProgress {
  return { ...progress, missed: progress.missed.filter((item) => item !== id) };
}

export function markDone(progress: LessonProgress, circleId: string): LessonProgress {
  return { ...progress, done: progress.done.includes(circleId) ? progress.done : [...progress.done, circleId], inCircle: 0 };
}

export function recordQuiz(progress: LessonProgress, circleId: string, right: number, total: number): LessonProgress {
  return { ...progress, quizScores: { ...progress.quizScores, [circleId]: [right, total] } };
}

/** **Recommencer la leçon** : le chemin repart de l'Intro, le temps passé reste compté. */
export function resetProgress(progress: LessonProgress): LessonProgress {
  return { ...progress, done: [], inCircle: 0, quizScores: {}, missed: [], finishedAt: null };
}

export function isFinished(progress: LessonProgress): boolean {
  return progress.finishedAt !== null;
}
