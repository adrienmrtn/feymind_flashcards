import {
  DEFAULT_HIGHLIGHT,
  SHEET_HIGHLIGHTS,
  SHEET_TEXT_SIZES,
  normalizeSheet,
  parseInlineMarkup,
  toInlineMarkup,
  type MarkupSpan,
  type SheetBlock,
  type SheetHighlight,
  type SheetTextSize,
} from "@micabo/core";

/**
 * La fiche, dans les deux sens : des blocs vers le document, et du document vers les blocs.
 *
 * C'est le pivot de la fiche modifiable. La fiche se **range** en blocs - c'est ce que le
 * modèle écrit, ce que l'iPhone lit et ce que la mise à plat dépouille pour écrire les cartes
 * - mais elle se **modifie** dans un document, parce qu'un document est ce que tout le monde
 * sait manipuler. Les deux conversions vivent donc ici, ensemble : les séparer, c'est le jour
 * où l'aller n'écrit plus ce que le retour sait lire.
 *
 * Le retour ne fait confiance à rien. Il lit un arbre que l'utilisateur a pu remplir en
 * collant du Word, du HTML d'une page web ou trois niveaux de listes imbriquées ; il n'en
 * garde que ce que le vocabulaire connaît, et `normalizeSheet` repasse derrière. Une fiche
 * enregistrée est une fiche que le modèle aurait pu écrire.
 */

/** Ce qu'un nœud doit savoir faire pour être lu. Le DOM le sait ; un objet de test aussi. */
export interface NodeLike {
  nodeType: number;
  nodeName: string;
  textContent: string | null;
  childNodes: ArrayLike<NodeLike>;
  getAttribute?: (name: string) => string | null;
}

const ELEMENT = 1;
const TEXT = 3;

// MARK: - Des blocs vers le document

export function blocksToHtml(blocks: readonly SheetBlock[]): string {
  return blocks.map(blockToHtml).join("");
}

function blockToHtml(block: SheetBlock): string {
  switch (block.type) {
    case "heading": {
      const tag = block.level === 1 ? "h1" : "h2";
      return `<${tag}>${inlineToHtml(block.text)}</${tag}>`;
    }
    case "paragraph":
      return `<p>${inlineToHtml(block.text)}</p>`;
    case "list": {
      const tag = block.ordered ? "ol" : "ul";
      const items = block.items.map((item) => `<li>${inlineToHtml(item)}</li>`).join("");
      return `<${tag}>${items}</${tag}>`;
    }
    case "formula":
      // Le bloc est fermé à l'écriture libre : une formule se corrige par son LaTeX, pas en
      // tapant au milieu des symboles composés.
      return `<div data-formula="" data-latex="${escapeAttribute(block.latex)}" data-caption="${escapeAttribute(block.caption ?? "")}" contenteditable="false"></div>`;
  }
}

function inlineToHtml(text: string): string {
  const html = parseInlineMarkup(text)
    .map((span) => {
      // `contenteditable="false"` : une formule en ligne est **composée**, donc on ne tape
      // pas dedans - on la rouvre dans son éditeur. Sans ça le curseur se pose au milieu des
      // symboles rendus et la frappe suivante détruit le LaTeX sans que rien ne le dise.
      if (span.math) {
        return `<span data-math="${escapeAttribute(span.text)}" contenteditable="false">${escapeText(span.text)}</span>`;
      }
      let out = escapeText(span.text);
      // La taille est portée par un attribut, pas par une classe : c'est elle qu'on relit à
      // l'enregistrement, et une classe se perd au premier collage depuis un autre document.
      if (span.size) out = `<span data-size="${span.size}">${out}</span>`;
      if (span.highlight) out = `<mark data-hl="${span.highlight}">${out}</mark>`;
      if (span.strike) out = `<s>${out}</s>`;
      if (span.italic) out = `<em>${out}</em>`;
      if (span.bold) out = `<strong>${out}</strong>`;
      return out;
    })
    .join("");
  // Un bloc vide n'a pas de hauteur dans un document modifiable : on ne pourrait plus y poser
  // le curseur, donc plus jamais le remplir.
  return html.length > 0 ? html : "<br>";
}

function escapeText(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function escapeAttribute(value: string): string {
  return escapeText(value).replace(/"/g, "&quot;");
}

// MARK: - Du document vers les blocs

export function htmlToBlocks(root: NodeLike): SheetBlock[] {
  const drafted: SheetBlock[] = [];

  for (let index = 0; index < root.childNodes.length; index += 1) {
    const node = root.childNodes[index]!;
    if (node.nodeType !== ELEMENT) {
      // Du texte posé à la racine : c'est ce que produit un collage brut. Il devient un
      // paragraphe plutôt que de disparaître.
      const loose = (node.textContent ?? "").trim();
      if (loose.length > 0) drafted.push({ type: "paragraph", text: loose });
      continue;
    }
    drafted.push(...elementToBlocks(node));
  }

  return normalizeSheet(drafted);
}

function elementToBlocks(node: NodeLike): SheetBlock[] {
  const name = node.nodeName.toLowerCase();

  if (name === "div" && node.getAttribute?.("data-formula") !== null && node.getAttribute) {
    const latex = (node.getAttribute("data-latex") ?? "").trim();
    if (latex.length === 0) return [];
    const caption = (node.getAttribute("data-caption") ?? "").trim();
    return [{ type: "formula", latex, caption: caption.length > 0 ? caption : undefined }];
  }

  if (name === "h1" || name === "h2" || name === "h3") {
    const text = readInline(node);
    if (text.length === 0) return [];
    return [{ type: "heading", level: name === "h1" ? 1 : 2, text }];
  }

  if (name === "ul" || name === "ol") {
    const items: string[] = [];
    for (let index = 0; index < node.childNodes.length; index += 1) {
      const child = node.childNodes[index]!;
      if (child.nodeType !== ELEMENT || child.nodeName.toLowerCase() !== "li") continue;
      const text = readInline(child);
      if (text.length > 0) items.push(text);
    }
    if (items.length === 0) return [];
    return [{ type: "list", ordered: name === "ol", items }];
  }

  // Tout le reste - p, div collé, blockquote - devient un paragraphe. Un document en garde
  // le texte ; le vocabulaire de la fiche, lui, ne s'étend pas parce qu'on a collé du Word.
  const text = readInline(node);
  if (text.length === 0) return [];
  return [{ type: "paragraph", text }];
}

/** Le contenu d'un élément, ramené au texte balisé de la fiche. */
export function readInline(node: NodeLike): string {
  const spans: MarkupSpan[] = [];
  collect(node, { bold: false, italic: false, strike: false, highlight: null, size: null }, spans);
  return toInlineMarkup(spans).trim();
}

interface Marks {
  bold: boolean;
  italic: boolean;
  strike: boolean;
  highlight: SheetHighlight | null;
  size: SheetTextSize | null;
}

function collect(node: NodeLike, marks: Marks, out: MarkupSpan[]): void {
  for (let index = 0; index < node.childNodes.length; index += 1) {
    const child = node.childNodes[index]!;

    if (child.nodeType === TEXT) {
      const text = child.textContent ?? "";
      if (text.length === 0) continue;
      out.push({
        text,
        bold: marks.bold,
        italic: marks.italic,
        strike: marks.strike,
        highlighted: marks.highlight !== null,
        highlight: marks.highlight,
        size: marks.size,
        math: false,
      });
      continue;
    }

    if (child.nodeType !== ELEMENT) continue;

    const name = child.nodeName.toLowerCase();

    // Une formule en ligne est opaque : on reprend son LaTeX, pas le texte composé.
    const math = child.getAttribute?.("data-math");
    if (math) {
      out.push({
        text: math,
        bold: marks.bold,
        italic: marks.italic,
        strike: marks.strike,
        highlighted: marks.highlight !== null,
        highlight: marks.highlight,
        size: marks.size,
        math: true,
      });
      continue;
    }

    if (name === "br") {
      out.push({
        text: " ",
        bold: false,
        italic: false,
        strike: false,
        highlighted: false,
        highlight: null,
        size: null,
        math: false,
      });
      continue;
    }

    collect(child, {
      bold: marks.bold || name === "strong" || name === "b",
      italic: marks.italic || name === "em" || name === "i",
      // `del` et `strike` viennent d'un collage : un document externe barre comme il veut.
      strike: marks.strike || name === "s" || name === "del" || name === "strike",
      highlight: name === "mark" ? highlightOf(child.getAttribute?.("data-hl")) : marks.highlight,
      size: sizeOf(child.getAttribute?.("data-size")) ?? marks.size,
    }, out);
  }
}

/** La taille portée par un `span[data-size]`, ou rien si ce n'en est pas un. */
function sizeOf(raw: string | null | undefined): SheetTextSize | null {
  const value = (raw ?? "").trim().toLowerCase();
  return SHEET_TEXT_SIZES.find((item) => item === value) ?? null;
}

function highlightOf(raw: string | null | undefined): SheetHighlight {
  const found = SHEET_HIGHLIGHTS.find((item) => item === (raw ?? "").trim().toLowerCase());
  return found ?? DEFAULT_HIGHLIGHT;
}
