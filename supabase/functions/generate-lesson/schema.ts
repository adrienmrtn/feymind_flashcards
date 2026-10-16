/**
 * **Ce que le modèle rend, remis aux règles de la leçon.**
 *
 * Le prompt dit les règles ; ce module les **tient**. Un modèle qui écrit sept puces, deux
 * encadrés de suite ou un emoji dans une définition rend quand même des notes lisibles, parce
 * que tout ce qui sort passe ici avant d'arriver à l'app. Voir `docs/refonte-parcours.md` § 6.
 *
 * Tout est pur : aucune entrée-sortie, et chaque règle a son test.
 */
import { DEFAULT_ICON, LESSON_ICONS, normalizeIcon } from "../_shared/icons.ts";
import { uniqueSymbols } from "../_shared/symbols.ts";
import { normalizeFormula, protectedSpans } from "../_shared/sheet.ts";

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
  /** Le plafond par thème : le nombre demandé dépend de la marche (`volumeOf`). */
  questionsPerTheme: 8,
  /** Moins que ça, le thème est à réécrire : la question de fin et deux pour les quiz. */
  minQuestions: 3,
  flashcardsPerTheme: 8,
  /** Les notions qu'un thème doit couvrir, données par le plan. */
  pointsPerTheme: 4,
  /** Un lot de « nouvelles questions ». */
  practiceMax: 12,
  /** Un examen blanc. */
  examMax: 30,
  orderItemsMin: 3,
  orderItemsMax: 6,
  matchPairsMin: 3,
  matchPairsMax: 5,
  datesMax: 6,
  stepsMin: 2,
  stepsMax: 6,
  stepWords: 22,
  tableColumnsMin: 2,
  tableColumnsMax: 4,
  tableRowsMin: 2,
  tableRowsMax: 6,
  tableCellWords: 12,
  quoteWords: 40,
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

/** Vrai quand `index` tombe dans une formule `$…$` ou un mot-clé `**…**`. */
function insideSpans(spans: [number, number][], index: number): boolean {
  return spans.some(([from, to]) => index >= from && index < to);
}

/**
 * Les « mots » d'une coupe : une formule `$…$` ou un mot-clé `**…**` compte pour un seul,
 * même quand il contient des espaces. Couper au milieu laissait un `$` ou des `**` orphelins,
 * et l'app rendait le reste du texte en formule ou en gras.
 */
export function tokens(text: string): string[] {
  const spans = protectedSpans(text);
  const out: string[] = [];
  let current = "";
  for (let index = 0; index < text.length; index += 1) {
    const char = text[index]!;
    if (/\s/.test(char) && !insideSpans(spans, index)) {
      if (current) out.push(current);
      current = "";
    } else {
      current += char;
    }
  }
  if (current) out.push(current);
  return out;
}

/**
 * Coupe à `max` mots. Un titre trop long perd sa fin, pas son début. Une formule ou un
 * mot-clé ne se coupe jamais en deux : il reste entier ou part entier.
 */
export function clampWords(text: string, max: number): string {
  const list = tokens(text);
  if (list.length <= max) return text;
  return list.slice(0, max).join(" ").replace(/[,;:]$/, "");
}

/**
 * Les phrases d'un texte, ponctuation comprise. Une phrase finit sur « . », « ! », « ? » ou
 * « … » SUIVI D'UN BLANC, et jamais dans une formule : « 3.14 », « $g = 9.81$ » et « e.g. »
 * restent entiers. Couper sur chaque point rendait « 3. 14 » une fois les phrases recollées.
 */
export function sentences(text: string): string[] {
  const spans = protectedSpans(text);
  const out: string[] = [];
  let start = 0;
  for (const match of text.matchAll(/[.!?…]+["»”)]*(?=\s)/g)) {
    if (insideSpans(spans, match.index!)) continue;
    const end = match.index! + match[0].length;
    const sentence = text.slice(start, end).trim();
    if (sentence) out.push(sentence);
    start = end;
  }
  const rest = text.slice(start).trim();
  if (rest) out.push(rest);
  return out;
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
  // Même chose pour un `$` orphelin : tout ce qui le suit passerait en formule.
  const dollars = out.match(/\$/g)?.length ?? 0;
  if (dollars % 2 === 1) {
    const last = out.lastIndexOf("$");
    out = out.slice(0, last) + out.slice(last + 1);
  }
  return out.replace(/[ \t]{2,}/g, " ").trim();
}

/** Un texte court aux règles : nettoyé, coupé à `maxWords` (formules et mots-clés entiers), puis remis au propre. */
function inline(value: unknown, maxLength: number, maxWords: number): string {
  return cleanInline(clampWords(cleanText(value, maxLength), maxWords));
}

/** Un paragraphe aux règles : coupé aux phrases d'abord, le balisage remis au propre ensuite. */
function prose(value: unknown, maxLength: number): string {
  return cleanInline(clampParagraph(cleanText(value, maxLength)));
}

// MARK: - Notes

/**
 * Les blocs d'un thème. `steps`, `table` et `quote` sont arrivés après les premières versions
 * de l'app : une app qui ne les connaît pas lit un type inconnu comme un paragraphe, sur son
 * champ `text`. Les étapes et le tableau portent donc aussi un `text` lisible (« 1. … 2. … »,
 * « a — b ; c — d ») ; la citation a déjà le sien.
 */
export type NoteBlock =
  | { type: "subtitle"; text: string }
  | { type: "paragraph"; text: string }
  | { type: "list"; items: string[] }
  | { type: "definition"; term: string; text: string }
  | { type: "dates"; items: { date: string; text: string }[] }
  | { type: "formula"; latex: string; caption?: string }
  | { type: "example"; text: string }
  | { type: "steps"; items: string[]; text: string }
  | { type: "table"; columns: string[]; rows: string[][]; text: string }
  | { type: "quote"; text: string; author?: string };

export interface ThemeNotes {
  oneLiner: string;
  blocks: NoteBlock[];
  takeaways: string[];
}

/** Les blocs encadrés : jamais deux de suite (`separateBoxes`). */
const BOXED = new Set(["definition", "formula", "example", "steps", "table", "quote"]);

/** La puce ou le numéro qu'un modèle écrit parfois en tête d'un élément de liste. */
const ITEM_MARKER = /^\s*(?:[-•*·▪●–]|\d{1,2}[.)])\s+/;

function stripMarker(value: unknown): unknown {
  return typeof value === "string" ? value.replace(ITEM_MARKER, "") : value;
}

function cellValue(value: unknown): unknown {
  return typeof value === "number" && Number.isFinite(value) ? String(value) : value;
}

/** Le texte de repli des étapes, pour une app qui ne sait pas les dessiner. */
export function stepsText(items: string[]): string {
  return items.map((item, index) => `${index + 1}. ${item}`).join(" ");
}

/** Le texte de repli d'un tableau : une ligne par rangée, « a — b ; c — d ». */
export function tableText(rows: string[][]): string {
  return rows.map((row) => row.filter(Boolean).join(" — ")).join(" ; ");
}

/**
 * La chimie écrite en `\ce{…}` (mhchem) : le moteur de l'app ne la compose pas. Elle redevient
 * du LaTeX ordinaire, indices et flèches compris : `\ce{2H2 + O2 -> 2H2O}` → `2H_2 + O_2 \rightarrow 2H_2O`.
 */
export function rewriteChemistry(latex: string): string {
  return latex.replace(/\\ce\s*\{([^{}]*)\}/g, (_match, body: string) =>
    body
      .replace(/<=>|<->/g, " \\rightleftharpoons ")
      .replace(/->/g, " \\rightarrow ")
      .replace(/([A-Za-z)\]])(\d+)/g, (_m, before: string, digits: string) =>
        digits.length === 1 ? `${before}_${digits}` : `${before}_{${digits}}`
      )
      .replace(/\s{2,}/g, " ")
      .trim()
  );
}

/** Une liste aux règles : 3 à 5 puces ; moins, elle se lit en phrase. */
function listBlock(rawItems: unknown[]): NoteBlock[] {
  const items = rawItems
    .map((item) => inline(stripMarker(item), 240, LIMITS.listItemWords))
    .filter(Boolean)
    .slice(0, LIMITS.listItemsMax);
  if (items.length === 0) return [];
  // Une liste d'un ou deux points n'en est pas une : elle se lit en phrase.
  if (items.length < LIMITS.listItemsMin) {
    return [{ type: "paragraph", text: cleanInline(clampParagraph(items.join(". ").replace(/\.\./g, "."))) }];
  }
  return [{ type: "list", items }];
}

function paragraphBlock(raw: unknown): NoteBlock[] {
  const text = prose(raw, 900);
  return text ? [{ type: "paragraph", text }] : [];
}

const BULLET_LINE = /^\s*(?:[-•*·▪●–])\s+\S/;
const NUMBERED_LINE = /^\s*\d{1,2}[.)]\s+\S/;
const HEADING_LINE = /^\s*#{1,6}\s+(.+?)\s*#*\s*$/;
const TABLE_LINE = /^\s*\|.*\|\s*$/;
const TABLE_RULE = /^\s*\|?\s*:?-{2,}:?\s*(?:\|\s*:?-{2,}:?\s*)*\|?\s*$/;

type LineKind = "bullet" | "number" | "heading" | "table" | "text" | "blank";

function lineKind(line: string): LineKind {
  if (!line.trim()) return "blank";
  if (TABLE_LINE.test(line) || TABLE_RULE.test(line) && line.includes("|")) return "table";
  if (HEADING_LINE.test(line)) return "heading";
  if (NUMBERED_LINE.test(line)) return "number";
  if (BULLET_LINE.test(line)) return "bullet";
  return "text";
}

function tableCells(line: string): string[] {
  return line.trim().replace(/^\|/, "").replace(/\|$/, "").split("|").map((cell) => cell.trim());
}

/**
 * **Le Markdown d'un paragraphe, rendu en blocs.** Le modèle écrit parfois des puces, une
 * méthode numérotée, un titre `##` ou un tableau `| a | b |` dans un paragraphe : une fois les
 * retours à la ligne repliés, tout se lisait en un pavé. Les puces deviennent une liste, les
 * numéros des étapes, un titre seul sur sa ligne un sous-titre, un tableau un tableau. `null`
 * quand le texte n'a aucune ligne de ce genre : c'est un paragraphe.
 */
export function markdownBlocks(raw: unknown): NoteBlock[] | null {
  if (typeof raw !== "string") return null;
  const lines = raw.split(/\r?\n/);
  const kinds = lines.map(lineKind);
  if (!kinds.some((kind) => kind !== "text" && kind !== "blank")) return null;

  const out: NoteBlock[] = [];
  let index = 0;
  while (index < lines.length) {
    const kind = kinds[index]!;
    if (kind === "blank") {
      index += 1;
      continue;
    }
    if (kind === "heading") {
      const title = HEADING_LINE.exec(lines[index]!)![1]!;
      out.push(...readBlock({ type: "subtitle", text: title }));
      index += 1;
      continue;
    }
    // Les lignes voisines du même genre vont ensemble ; un paragraphe s'arrête à une ligne vide.
    let end = index;
    while (end < lines.length && kinds[end] === kind) end += 1;
    const group = lines.slice(index, end);
    index = end;
    if (kind === "bullet") out.push(...listBlock(group));
    else if (kind === "number") out.push(...readBlock({ type: "steps", items: group }));
    else if (kind === "table") {
      const rows = group.filter((line) => !TABLE_RULE.test(line)).map(tableCells);
      const [columns, ...body] = rows;
      out.push(...readBlock({ type: "table", columns: columns ?? [], rows: body }));
    } else out.push(...paragraphBlock(group.join(" ")));
  }
  return out;
}

/**
 * **Un bloc du modèle, aux règles.** Rend zéro, un ou plusieurs blocs : un paragraphe écrit en
 * Markdown se déplie (`markdownBlocks`), un tableau trop maigre redevient une liste.
 */
export function readBlock(raw: unknown): NoteBlock[] {
  if (!raw || typeof raw !== "object") return [];
  const block = raw as Record<string, unknown>;
  const type = typeof block.type === "string" ? block.type : "";
  const items = Array.isArray(block.items) ? block.items : [];
  switch (type) {
    case "subtitle": {
      const title = typeof block.text === "string" ? block.text.replace(/^\s*#+\s*/, "") : block.text;
      const text = inline(title, 120, 8).replace(/\*\*/g, "").trim();
      return text ? [{ type, text }] : [];
    }
    case "paragraph":
      return markdownBlocks(block.text) ?? paragraphBlock(block.text);
    case "list":
      return listBlock(items);
    case "steps": {
      const steps = items
        .map((item) => inline(stripMarker(item), 300, LIMITS.stepWords))
        .filter(Boolean)
        .slice(0, LIMITS.stepsMax);
      if (steps.length === 0) return [];
      // Une seule étape n'est pas une méthode : elle se lit en phrase.
      if (steps.length < LIMITS.stepsMin) return paragraphBlock(steps[0]);
      return [{ type, items: steps, text: stepsText(steps) }];
    }
    case "table": {
      const rawColumns = Array.isArray(block.columns) ? block.columns : [];
      const width = rawColumns.length;
      const keep = Math.min(width, LIMITS.tableColumnsMax);
      const columns = rawColumns.slice(0, keep).map((cell) => inline(cellValue(cell), 120, LIMITS.tableCellWords).replace(/\*\*/g, ""));
      // Une rangée qui n'a pas autant de cases que d'en-têtes est mal formée : elle part.
      const rows = (Array.isArray(block.rows) ? block.rows : [])
        .filter((row): row is unknown[] => Array.isArray(row) && row.length === width)
        .map((row) => row.slice(0, keep).map((cell) => inline(cellValue(cell), 160, LIMITS.tableCellWords)))
        .filter((row) => row[0] && row.some((cell, index) => index > 0 && cell))
        .slice(0, LIMITS.tableRowsMax);
      const header = width >= LIMITS.tableColumnsMin && columns.every(Boolean);
      if (!header || rows.length < LIMITS.tableRowsMin) {
        // Trop maigre pour un tableau : ce qui reste se lit en liste.
        return listBlock(rows.map((row) => row.filter(Boolean).join(" : ")));
      }
      return [{ type, columns, rows, text: tableText(rows) }];
    }
    case "quote": {
      const quoted = typeof block.text === "string"
        ? block.text.trim().replace(/^[«"“„'\s]+|[»"”'\s]+$/g, "")
        : block.text;
      const text = inline(quoted, 400, LIMITS.quoteWords);
      const author = inline(block.author ?? block.source, 120, 12).replace(/\*\*/g, "").replace(/^[-,\s]+/, "");
      if (!text) return [];
      return author ? [{ type, text, author }] : [{ type, text }];
    }
    case "definition": {
      const term = cleanText(block.term, 80).replace(/\*\*/g, "");
      const text = prose(block.text, 600);
      return term && text ? [{ type, term, text }] : [];
    }
    case "dates": {
      const dates = items
        .map((item) => {
          const entry = (item ?? {}) as Record<string, unknown>;
          return {
            date: cleanText(cellValue(entry.date), 40),
            text: inline(entry.text, 200, 14),
          };
        })
        .filter((item) => item.date && item.text)
        .slice(0, LIMITS.datesMax);
      return dates.length >= 2 ? [{ type, items: dates }] : [];
    }
    case "formula": {
      // La même remise en forme que les fiches (`sheet.ts`) : sans `$` autour, sans flèche
      // étiquetée d'amsmath, sans boucle de répétition, sous le plafond de longueur.
      const latex = typeof block.latex === "string"
        ? rewriteChemistry(block.latex.trim().replace(/^\$+|\$+$/g, "").trim())
        : "";
      const formula = latex ? normalizeFormula(latex, cleanText(block.caption, 160) || undefined) : null;
      if (!formula) return [];
      const caption = formula.caption ? inline(formula.caption, 200, 20) : "";
      return caption ? [{ type, latex: formula.latex, caption }] : [{ type, latex: formula.latex }];
    }
    case "example": {
      const text = prose(block.text, 600);
      return text ? [{ type, text }] : [];
    }
    default:
      return [];
  }
}

/**
 * Ce que devient un encadré qu'on ne peut pas éloigner de son voisin : un exemple, une
 * citation, des étapes ou un tableau se relisent en texte courant ; une définition ou une
 * formule part.
 */
function unboxed(block: NoteBlock): NoteBlock | null {
  switch (block.type) {
    case "example":
      return { type: "paragraph", text: block.text };
    case "quote":
      return { type: "paragraph", text: block.author ? `${block.text} (${block.author})` : block.text };
    case "steps":
      return block.items.length >= LIMITS.listItemsMin && block.items.length <= LIMITS.listItemsMax
        ? { type: "list", items: block.items }
        : { type: "paragraph", text: block.text };
    case "table":
      return block.rows.length >= LIMITS.listItemsMin && block.rows.length <= LIMITS.listItemsMax
        ? { type: "list", items: block.rows.map((row) => row.filter(Boolean).join(" : ")) }
        : { type: "paragraph", text: block.text };
    default:
      return null;
  }
}

/**
 * **Jamais deux encadrés de suite.** Le second est repoussé après le bloc courant qui suit ;
 * s'il n'y en a pas, il redevient du texte courant quand il le peut (`unboxed`), sinon il part.
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
    const plain = unboxed(out[i]!);
    if (plain) {
      out[i] = plain;
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
  const oneLiner = prose(notes.oneLiner, 300);
  let blocks = (Array.isArray(notes.blocks) ? notes.blocks : []).flatMap(readBlock);
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
    .map((item) => inline(item, 300, maxWords))
    .filter(Boolean)
    .slice(0, max);
}

// MARK: - Questions

/**
 * Les formes de question. `choice` est le QCM ; `truefalse` une affirmation à juger ; `gap`
 * une phrase à trou et ses propositions ; `order` des éléments à remettre dans l'ordre (les
 * `choices` sont dans le bon ordre) ; `match` des paires à associer (`choices` à gauche,
 * `matches` à droite, dans le même ordre).
 */
export type QuestionKind = "choice" | "truefalse" | "gap" | "order" | "match";

export const ALL_KINDS: readonly QuestionKind[] = ["choice", "truefalse", "gap", "order", "match"];

export interface QuizQuestion {
  kind: QuestionKind;
  prompt: string;
  choices: string[];
  answer: number;
  why: string;
  /** De 1 (reconnaître) à 3 (appliquer, raisonner). */
  difficulty: number;
  matches?: string[];
  /** Le rang du thème, pour un lot de nouvelles questions ou un examen blanc. */
  theme?: number;
  /** Le rang de la leçon, pour un examen blanc sur plusieurs leçons. */
  lesson?: number;
}

/** Ce que la requête accepte : une app qui ne sait pas afficher un ordre n'en reçoit pas. */
export function readKinds(raw: unknown): QuestionKind[] {
  const kinds = (Array.isArray(raw) ? raw : [])
    .filter((kind): kind is QuestionKind => ALL_KINDS.includes(kind as QuestionKind));
  return kinds.includes("choice") ? kinds : ["choice"];
}

/** « Vrai » et « Faux » dans la langue des notes. */
const TRUE_FALSE: Record<string, [string, string]> = {
  fr: ["Vrai", "Faux"],
  en: ["True", "False"],
  de: ["Richtig", "Falsch"],
  it: ["Vero", "Falso"],
  es: ["Verdadero", "Falso"],
  pt: ["Verdadeiro", "Falso"],
  cs: ["Pravda", "Nepravda"],
  nl: ["Waar", "Onwaar"],
  el: ["Σωστό", "Λάθος"],
  hu: ["Igaz", "Hamis"],
  pl: ["Prawda", "Fałsz"],
  ro: ["Adevărat", "Fals"],
  sv: ["Sant", "Falskt"],
  tr: ["Doğru", "Yanlış"],
  sk: ["Pravda", "Nepravda"],
  da: ["Sandt", "Falsk"],
  fi: ["Tosi", "Epätosi"],
  et: ["Õige", "Vale"],
  hr: ["Točno", "Netočno"],
  sl: ["Drži", "Ne drži"],
  sr: ["Tačno", "Netačno"],
  bg: ["Вярно", "Невярно"],
  ru: ["Верно", "Неверно"],
  ar: ["صحيح", "خطأ"],
};

export function trueFalseLabels(language: string | undefined): [string, string] {
  return TRUE_FALSE[(language ?? "").trim().toLowerCase().slice(0, 2)] ?? TRUE_FALSE.fr!;
}

/** Vrai quand la langue des notes est une de celles dont on connaît « vrai » et « faux ». */
function knowsTrueFalse(language: string | undefined): boolean {
  return (language ?? "").trim().toLowerCase().slice(0, 2) in TRUE_FALSE;
}

const TRUE_WORDS = new Set(Object.values(TRUE_FALSE).map(([yes]) => promptKey(yes)));
const FALSE_WORDS = new Set(Object.values(TRUE_FALSE).map(([, no]) => promptKey(no)));

/**
 * **La réponse d'un vrai/faux**, lue comme le modèle l'écrit : un booléen, le rang dans
 * « Vrai, Faux », ou le mot lui-même dans n'importe quelle langue servie (« True »,
 * « Richtig », « "faux" »). `null` quand on ne sait pas : la question part plutôt que d'être
 * corrigée au hasard.
 */
export function readTrueFalse(value: unknown): boolean | null {
  if (value === true || value === 0) return true;
  if (value === false || value === 1) return false;
  if (typeof value !== "string") return null;
  const key = promptKey(value);
  if (key === "0") return true;
  if (key === "1") return false;
  if (TRUE_WORDS.has(key)) return true;
  if (FALSE_WORDS.has(key)) return false;
  return null;
}

/** Le trou d'une phrase : une seule graphie, celle de l'app (`ClozeGap.marker`). */
export const GAP = "…";

export function normalizeGap(text: string): string {
  let out = text;
  for (const candidate of ["[...]", "(...)", "[…]", "(…)", "_____", "____", "___", "__", "..."]) {
    out = out.split(candidate).join(GAP);
  }
  while (out.includes(GAP + GAP)) out = out.split(GAP + GAP).join(GAP);
  return out;
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

function shuffled<T>(items: T[], seed: string): T[] {
  const out = [...items];
  const random = seededRandom(seed);
  for (let i = out.length - 1; i > 0; i -= 1) {
    const j = Math.floor(random() * (i + 1));
    [out[i], out[j]] = [out[j]!, out[i]!];
  }
  return out;
}

function shortText(value: unknown, maxWords: number): string {
  return cleanInline(clampWords(cleanText(cellValue(value), 240).replace(/\*\*/g, ""), maxWords));
}

function readDifficulty(raw: unknown, fallback: number): number {
  const value = typeof raw === "number" ? Math.round(raw) : fallback;
  return Math.min(3, Math.max(1, value));
}

/** Une liste sans doublons ni vides : les éléments d'un ordre, les termes d'une association. */
function distinct(raw: unknown, maxWords: number): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const item of Array.isArray(raw) ? raw : []) {
    const text = shortText(item, maxWords);
    if (text && !seen.has(text.toLowerCase())) {
      seen.add(text.toLowerCase());
      out.push(text);
    }
  }
  return out;
}

/**
 * **Le rang de la bonne réponse**, quelle que soit la façon dont le modèle l'écrit : un nombre,
 * un nombre en texte (« "2" »), ou le texte même de la bonne proposition. Sans cette lecture,
 * une question juste partait parce que sa réponse était écrite « "0" ».
 */
export function answerIndex(raw: unknown, choices: readonly unknown[]): number {
  if (typeof raw === "number" && Number.isFinite(raw)) return Math.round(raw);
  if (typeof raw !== "string") return -1;
  const text = raw.trim();
  if (/^\d+$/.test(text)) return Number(text);
  const key = promptKey(text);
  if (!key) return -1;
  return choices.findIndex((choice) => typeof choice === "string" && promptKey(choice) === key);
}

/** Un QCM ou une phrase à trou : une bonne proposition, au moins deux fausses distinctes. */
function readChoices(question: Record<string, unknown>, seed: string): { choices: string[]; answer: number } | null {
  const rawChoices = Array.isArray(question.choices) ? question.choices : [];
  const answer = answerIndex(question.answer, rawChoices);
  if (answer < 0 || answer >= rawChoices.length) return null;
  const right = shortText(rawChoices[answer], 14);
  const seen = new Set([right.toLowerCase()]);
  const wrong: string[] = [];
  rawChoices.forEach((choice, index) => {
    if (index === answer) return;
    const text = shortText(choice, 14);
    if (text && !seen.has(text.toLowerCase())) {
      seen.add(text.toLowerCase());
      wrong.push(text);
    }
  });
  if (!right || wrong.length < 2) return null;
  // Le modèle met presque toujours la bonne réponse en premier : on mélange, de façon
  // reproductible. L'app mélange encore à l'affichage, à chaque passage.
  const choices = shuffled([right, ...wrong.slice(0, LIMITS.choices - 1)], seed);
  return { choices, answer: choices.indexOf(right) };
}

/**
 * **Une question aux règles**, quelle que soit sa forme. Une forme que l'app ne sait pas
 * afficher, ou une question mal formée, ne passe pas : mieux vaut une question de moins
 * qu'un écran cassé. Une phrase à trou sans trou redevient un QCM.
 */
export function readQuestion(
  raw: unknown,
  seed: string,
  options: { kinds?: readonly QuestionKind[]; language?: string } = {},
): QuizQuestion | null {
  if (!raw || typeof raw !== "object") return null;
  const question = raw as Record<string, unknown>;
  const kinds = options.kinds ?? ["choice"];
  let kind = (typeof question.kind === "string" ? question.kind : "choice") as QuestionKind;
  if (!ALL_KINDS.includes(kind)) kind = "choice";
  const prompt = cleanInline(clampWords(cleanText(question.prompt, 400).replace(/\*\*/g, ""), 30));
  const why = cleanInline(clampWords(cleanText(question.why, 500).replace(/\*\*/g, ""), 40));
  const difficulty = readDifficulty(question.difficulty ?? question.level, 2);
  if (!prompt) return null;

  if (kind === "truefalse") {
    const isTrue = readTrueFalse(question.answer);
    if (isTrue === null) return null;
    // L'app dessine « vrai » au rang 0 (la coche) et « faux » au rang 1 (la croix), et la
    // réponse se lit sur ces rangs. Les libellés de la langue demandée sont donc les seuls
    // sûrs ; ceux du modèle ne servent que pour une langue qu'on ne connaît pas (une leçon
    // « dans la langue du document »), et remis dans l'ordre s'il a commencé par « faux ».
    const given = distinct(question.choices, 3);
    let labels: string[] = trueFalseLabels(options.language);
    if (!knowsTrueFalse(options.language) && given.length === 2) {
      labels = FALSE_WORDS.has(promptKey(given[0]!)) || TRUE_WORDS.has(promptKey(given[1]!))
        ? [given[1]!, given[0]!]
        : given;
    }
    // Une app qui ne connaît pas encore le vrai/faux le lit comme un QCM à deux choix.
    return { kind: kinds.includes("truefalse") ? "truefalse" : "choice", prompt, choices: [...labels], answer: isTrue ? 0 : 1, why, difficulty };
  }

  if (kind === "order") {
    if (!kinds.includes("order")) return null;
    const items = distinct(question.items ?? question.choices, 12).slice(0, LIMITS.orderItemsMax);
    if (items.length < LIMITS.orderItemsMin) return null;
    return { kind, prompt, choices: items, answer: 0, why, difficulty };
  }

  if (kind === "match") {
    if (!kinds.includes("match")) return null;
    const seen = new Set<string>();
    const left: string[] = [];
    const right: string[] = [];
    for (const pair of Array.isArray(question.pairs) ? question.pairs : []) {
      const entry = Array.isArray(pair) ? pair : [];
      const term = shortText(entry[0], 8);
      const match = shortText(entry[1], 14);
      if (!term || !match || seen.has(term.toLowerCase()) || seen.has(match.toLowerCase())) continue;
      seen.add(term.toLowerCase());
      seen.add(match.toLowerCase());
      left.push(term);
      right.push(match);
    }
    if (left.length < LIMITS.matchPairsMin) return null;
    return {
      kind,
      prompt,
      choices: left.slice(0, LIMITS.matchPairsMax),
      matches: right.slice(0, LIMITS.matchPairsMax),
      answer: 0,
      why,
      difficulty,
    };
  }

  const chosen = readChoices(question, seed);
  if (!chosen) return null;
  if (kind === "gap") {
    // Le trou se repère avant la coupe à 30 mots : coupé, il ferait de la phrase un QCM
    // sans question.
    const sentence = cleanInline(clampWords(normalizeGap(cleanText(question.prompt, 400).replace(/\*\*/g, "")), 40));
    // Une phrase qui contient déjà le mot à trouver le donne : elle ne vérifie plus rien.
    if (givesAway(sentence, chosen.choices[chosen.answer]!)) return null;
    if (kinds.includes("gap") && sentence.includes(GAP)) {
      return { kind, prompt: sentence, ...chosen, why, difficulty };
    }
    return { kind: "choice", prompt: sentence, ...chosen, why, difficulty };
  }
  return { kind: "choice", prompt, ...chosen, why, difficulty };
}

/** Vrai quand la phrase à trou écrit en toutes lettres la bonne réponse, hors du trou. */
export function givesAway(sentence: string, answer: string): boolean {
  const key = promptKey(answer);
  if (key.length < 3) return false;
  return ` ${promptKey(sentence)} `.includes(` ${key} `);
}

/**
 * **La question de fin d'abord.** L'app prend la première question d'un thème pour la question
 * de fin de son cercle Notes (`ThemeQuiz.final`) : elle doit vérifier l'idée clé, simplement.
 * Le modèle ne commence pas toujours par là, et une question mal formée qui part peut laisser
 * la première place à une remise en ordre de difficulté 3. On remonte donc la première
 * question simple (QCM, vrai/faux, trou, difficulté 1 ou 2), sinon le premier QCM ; l'ordre
 * des autres ne change pas.
 */
export function finalFirst(questions: QuizQuestion[]): QuizQuestion[] {
  const simple = (question: QuizQuestion) => question.kind === "choice" || question.kind === "truefalse" || question.kind === "gap";
  let index = questions.findIndex((question) => simple(question) && question.difficulty <= 2);
  if (index === -1) index = questions.findIndex(simple);
  if (index <= 0) return questions;
  return [questions[index]!, ...questions.slice(0, index), ...questions.slice(index + 1)];
}

/**
 * **Partager un budget de caractères équitablement** entre des textes. Les plus courts gardent
 * tout, et ce qu'ils laissent revient aux plus longs. Couper dans l'ordre, au fil de l'eau,
 * vidait les derniers thèmes : un examen blanc sur une leçon de dix thèmes n'en voyait que
 * les quatre premiers, et n'interrogeait que sur eux.
 */
export function fairShares(lengths: readonly number[], budget: number): number[] {
  const shares = lengths.map(() => 0);
  let left = Math.max(0, Math.floor(budget));
  let open = lengths.map((length, index) => ({ length: Math.max(0, length), index }));
  while (open.length > 0 && left > 0) {
    const even = Math.floor(left / open.length);
    const short = open.filter((entry) => entry.length - shares[entry.index]! <= even);
    if (short.length === 0) {
      for (const entry of open) shares[entry.index]! += even;
      // Le reste de la division va aux premiers, un caractère chacun.
      let rest = left - even * open.length;
      for (const entry of open) {
        if (rest <= 0) break;
        shares[entry.index]! += 1;
        rest -= 1;
      }
      break;
    }
    for (const entry of short) {
      left -= entry.length - shares[entry.index]!;
      shares[entry.index] = entry.length;
    }
    open = open.filter((entry) => !short.includes(entry));
  }
  return shares;
}

/**
 * Les questions d'un thème, sans doublons : deux questions dont l'énoncé est le même, à la
 * casse près, n'en font qu'une.
 */
export function readQuestions(
  raw: unknown,
  seed: string,
  options: { kinds?: readonly QuestionKind[]; language?: string; max?: number; avoid?: readonly string[] } = {},
): QuizQuestion[] {
  const seen = new Set((options.avoid ?? []).map((prompt) => promptKey(prompt)));
  const out: QuizQuestion[] = [];
  (Array.isArray(raw) ? raw : []).forEach((item, index) => {
    const question = readQuestion(item, `${seed}:${index}`, options);
    if (!question) return;
    const key = promptKey(question.prompt);
    if (seen.has(key)) return;
    seen.add(key);
    const theme = (item as Record<string, unknown>)?.theme;
    if (typeof theme === "number" && Number.isFinite(theme)) question.theme = Math.round(theme);
    const lesson = (item as Record<string, unknown>)?.lesson;
    if (typeof lesson === "number" && Number.isFinite(lesson)) question.lesson = Math.round(lesson);
    out.push(question);
  });
  return out.slice(0, options.max ?? LIMITS.questionsPerTheme);
}

/** La clé d'un énoncé : sans casse, sans ponctuation, pour repérer une question déjà posée. */
export function promptKey(prompt: string): string {
  return prompt.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^\p{L}\p{N}]+/gu, " ").trim();
}

// MARK: - Flashcards

export interface Flashcard {
  /** `basic` (recto/verso) ou `cloze` (le recto est une phrase à trou, le verso ce qui manque). */
  kind: "basic" | "cloze";
  front: string;
  back: string;
}

export function readFlashcards(raw: unknown, max: number = LIMITS.flashcardsPerTheme): Flashcard[] {
  const seen = new Set<string>();
  return (Array.isArray(raw) ? raw : [])
    .map((card): Flashcard => {
      const entry = (card ?? {}) as Record<string, unknown>;
      const front = cleanInline(clampWords(cleanText(entry.front, 300).replace(/\*\*/g, ""), 24));
      const back = cleanInline(clampWords(cleanText(cellValue(entry.back), 400).replace(/\*\*/g, ""), 30));
      if (entry.kind === "cloze") {
        const sentence = normalizeGap(front);
        if (sentence.includes(GAP)) return { kind: "cloze", front: sentence, back };
      }
      return { kind: "basic", front, back };
    })
    .filter((card) => {
      const key = promptKey(card.front);
      if (!card.front || !card.back || seen.has(key)) return false;
      seen.add(key);
      return true;
    })
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
  /**
   * Chaque thème : son icône 3D, son pictogramme sur le chemin (jamais deux fois le même) et
   * les notions qu'il doit couvrir.
   */
  themes: { title: string; icon: string; symbol: string; points: string[] }[];
  groups: { name: string; themes: number[] }[];
  intro: { lines: string[]; minutes: number };
  takeaways: string[];
  shortened: boolean;
  singleQuiz: boolean;
}

/**
 * **Jamais deux fois la même icône sur un chemin.** Un thème dont l'icône est déjà prise (par
 * un thème précédent ou par la leçon) en reçoit une autre de la base, la première libre dans
 * l'ordre de `LESSON_ICONS` : le chemin reste lisible d'un coup d'œil.
 */
export function uniqueIcons<T extends { icon: string }>(themes: T[], lessonIcon: string): T[] {
  const used = new Set<string>([lessonIcon]);
  return themes.map((theme) => {
    if (!used.has(theme.icon)) {
      used.add(theme.icon);
      return theme;
    }
    const free = LESSON_ICONS.find((icon) => !used.has(icon.id))?.id;
    if (!free) return theme;
    used.add(free);
    return { ...theme, icon: free };
  });
}

/**
 * **Le plan aux règles** : de 4 à 12 thèmes (4 exactement, et un seul quiz, pour une leçon très
 * courte), des titres de six mots au plus, des icônes de la base, des paliers sur le découpage
 * de l'app, une durée calculée et non devinée.
 */
export function readPlan(
  raw: unknown,
  options: { shortSource: boolean; shortened: boolean; fallbackTitle: string; maxThemes?: number },
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
        symbol: typeof entry.symbol === "string" ? entry.symbol : "",
        points: readSentences(entry.points, LIMITS.pointsPerTheme, 12).map((point) => point.replace(/\*\*/g, "")),
      };
    })
    .filter((theme) => {
      const key = theme.title.toLowerCase();
      if (!theme.title || seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  const singleQuiz = options.shortSource;
  const ceiling = Math.min(LIMITS.maxThemes, Math.max(LIMITS.minThemes, options.maxThemes ?? LIMITS.maxThemes));
  themes = themes.slice(0, singleQuiz ? LIMITS.minThemes : ceiling);
  if (themes.length < (singleQuiz ? 2 : LIMITS.minThemes - 1)) return null;
  const lessonIcon = normalizeIcon(plan.icon) || DEFAULT_ICON;
  themes = uniqueIcons(themes, lessonIcon);
  const symbols = uniqueSymbols(themes.map((theme) => theme.symbol));
  themes = themes.map((theme, index) => ({ ...theme, symbol: symbols[index]! }));

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
    icon: lessonIcon,
    themes,
    groups: groups.map((themes, index) => ({ name: names[index] ?? "", themes })),
    intro: { lines, minutes: estimateMinutes(themes.length, groups.length) },
    takeaways: readSentences(plan.takeaways, LIMITS.lessonTakeaways, 22),
    shortened: options.shortened,
    singleQuiz,
  };
}
