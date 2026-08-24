/**
 * La fiche d'un cours, côté serveur.
 *
 * Le modèle rend une structure de blocs ; ce fichier la ramène à ce que l'application sait
 * afficher, et en tire la version à plat qui servira de contexte aux cartes. Les garde-fous
 * sont ici et pas seulement dans le prompt : une consigne se respecte à peu près, un plafond
 * se respecte toujours.
 */

import { stripEmDashes } from "./fal.ts";

export type SheetBlock =
  | { type: "heading"; level: number; text: string }
  | { type: "paragraph"; text: string }
  | { type: "definition"; term: string; text: string }
  | { type: "callout"; tone: string; text: string }
  | { type: "steps"; title?: string; items: string[] }
  | { type: "table"; title?: string; headers: string[]; rows: string[][]; caption?: string }
  | {
    type: "chart";
    title?: string;
    unit?: string;
    bars: { label: string; value: number }[];
    caption?: string;
  }
  | { type: "formula"; latex: string; caption?: string };

export const SHEET_LIMITS = {
  blocks: 60,
  stepsBlocks: 2,
  stepsItems: 7,
  tableColumns: 4,
  tableRows: 8,
  chartBars: 6,
  /** Nombre de passages surlignés sur toute la fiche. Au delà, plus rien ne ressort. */
  highlights: 5,
} as const;

const TONES = new Set(["essentiel", "attention", "exemple", "astuce"]);

/**
 * Nettoie un texte de bloc.
 *
 * On garde le balisage en ligne, qui met la fiche en page, et on retire ce qui trahit un
 * texte laissé tel que le modèle l'a rendu : tirets cadratins, puces, dièses de markdown.
 */
function cleanText(value: unknown): string {
  if (typeof value !== "string") return "";

  let text = stripEmDashes(value)
    .replace(/\u00A0/g, " ")
    .replace(/\r?\n+/g, " ");

  // Une puce ou un dièse en tête de bloc est du markdown qui a fui hors de sa structure :
  // le bloc porte déjà sa forme.
  text = text.replace(/^\s*(?:[-•◦·>]|#{1,6}|\d+[.)])\s+/, "");

  return text.replace(/\s{2,}/g, " ").trim();
}

function cleanOptional(value: unknown): string | undefined {
  const text = cleanText(value);
  return text.length > 0 ? text : undefined;
}

function toNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number.parseFloat(value.replace(/\s/g, "").replace(",", ".").replace("%", ""));
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function cellText(value: unknown): string {
  if (typeof value === "number") return String(value);
  if (typeof value === "boolean") return value ? "oui" : "non";
  return cleanText(value);
}

/** Ramène la fiche du modèle à ce que l'application sait afficher. */
export function normalizeSheet(raw: unknown): SheetBlock[] {
  const source = Array.isArray(raw)
    ? raw
    : Array.isArray((raw as { blocks?: unknown })?.blocks)
    ? (raw as { blocks: unknown[] }).blocks
    : [];

  const blocks: SheetBlock[] = [];
  let stepsBlocks = 0;
  let highlights = 0;

  for (const entry of source) {
    if (blocks.length >= SHEET_LIMITS.blocks) break;
    if (!entry || typeof entry !== "object") continue;

    const record = entry as Record<string, unknown>;
    const type = typeof record.type === "string" ? record.type.trim().toLowerCase() : "";
    const block = normalizeBlock(type, record, () => stepsBlocks < SHEET_LIMITS.stepsBlocks);
    if (!block) continue;

    if (block.type === "steps") stepsBlocks += 1;

    // Le surligneur est plafonné sur toute la fiche : passé le quota, les marques
    // suivantes sont retirées plutôt que de tout faire ressortir.
    const counted = countHighlights(block);
    if (highlights + counted > SHEET_LIMITS.highlights) {
      blocks.push(removeHighlights(block));
    } else {
      highlights += counted;
      blocks.push(block);
    }
  }

  return blocks;
}

function normalizeBlock(
  type: string,
  record: Record<string, unknown>,
  allowsSteps: () => boolean,
): SheetBlock | null {
  switch (type) {
    case "heading": {
      const text = cleanText(record.text ?? record.title);
      if (text.length < 2) return null;
      const level = toNumber(record.level) === 1 ? 1 : 2;
      return { type: "heading", level, text };
    }

    case "paragraph": {
      const text = cleanText(record.text);
      if (text.length < 30) return null;
      return { type: "paragraph", text };
    }

    case "definition": {
      const term = cleanText(record.term ?? record.title);
      const text = cleanText(record.text);
      if (term.length < 2 || text.length < 15) return null;
      return { type: "definition", term, text };
    }

    case "callout": {
      const text = cleanText(record.text);
      if (text.length < 15) return null;
      const rawTone = typeof record.tone === "string" ? record.tone.trim().toLowerCase() : "";
      const tone = TONES.has(rawTone) ? rawTone : "essentiel";
      return { type: "callout", tone, text };
    }

    case "steps": {
      if (!allowsSteps()) return null;
      const items = (Array.isArray(record.items) ? record.items : [])
        .map(cellText)
        .filter((item) => item.length >= 8)
        .slice(0, SHEET_LIMITS.stepsItems);
      if (items.length < 2) return null;
      return { type: "steps", title: cleanOptional(record.title), items };
    }

    case "table": {
      const headers = (Array.isArray(record.headers) ? record.headers : [])
        .map(cellText)
        .slice(0, SHEET_LIMITS.tableColumns);
      if (headers.length < 2) return null;

      const rows = (Array.isArray(record.rows) ? record.rows : [])
        .map((row) => (Array.isArray(row) ? row.map(cellText) : []))
        .filter((row) => row.some((cell) => cell.length > 0))
        .map((row) => {
          const trimmed = row.slice(0, headers.length);
          while (trimmed.length < headers.length) trimmed.push("");
          return trimmed;
        })
        .slice(0, SHEET_LIMITS.tableRows);
      if (rows.length < 2) return null;

      return { type: "table", title: cleanOptional(record.title), headers, rows, caption: cleanOptional(record.caption) };
    }

    case "chart": {
      const bars = (Array.isArray(record.bars) ? record.bars : [])
        .map((bar) => {
          if (!bar || typeof bar !== "object") return null;
          const entry = bar as Record<string, unknown>;
          const label = cleanText(entry.label);
          const value = toNumber(entry.value);
          if (label.length === 0 || value === null || value < 0) return null;
          return { label, value };
        })
        .filter((bar): bar is { label: string; value: number } => bar !== null)
        .slice(0, SHEET_LIMITS.chartBars);

      // Une seule barre ne compare rien, et un graphe tout à zéro ne dit rien.
      if (bars.length < 2 || !bars.some((bar) => bar.value > 0)) return null;

      return {
        type: "chart",
        title: cleanOptional(record.title),
        unit: cleanOptional(record.unit),
        bars,
        caption: cleanOptional(record.caption),
      };
    }

    case "formula": {
      const latex = typeof record.latex === "string"
        ? record.latex.trim().replace(/^\$+|\$+$/g, "").trim()
        : cleanText(record.text);
      if (latex.length < 2) return null;
      return { type: "formula", latex, caption: cleanOptional(record.caption) };
    }

    default:
      return null;
  }
}

function textsOf(block: SheetBlock): string[] {
  switch (block.type) {
    case "heading":
    case "paragraph":
    case "callout":
      return [block.text];
    case "definition":
      return [block.term, block.text];
    case "steps":
      return [block.title ?? "", ...block.items];
    case "table":
      return [block.title ?? "", ...block.headers, ...block.rows.flat(), block.caption ?? ""];
    case "chart":
      return [block.title ?? "", ...block.bars.map((bar) => bar.label), block.caption ?? ""];
    case "formula":
      return [block.caption ?? ""];
  }
}

function countHighlights(block: SheetBlock): number {
  return textsOf(block).reduce((total, text) => total + Math.floor((text.match(/==/g)?.length ?? 0) / 2), 0);
}

function removeHighlights(block: SheetBlock): SheetBlock {
  const strip = (text: string) => text.replace(/==/g, "");

  switch (block.type) {
    case "heading":
      return { ...block, text: strip(block.text) };
    case "paragraph":
    case "callout":
      return { ...block, text: strip(block.text) };
    case "definition":
      return { ...block, term: strip(block.term), text: strip(block.text) };
    case "steps":
      return { ...block, items: block.items.map(strip) };
    default:
      return block;
  }
}

/** Retire le balisage en ligne : c'est la version qui part au modèle pour les cartes. */
export function stripInlineMarkup(text: string): string {
  return text
    .replace(/\*\*/g, "")
    .replace(/==/g, "")
    .replace(/\*/g, "")
    .replace(/`/g, "")
    .replace(/\$/g, "")
    .replace(/\s{2,}/g, " ")
    .trim();
}

/**
 * La fiche à plat, une notion par ligne.
 *
 * C'est le contexte envoyé au modèle quand il faut écrire des cartes ou expliquer un
 * passage. Les valeurs des tableaux et des graphes y sont **conservées**, avec le nom de
 * leur colonne : « Phase photochimique : thylakoïdes » se révise, « thylakoïdes » seul non.
 */
export function sheetToPlainText(blocks: SheetBlock[]): string {
  const lines: string[] = [];

  for (const block of blocks) {
    switch (block.type) {
      case "heading":
      case "paragraph":
      case "callout":
        lines.push(stripInlineMarkup(block.text));
        break;

      case "definition":
        lines.push(`${stripInlineMarkup(block.term)} : ${stripInlineMarkup(block.text)}`);
        break;

      case "steps":
        if (block.title) lines.push(stripInlineMarkup(block.title));
        block.items.forEach((item, index) => lines.push(`${index + 1}. ${stripInlineMarkup(item)}`));
        break;

      case "table": {
        if (block.title) lines.push(stripInlineMarkup(block.title));
        for (const row of block.rows) {
          // Un tableau de comparaison a souvent une première colonne sans intitulé : la
          // cellule vaut alors pour elle-même.
          const cells = row
            .map((cell, index) => [stripInlineMarkup(block.headers[index] ?? ""), stripInlineMarkup(cell)])
            .filter(([, value]) => value.length > 0)
            .map(([header, value]) => (header ? `${header} : ${value}` : value));
          if (cells.length > 0) lines.push(cells.join(", "));
        }
        if (block.caption) lines.push(stripInlineMarkup(block.caption));
        break;
      }

      case "chart": {
        if (block.title) lines.push(stripInlineMarkup(block.title));
        const unit = block.unit ? ` ${block.unit}` : "";
        lines.push(block.bars.map((bar) => `${stripInlineMarkup(bar.label)} : ${bar.value}${unit}`).join(", "));
        if (block.caption) lines.push(stripInlineMarkup(block.caption));
        break;
      }

      case "formula":
        lines.push(
          block.caption ? `${block.latex} (${stripInlineMarkup(block.caption)})` : block.latex,
        );
        break;
    }
  }

  return lines.filter((line) => line.length > 0).join("\n");
}
