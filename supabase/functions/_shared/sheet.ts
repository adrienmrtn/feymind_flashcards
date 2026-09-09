/**
 * La fiche d'un cours, côté serveur.
 *
 * Le modèle rend une structure de blocs ; ce fichier la ramène à ce que l'application sait
 * afficher, et en tire la version à plat qui servira de contexte aux cartes. Les garde-fous
 * sont ici et pas seulement dans le prompt : une consigne se respecte à peu près, un plafond
 * se respecte toujours.
 *
 * **Le vocabulaire s'est réduit à quatre blocs**, et c'est le changement de fond. Il y en
 * avait neuf : définition encadrée, encadré de ton, suite d'étapes, tableau, graphe à barres,
 * figure recadrée. Chacun se défendait pris isolément, et ensemble ils faisaient une page qui
 * ressemblait à une brochure - un cours n'est pas une infographie, et l'étudiant qui relit la
 * veille ne veut pas d'un graphe, il veut son cours mis au propre. Pire : ces objets étaient
 * décidés par le modèle et fermés au lecteur, alors que la fiche est **la sienne** et doit se
 * corriger comme un document.
 *
 * Reste donc ce qu'on écrit à la main sur une feuille : des titres, des paragraphes, des
 * listes, et les formules qu'on ne peut pas écrire en toutes lettres. La mise en valeur passe
 * par le balisage en ligne - gras, italique, surlignage de couleur - qui est modifiable, lui.
 *
 * Les anciens blocs ne sont pas jetés : ils sont **convertis**. Trente fiches existent en
 * base, et les faire disparaître pour changer de goût serait le pire service à rendre.
 */

import { stripEmDashes } from "./fal.ts";

export type SheetBlock =
  | { type: "heading"; level: number; text: string }
  | { type: "paragraph"; text: string }
  | { type: "list"; ordered: boolean; items: string[] }
  | { type: "formula"; latex: string; caption?: string };

/**
 * Les couleurs de surlignage.
 *
 * Cinq pastels, et pas une de plus. Le surlignage sert à retrouver un passage d'un coup
 * d'œil ; au-delà de cinq teintes on ne les distingue plus en diagonale, et une page qui en
 * porte huit n'a plus rien de mis en avant. Le modèle n'en choisit aucune - il marque ce qui
 * compte, en jaune - et c'est l'étudiant qui recolore, parce que le code couleur d'une fiche
 * n'appartient qu'à celui qui la relit.
 */
export const SHEET_HIGHLIGHTS = ["jaune", "menthe", "bleu", "rose", "lilas"] as const;

export type SheetHighlight = (typeof SHEET_HIGHLIGHTS)[number];

export const DEFAULT_HIGHLIGHT: SheetHighlight = "jaune";

export const SHEET_LIMITS = {
  /**
   * Le plafond de blocs. Il passe de 60 à 90, et c'est délibéré.
   *
   * Les fiches sortaient courtes : le vocabulaire d'objets poussait le modèle à résumer pour
   * faire tenir un tableau et un graphe, et une notion résumée à une ligne ne se révise pas.
   * Sans objets, le budget revient au texte, et une fiche a le droit d'être longue - elle
   * remplace le cours, elle ne l'annonce pas.
   */
  blocks: 90,
  /** Une liste de plus de dix points n'est plus une liste, c'est un paragraphe mal découpé. */
  listItems: 10,
  /**
   * Nombre de passages mis en avant sur toute la fiche. Au delà, plus rien ne ressort.
   *
   * Il monte avec la longueur : douze marques sur une fiche de quatre-vingt-dix blocs, c'est
   * une page sans relief. Le garde-fou ne va toujours que dans un sens - il en retire, il n'en
   * ajoute pas. Il y avait un plancher en face, qui marquait trois passages quand le modèle
   * n'en avait marqué aucun ; il choisissait la première phrase de la bonne longueur, ce qui
   * n'est pas ce qui compte dans un cours. Une marque tombée sur la phrase d'à côté apprend la
   * phrase d'à côté.
   */
  highlights: 24,
} as const;

export function normalizeSheet(raw: unknown): SheetBlock[] {
  const source = Array.isArray(raw)
    ? raw
    : Array.isArray((raw as { blocks?: unknown })?.blocks)
    ? (raw as { blocks: unknown[] }).blocks
    : [];

  const blocks: SheetBlock[] = [];
  let highlights = 0;

  for (const entry of source) {
    if (blocks.length >= SHEET_LIMITS.blocks) break;
    if (!entry || typeof entry !== "object") continue;

    const record = entry as Record<string, unknown>;
    const type = typeof record.type === "string" ? record.type.trim().toLowerCase() : "";

    for (const block of normalizeBlock(type, record)) {
      if (blocks.length >= SHEET_LIMITS.blocks) break;

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
  }

  return blocks;
}

/**
 * Un bloc du modèle, ou de l'ancien format, ramené au vocabulaire courant.
 *
 * Rend une **liste** et non un bloc unique, parce qu'une conversion produit parfois deux
 * choses : un tableau devient son titre puis ses lignes, une suite d'étapes devient son titre
 * puis sa liste. Un bloc jeté rendrait la fiche muette là où le cours disait quelque chose.
 */
function normalizeBlock(type: string, record: Record<string, unknown>): SheetBlock[] {
  switch (type) {
    case "heading": {
      const text = cleanText(record.text ?? record.title);
      if (text.length < 2) return [];
      const level = toNumber(record.level) === 1 ? 1 : 2;
      return [{ type: "heading", level, text }];
    }

    case "paragraph": {
      const text = cleanText(record.text);
      // Le plancher passe de 30 à 12 caractères : une fiche modifiable à la main contient des
      // paragraphes courts, et couper la ligne que l'étudiant vient d'écrire serait pire que
      // tout ce que ce plancher protège.
      if (text.length < 12) return [];
      return [{ type: "paragraph", text }];
    }

    case "list": {
      const items = itemsOf(record.items);
      if (items.length === 0) return [];
      return [{ type: "list", ordered: record.ordered === true, items }];
    }

    case "formula": {
      const latex = typeof record.latex === "string"
        ? record.latex.trim().replace(/^\$+|\$+$/g, "").trim()
        : cleanText(record.text);
      if (latex.length < 2) return [];
      return [{ type: "formula", latex, caption: cleanOptional(record.caption) }];
    }

    // MARK: - Les blocs d'avant, convertis plutôt que jetés

    case "definition": {
      const term = cleanText(record.term ?? record.title);
      const text = cleanText(record.text);
      if (term.length < 2 || text.length < 2) return [];
      // Le terme passe en gras dans la phrase : c'est exactement ce que la définition
      // encadrée disait, sans le cadre.
      return [{ type: "paragraph", text: `**${term}** : ${text}` }];
    }

    case "callout": {
      const text = cleanText(record.text);
      if (text.length < 2) return [];
      return [{ type: "paragraph", text }];
    }

    case "steps": {
      const items = itemsOf(record.items);
      if (items.length === 0) return [];
      const title = cleanOptional(record.title);
      const out: SheetBlock[] = [];
      if (title) out.push({ type: "paragraph", text: `**${title}**` });
      out.push({ type: "list", ordered: true, items });
      return out;
    }

    case "table": {
      const headers = (Array.isArray(record.headers) ? record.headers : []).map(cellText);
      const rows = (Array.isArray(record.rows) ? record.rows : [])
        .map((row) => (Array.isArray(row) ? row.map(cellText) : []))
        .filter((row) => row.some((cell) => cell.length > 0));
      if (rows.length === 0) return [];

      const out: SheetBlock[] = [];
      const title = cleanOptional(record.title);
      if (title) out.push({ type: "paragraph", text: `**${title}**` });

      // Une ligne devient « colonne : valeur, colonne : valeur ». C'est ce que la mise à plat
      // faisait déjà pour le modèle des cartes ; la fiche le lit maintenant pareil.
      const items = rows
        .map((row) =>
          row
            .map((cell, index) => [headers[index] ?? "", cell])
            .filter(([, value]) => value.length > 0)
            .map(([header, value]) => (header ? `**${header}** : ${value}` : value))
            .join(", ")
        )
        .filter((line) => line.length > 0)
        .slice(0, SHEET_LIMITS.listItems);
      if (items.length > 0) out.push({ type: "list", ordered: false, items });

      const caption = cleanOptional(record.caption);
      if (caption) out.push({ type: "paragraph", text: caption });
      return out;
    }

    case "chart": {
      const bars = (Array.isArray(record.bars) ? record.bars : [])
        .map((bar) => {
          if (!bar || typeof bar !== "object") return null;
          const entry = bar as Record<string, unknown>;
          const label = cleanText(entry.label);
          const value = toNumber(entry.value);
          if (label.length === 0 || value === null) return null;
          return { label, value };
        })
        .filter((bar): bar is { label: string; value: number } => bar !== null);
      if (bars.length === 0) return [];

      const out: SheetBlock[] = [];
      const title = cleanOptional(record.title);
      if (title) out.push({ type: "paragraph", text: `**${title}**` });
      const unit = cleanOptional(record.unit);
      out.push({
        type: "list",
        ordered: false,
        items: bars
          .slice(0, SHEET_LIMITS.listItems)
          .map((bar) => `**${bar.label}** : ${bar.value}${unit ? ` ${unit}` : ""}`),
      });
      return out;
    }

    // Les figures avaient déjà quitté les fiches : une image recadrée d'un scan était
    // décorative et souvent illisible. La légende, elle, disait quelque chose.
    case "figure": {
      const caption = cleanText(record.caption ?? record.text ?? record.title);
      if (caption.length < 4) return [];
      return [{ type: "paragraph", text: caption }];
    }

    default:
      return [];
  }
}

/** Les points d'une liste, nettoyés et bornés. */
function itemsOf(raw: unknown): string[] {
  return (Array.isArray(raw) ? raw : [])
    .map(cellText)
    .filter((item) => item.length > 0)
    .slice(0, SHEET_LIMITS.listItems);
}

function textsOf(block: SheetBlock): string[] {
  switch (block.type) {
    case "heading":
    case "paragraph":
      return [block.text];
    case "list":
      return block.items;
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
    case "paragraph":
      return { ...block, text: strip(block.text) };
    case "list":
      return { ...block, items: block.items.map(strip) };
    default:
      return block;
  }
}

/** Retire le balisage en ligne : c'est la version qui part au modèle pour les cartes. */
export function stripInlineMarkup(text: string): string {
  return text
    // La couleur d'un surligneur s'écrit à l'ouverture de la marque - `==menthe|texte==` -
    // et n'appartient qu'au rendu. Sans cette ligne, le modèle recevrait « menthe|texte »
    // et le nom de la couleur se réviserait avec le cours.
    .replace(new RegExp(`==(?:${SHEET_HIGHLIGHTS.join("|")})\\|`, "gi"), "")
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
        lines.push(stripInlineMarkup(block.text));
        break;

      case "list":
        block.items.forEach((item, index) =>
          lines.push(block.ordered ? `${index + 1}. ${stripInlineMarkup(item)}` : stripInlineMarkup(item))
        );
        break;

      case "formula":
        lines.push(
          block.caption ? `${block.latex} (${stripInlineMarkup(block.caption)})` : block.latex,
        );
        break;
    }
  }

  return lines.filter((line) => line.length > 0).join("\n");
}

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
