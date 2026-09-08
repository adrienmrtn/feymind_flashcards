/**
 * La fiche d'un cours, côté serveur.
 *
 * Le modèle rend une structure de blocs ; ce fichier la ramène à ce que l'application sait
 * afficher, et en tire la version à plat qui servira de contexte aux cartes. Les garde-fous
 * sont ici et pas seulement dans le prompt : une consigne se respecte à peu près, un plafond
 * se respecte toujours.
 */

import { stripEmDashes } from "./fal.ts";

export type SheetCrop = { x: number; y: number; w: number; h: number };

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
  | { type: "formula"; latex: string; caption?: string }
  | {
    type: "figure";
    caption: string;
    page?: number;
    crop?: SheetCrop;
    /** JPEG recadré, en data URL. Absent tant que la coupe n'a pas encore été faite. */
    image?: string;
  };

export const SHEET_LIMITS = {
  blocks: 60,
  stepsBlocks: 3,
  stepsItems: 7,
  tableColumns: 4,
  tableRows: 8,
  chartBars: 6,
  chartBlocks: 3,
  figureBlocks: 4,
  /**
   * Nombre de passages mis en avant sur toute la fiche. Au delà, plus rien ne ressort.
   *
   * C'est le seul garde-fou qui reste sur le surlignage, et il ne va que dans un sens : il
   * en retire, il n'en ajoute pas. Il y avait un plancher en face, qui marquait trois
   * passages quand le modèle n'en avait marqué aucun ; il choisissait la première phrase de
   * la bonne longueur, ce qui n'est pas ce qui compte dans un cours. Une marque tombée sur
   * la phrase d'à côté apprend la phrase d'à côté.
   */
  highlights: 12,
  /**
   * Nombre d'objets qui peuvent se suivre sans un paragraphe entre eux.
   *
   * C'est le garde-fou contre la fiche en accordéon : une définition, un encadré, un
   * tableau et un graphe collés les uns aux autres sans une ligne pour les relier. Deux
   * objets qui se touchent éclairent souvent la même notion ; cinq d'affilée, c'est un
   * vidage de notes. Au-delà de quatre, le surplus est écarté.
   */
  objectRun: 4,
} as const;

const TONES = new Set(["essentiel", "attention", "exemple", "astuce"]);

/**
 * Les blocs qui prennent une surface au lieu de reposer sur le papier.
 *
 * C'est la distinction qui porte la mise en page de la fiche côté application, et c'est
 * aussi celle qui décide du rythme : le texte est posé à même la page, les objets sont
 * encartés. Deux objets qui se touchent font deux cartes empilées.
 */
const OBJECT_TYPES = new Set([
  "definition",
  "callout",
  "steps",
  "table",
  "chart",
  "formula",
  "figure",
]);

function isObject(block: SheetBlock): boolean {
  return OBJECT_TYPES.has(block.type);
}

/**
 * L'encadré « essentiel » ne s'écarte jamais, même au milieu d'une file d'objets.
 *
 * Le prompt lui demande de fermer la fiche, et c'est le bloc que l'étudiant relit en dernier.
 * Une fin de fiche en « paragraphe, tableau, graphe, essentiel » le placerait quatrième de la
 * file : le garde-fou l'écarterait, et emporterait avec lui la seule chose qu'on avait
 * exigée.
 */
function isKeystone(block: SheetBlock): boolean {
  return block.type === "callout" && block.tone === "essentiel";
}

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

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function normalizeCrop(raw: unknown): SheetCrop | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const entry = raw as Record<string, unknown>;
  const x = toNumber(entry.x);
  const y = toNumber(entry.y);
  const w = toNumber(entry.w);
  const h = toNumber(entry.h);
  if (x === null || y === null || w === null || h === null) return undefined;

  const crop = {
    x: clamp(x, 0, 0.95),
    y: clamp(y, 0, 0.95),
    w: clamp(w, 0.08, 1),
    h: clamp(h, 0.08, 1),
  };
  if (crop.x + crop.w > 1) crop.w = 1 - crop.x;
  if (crop.y + crop.h > 1) crop.h = 1 - crop.y;
  if (crop.w < 0.08 || crop.h < 0.08) return undefined;
  return crop;
}

/**
 * Une data URL JPEG, ou un base64 nu assez long pour être une vraie image.
 *
 * Le plafond n'est pas cosmétique : trop bas, un schéma dense recadré disparaissait
 * à l'enregistrement (la légende restait, l'image non). 1 200 000 caractères, c'est
 * ~900 Ko — largement assez pour quatre figures à 640 px, sans ouvrir la porte à
 * une fiche de plusieurs mégaoctets.
 */
function normalizeFigureImage(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const text = value.trim();
  if (text.length < 32 || text.length > 1_200_000) return undefined;
  if (text.startsWith("data:image/")) return text;
  if (/^[A-Za-z0-9+/=\s]+$/.test(text.slice(0, 120))) return `data:image/jpeg;base64,${text.replace(/\s/g, "")}`;
  return undefined;
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
  let chartBlocks = 0;
  let figureBlocks = 0;
  let highlights = 0;
  let objectRun = 0;

  for (const entry of source) {
    if (blocks.length >= SHEET_LIMITS.blocks) break;
    if (!entry || typeof entry !== "object") continue;

    const record = entry as Record<string, unknown>;
    const type = typeof record.type === "string" ? record.type.trim().toLowerCase() : "";
    const block = normalizeBlock(type, record, {
      allowsSteps: () => stepsBlocks < SHEET_LIMITS.stepsBlocks,
      allowsChart: () => chartBlocks < SHEET_LIMITS.chartBlocks,
      allowsFigure: () => figureBlocks < SHEET_LIMITS.figureBlocks,
    });
    if (!block) continue;

    // Le rythme de la page, tenu par le code. Un titre remet le compteur à zéro comme un
    // paragraphe : il ouvre une partie, donc il rompt la file d'objets.
    if (isObject(block)) {
      if (objectRun >= SHEET_LIMITS.objectRun && !isKeystone(block)) continue;
      objectRun += 1;
    } else {
      objectRun = 0;
    }

    if (block.type === "steps") stepsBlocks += 1;
    if (block.type === "chart") chartBlocks += 1;
    if (block.type === "figure") figureBlocks += 1;

    // La mise en avant est plafonnée sur toute la fiche : passé le quota, les marques
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
  allow: {
    allowsSteps: () => boolean;
    allowsChart: () => boolean;
    allowsFigure: () => boolean;
  },
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
      if (!allow.allowsSteps()) return null;
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
      if (!allow.allowsChart()) return null;
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

    case "figure": {
      if (!allow.allowsFigure()) return null;
      const caption = cleanText(record.caption ?? record.text ?? record.title);
      if (caption.length < 4) return null;
      const page = toNumber(record.page);
      const crop = normalizeCrop(record.crop);
      const image = normalizeFigureImage(record.image);
      if (page === null && !image) return null;
      return {
        type: "figure",
        caption,
        page: page !== null && page >= 1 ? Math.round(page) : undefined,
        crop,
        image,
      };
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
    case "figure":
      return [block.caption];
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

      case "figure":
        lines.push(stripInlineMarkup(block.caption));
        break;
    }
  }

  return lines.filter((line) => line.length > 0).join("\n");
}
