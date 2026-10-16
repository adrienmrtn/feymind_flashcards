/**
 * **Ce que le modèle rend, remis aux règles de la leçon.**
 *
 * Le prompt dit les règles ; ce module les **tient**. Un modèle qui écrit sept puces, deux
 * encadrés de suite ou un emoji dans une définition rend quand même des notes lisibles, parce
 * que tout ce qui sort passe ici avant d'arriver à l'app. Voir `docs/refonte-parcours.md` § 6.
 *
 * Tout est pur : aucune entrée-sortie, et chaque règle a son test.
 */
import { DEFAULT_ICON, normalizeIcon } from "../_shared/icons.ts";

// MARK: - Les nombres de la leçon

export const LIMITS = {
  minThemes: 4,
  maxThemes: 12,
  themeTitleWords: 6,
  lessonTitleWords: 10,
  sentenceWords: 25,
  paragraphWords: 60,
  listItemsMin: 3,
  listItemsMax: 5,
  listItemWords: 16,
  blocksMin: 2,
  blocksMax: 5,
  takeawaysPerTheme: 3,
  lessonTakeaways: 5,
  introLines: 3,
  choices: 4,
  questionsPerTheme: 4,
  flashcardsPerTheme: 3,
  datesMax: 6,
} as const;

/** Moins que ça, une leçon tient en un seul quiz : très courte, quatre thèmes. */
export const SHORT_SOURCE = 1_500;
/** Au-delà, les supports sont coupés et la leçon le dit. */
export const MAX_SOURCE = 60_000;

// MARK: - Texte

/** Les emojis et pictogrammes : jamais dans le texte d'une leçon. */
const EMOJI = /[\p{Extended_Pictographic}\u{1F1E6}-\u{1F1FF}\u{FE0F}\u{200D}]/gu;

export function cleanText(value: unknown, maxLength = 600): string {
  if (typeof value !== "string") return "";
  return value
    .replace(EMOJI, "")
    .replace(/\s+[—–―]\s+/g, ", ")
    .replace(/[—–―]/g, "-")
    .replace(/[ \t]+/g, " ")
    .replace(/\s*\n\s*/g, " ")
    .trim()
    .slice(0, maxLength);
}

export function words(text: string): string[] {
  return text.split(/\s+/).filter(Boolean);
}

/** Coupe à `max` mots. Un titre trop long perd sa fin, pas son début. */
export function clampWords(text: string, max: number): string {
  const list = words(text);
  if (list.length <= max) return text;
  return list.slice(0, max).join(" ").replace(/[,;:]$/, "");
}

/** Les phrases d'un texte, ponctuation comprise. */
export function sentences(text: string): string[] {
  return text.match(/[^.!?…]+[.!?…]+["»”)]*\s*|[^.!?…]+$/g)?.map((s) => s.trim()).filter(Boolean) ?? [];
}

/**
 * **Un paragraphe aux règles** : 60 mots au plus, des phrases de 25 mots au plus. Une phrase
 * trop longue est coupée à sa première virgule passé la moitié, sinon à 25 mots ; les phrases
 * qui débordent du paragraphe partent.
 */
export function clampParagraph(text: string): string {
  const out: string[] = [];
  let count = 0;
  for (let sentence of sentences(text)) {
    if (words(sentence).length > LIMITS.sentenceWords) {
      sentence = clampWords(sentence, LIMITS.sentenceWords).replace(/[,;:]?$/, ".");
    }
    const n = words(sentence).length;
    if (count + n > LIMITS.paragraphWords && out.length > 0) break;
    out.push(sentence);
    count += n;
  }
  return out.join(" ");
}

/** Le balisage en ligne : seuls `**mot-clé**` et `$latex$` survivent. */
export function cleanInline(text: string): string {
  let out = text
    .replace(/==(?:[^=|]*\|)?([^=]+)==/g, "$1")
    .replace(/\^\^[^|^]*\|([^^]+)\^\^/g, "$1")
    .replace(/~~([^~]+)~~/g, "$1")
    .replace(/(?<!\*)\*(?!\*)([^*\n]+?)(?<!\*)\*(?!\*)/g, "$1")
    // Un gras vide ; « ** ** » ne se retire pas : c'est souvent la jonction de deux mots-clés.
    .replace(/\*\*\*\*/g, "");
  // Un `**` orphelin ferait passer tout le reste du texte en mot-clé : le dernier part.
  const marks = out.match(/\*\*/g)?.length ?? 0;
  if (marks % 2 === 1) {
    const last = out.lastIndexOf("**");
    out = out.slice(0, last) + out.slice(last + 2);
  }
  return out;
}

// MARK: - Notes

export type NoteBlock =
  | { type: "subtitle"; text: string }
  | { type: "paragraph"; text: string }
  | { type: "list"; items: string[] }
  | { type: "definition"; term: string; text: string }
  | { type: "dates"; items: { date: string; text: string }[] }
  | { type: "formula"; latex: string; caption?: string }
  | { type: "example"; text: string };

export interface ThemeNotes {
  oneLiner: string;
  blocks: NoteBlock[];
  takeaways: string[];
}

const BOXED = new Set(["definition", "formula", "example"]);

function readBlock(raw: unknown): NoteBlock | null {
  if (!raw || typeof raw !== "object") return null;
  const block = raw as Record<string, unknown>;
  const type = typeof block.type === "string" ? block.type : "";
  switch (type) {
    case "subtitle": {
      const text = clampWords(cleanInline(cleanText(block.text, 120)).replace(/\*\*/g, ""), 8);
      return text ? { type, text } : null;
    }
    case "paragraph": {
      const text = clampParagraph(cleanInline(cleanText(block.text, 900)));
      return text ? { type, text } : null;
    }
    case "list": {
      const items = (Array.isArray(block.items) ? block.items : [])
        .map((item) => clampWords(cleanInline(cleanText(item, 240)), LIMITS.listItemWords))
        .filter(Boolean)
        .slice(0, LIMITS.listItemsMax);
      if (items.length === 0) return null;
      // Une liste d'un ou deux points n'en est pas une : elle se lit en phrase.
      if (items.length < LIMITS.listItemsMin) {
        return { type: "paragraph", text: clampParagraph(items.join(". ").replace(/\.\./g, ".")) };
      }
      return { type, items };
    }
    case "definition": {
      const term = cleanText(block.term, 80).replace(/\*\*/g, "");
      const text = clampParagraph(cleanInline(cleanText(block.text, 600)));
      return term && text ? { type, term, text } : null;
    }
    case "dates": {
      const items = (Array.isArray(block.items) ? block.items : [])
        .map((item) => {
          const entry = (item ?? {}) as Record<string, unknown>;
          return {
            date: cleanText(entry.date, 40),
            text: clampWords(cleanInline(cleanText(entry.text, 200)), 14),
          };
        })
        .filter((item) => item.date && item.text)
        .slice(0, LIMITS.datesMax);
      return items.length >= 2 ? { type, items } : null;
    }
    case "formula": {
      const latex = typeof block.latex === "string" ? block.latex.trim().slice(0, 240) : "";
      const caption = clampWords(cleanText(block.caption, 160), 16);
      if (!latex) return null;
      return caption ? { type, latex, caption } : { type, latex };
    }
    case "example": {
      const text = clampParagraph(cleanInline(cleanText(block.text, 600)));
      return text ? { type, text } : null;
    }
    default:
      return null;
  }
}

/**
 * **Jamais deux encadrés de suite.** Le second est repoussé après le bloc courant qui suit ;
 * s'il n'y en a pas, un exemple redevient un paragraphe, et tout autre encadré part.
 */
export function separateBoxes(blocks: NoteBlock[]): NoteBlock[] {
  const out = [...blocks];
  for (let i = 1; i < out.length; i += 1) {
    if (!BOXED.has(out[i]!.type) || !BOXED.has(out[i - 1]!.type)) continue;
    const next = out.findIndex((block, index) => index > i && !BOXED.has(block.type));
    if (next !== -1) {
      const [plain] = out.splice(next, 1);
      out.splice(i, 0, plain!);
      continue;
    }
    const boxed = out[i]!;
    if (boxed.type === "example") {
      out[i] = { type: "paragraph", text: boxed.text };
    } else {
      out.splice(i, 1);
      i -= 1;
    }
  }
  return out;
}

export function readNotes(raw: unknown): ThemeNotes | null {
  if (!raw || typeof raw !== "object") return null;
  const notes = raw as Record<string, unknown>;
  const oneLiner = clampParagraph(cleanInline(cleanText(notes.oneLiner, 300)));
  let blocks = (Array.isArray(notes.blocks) ? notes.blocks : [])
    .map(readBlock)
    .filter((block): block is NoteBlock => block !== null);
  // Un sous-titre en dernier n'ouvre rien, et deux sous-titres de suite n'en font qu'un.
  blocks = blocks.filter((block, index) =>
    block.type !== "subtitle" ||
    (index < blocks.length - 1 && blocks[index + 1]!.type !== "subtitle")
  );
  blocks = separateBoxes(blocks);
  // Cinq blocs courts au plus, sans compter les sous-titres qui les ouvrent.
  let counted = 0;
  blocks = blocks.filter((block) => {
    if (block.type === "subtitle") return true;
    counted += 1;
    return counted <= LIMITS.blocksMax + 2;
  });
  while (blocks.length > 0 && blocks[blocks.length - 1]!.type === "subtitle") blocks.pop();
  const takeaways = readSentences(notes.takeaways, LIMITS.takeawaysPerTheme, 22);
  const content = blocks.filter((block) => block.type !== "subtitle").length;
  if (!oneLiner || content < 1) return null;
  return { oneLiner, blocks, takeaways };
}

function readSentences(raw: unknown, max: number, maxWords: number): string[] {
  return (Array.isArray(raw) ? raw : [])
    .map((item) => clampWords(cleanInline(cleanText(item, 300)), maxWords))
    .filter(Boolean)
    .slice(0, max);
}

// MARK: - Questions

export interface QuizQuestion {
  prompt: string;
  choices: string[];
  answer: number;
  why: string;
}

/** Un générateur pseudo-aléatoire reproductible : le même thème mélange toujours pareil. */
export function seededRandom(seed: string): () => number {
  let h = 2166136261;
  for (let i = 0; i < seed.length; i += 1) {
    h ^= seed.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return () => {
    h += 0x6d2b79f5;
    let t = h;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * Une question aux règles : quatre propositions distinctes, une seule bonne, une phrase qui
 * explique. Le modèle met presque toujours la bonne réponse en premier ou en deuxième : les
 * propositions sont mélangées ici, de façon reproductible.
 */
export function readQuestion(raw: unknown, seed: string): QuizQuestion | null {
  if (!raw || typeof raw !== "object") return null;
  const question = raw as Record<string, unknown>;
  const prompt = clampWords(cleanInline(cleanText(question.prompt, 400)).replace(/\*\*/g, ""), 30);
  const rawChoices = Array.isArray(question.choices) ? question.choices : [];
  const answer = typeof question.answer === "number" ? Math.round(question.answer) : -1;
  if (!prompt || answer < 0 || answer >= rawChoices.length) return null;

  const right = clampWords(cleanText(rawChoices[answer], 200).replace(/\*\*/g, ""), 14);
  const seen = new Set([right.toLowerCase()]);
  const wrong: string[] = [];
  rawChoices.forEach((choice, index) => {
    if (index === answer) return;
    const text = clampWords(cleanText(choice, 200).replace(/\*\*/g, ""), 14);
    if (text && !seen.has(text.toLowerCase())) {
      seen.add(text.toLowerCase());
      wrong.push(text);
    }
  });
  if (!right || wrong.length < 2) return null;

  const choices = [right, ...wrong.slice(0, LIMITS.choices - 1)];
  const random = seededRandom(seed);
  for (let i = choices.length - 1; i > 0; i -= 1) {
    const j = Math.floor(random() * (i + 1));
    [choices[i], choices[j]] = [choices[j]!, choices[i]!];
  }
  const why = clampParagraph(cleanInline(cleanText(question.why, 400)).replace(/\*\*/g, ""));
  return { prompt, choices, answer: choices.indexOf(right), why };
}

export function readQuestions(raw: unknown, seed: string, max = LIMITS.questionsPerTheme): QuizQuestion[] {
  return (Array.isArray(raw) ? raw : [])
    .map((question, index) => readQuestion(question, `${seed}:${index}`))
    .filter((question): question is QuizQuestion => question !== null)
    .slice(0, max);
}

// MARK: - Flashcards

export interface Flashcard {
  front: string;
  back: string;
}

export function readFlashcards(raw: unknown, max = LIMITS.flashcardsPerTheme): Flashcard[] {
  return (Array.isArray(raw) ? raw : [])
    .map((card) => {
      const entry = (card ?? {}) as Record<string, unknown>;
      return {
        front: clampWords(cleanText(entry.front, 300).replace(/\*\*/g, ""), 20),
        back: clampWords(cleanText(entry.back, 400).replace(/\*\*/g, ""), 30),
      };
    })
    .filter((card) => card.front && card.back)
    .slice(0, max);
}

// MARK: - Le plan

/** Le découpage des thèmes en paliers : le même que `PathLayout.groups` dans l'app. */
export function groupThemes(count: number, singleQuiz = false): number[][] {
  if (count <= 0) return [];
  if (singleQuiz) return [Array.from({ length: count }, (_, i) => i)];
  const size = count > 8 ? 3 : 2;
  const sizes = Array<number>(Math.floor(count / size)).fill(size);
  const rest = count % size;
  if (size === 2 && rest === 1) {
    if (sizes.length === 0) sizes.push(1);
    else sizes[sizes.length - 1]! += 1;
  } else if (size === 3 && rest === 1) {
    if (sizes.length === 0) sizes.push(1);
    else sizes.splice(sizes.length - 1, 1, 2, 2);
  } else if (size === 3 && rest === 2) {
    sizes.push(2);
  }
  const groups: number[][] = [];
  let start = 0;
  for (const n of sizes) {
    groups.push(Array.from({ length: n }, (_, i) => start + i));
    start += n;
  }
  return groups;
}

/** Le temps estimé : quatre minutes par thème, deux par quiz, cinq pour le reste. */
export function estimateMinutes(themes: number, quizzes: number): number {
  return Math.max(10, Math.round((themes * 4 + quizzes * 2 + 5) / 5) * 5);
}

/**
 * Les noms des paliers, sur le découpage de l'app. Le modèle groupe parfois autrement : chaque
 * palier prend alors le nom du groupe du modèle qui contient son premier thème.
 */
export function nameGroups(groups: number[][], raw: unknown): string[] {
  const proposed = (Array.isArray(raw) ? raw : [])
    .map((group) => {
      const entry = (group ?? {}) as Record<string, unknown>;
      const themes = Array.isArray(entry.themes)
        ? entry.themes.filter((n): n is number => typeof n === "number")
        : [];
      return { name: clampWords(cleanText(entry.name, 80).replace(/\*\*/g, ""), 5), themes };
    })
    .filter((group) => group.name);
  return groups.map((group, index) => {
    const exact = proposed[index];
    if (exact && exact.themes.length === group.length && exact.themes[0] === group[0]) {
      return exact.name;
    }
    const containing = proposed.find((candidate) => candidate.themes.includes(group[0]!));
    return containing?.name ?? exact?.name ?? "";
  });
}

export interface LessonPlan {
  title: string;
  subject: string;
  icon: string;
  themes: { title: string; icon: string }[];
  groups: { name: string; themes: number[] }[];
  intro: { lines: string[]; minutes: number };
  takeaways: string[];
  shortened: boolean;
  singleQuiz: boolean;
}

/**
 * **Le plan aux règles** : de 4 à 12 thèmes (4 exactement, et un seul quiz, pour une leçon très
 * courte), des titres de six mots au plus, des icônes de la base, des paliers sur le découpage
 * de l'app, une durée calculée et non devinée.
 */
export function readPlan(
  raw: unknown,
  options: { shortSource: boolean; shortened: boolean; fallbackTitle: string },
): LessonPlan | null {
  if (!raw || typeof raw !== "object") return null;
  const plan = raw as Record<string, unknown>;
  const seen = new Set<string>();
  let themes = (Array.isArray(plan.themes) ? plan.themes : [])
    .map((theme) => {
      const entry = (theme ?? {}) as Record<string, unknown>;
      return {
        title: clampWords(cleanText(entry.title, 120).replace(/\*\*/g, "").replace(/[.:]$/, ""), LIMITS.themeTitleWords),
        icon: normalizeIcon(entry.icon),
      };
    })
    .filter((theme) => {
      const key = theme.title.toLowerCase();
      if (!theme.title || seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  const singleQuiz = options.shortSource;
  themes = themes.slice(0, singleQuiz ? LIMITS.minThemes : LIMITS.maxThemes);
  if (themes.length < (singleQuiz ? 2 : LIMITS.minThemes - 1)) return null;

  const groups = groupThemes(themes.length, singleQuiz);
  const names = nameGroups(groups, plan.groups);
  const intro = (plan.intro ?? {}) as Record<string, unknown>;
  const lines = readSentences(intro.lines, LIMITS.introLines, 16);
  const title = clampWords(
    cleanText(plan.title, 160).replace(/\*\*/g, "") || options.fallbackTitle,
    LIMITS.lessonTitleWords,
  );
  return {
    title: title || options.fallbackTitle,
    subject: clampWords(cleanText(plan.subject, 60).replace(/\*\*/g, ""), 4),
    icon: normalizeIcon(plan.icon) || DEFAULT_ICON,
    themes,
    groups: groups.map((themes, index) => ({ name: names[index] ?? "", themes })),
    intro: { lines, minutes: estimateMinutes(themes.length, groups.length) },
    takeaways: readSentences(plan.takeaways, LIMITS.lessonTakeaways, 22),
    shortened: options.shortened,
    singleQuiz,
  };
}
