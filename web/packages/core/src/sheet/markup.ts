/**
 * Le balisage en ligne d'une fiche, porté depuis `Micabo/Services/SheetMarkup.swift`.
 *
 * Quatre marques, pas une de plus, et chacune a une raison d'exister sur une fiche :
 *
 * | Écriture | Rendu | À quoi ça sert |
 * | --- | --- | --- |
 * | `**terme**` | gras | le mot que l'examen attend |
 * | `*nuance*` | italique | une réserve, un mot étranger, un titre d'œuvre |
 * | `==l'essentiel==` | surligné en jaune | ce qu'on relit la veille, et rien d'autre |
 * | `==menthe\|l'essentiel==` | surligné en menthe | la même marque, dans une autre couleur |
 * | `$E = mc^2$` | formule | rendue à part |
 *
 * **Ce module sert au rendu, et à rien d'autre.** Pour obtenir le texte sans ses marques,
 * c'est `stripInlineMarkup` du module canonique qu'il faut appeler : c'est lui qui a produit
 * le `context_text` enregistré en base, et deux façons de mettre une fiche à plat finiraient
 * par se contredire. Ici, un fragment de formule garde donc son LaTeX **brut** - c'est le
 * moteur de rendu qui s'en occupe, pas le parseur.
 *
 * Un délimiteur seul ne casse rien : sans fermeture, il reste un caractère comme un autre, ce
 * qui est indispensable pour un cours de statistiques où l'astérisque veut dire
 * « significatif ».
 */

import { DEFAULT_HIGHLIGHT, SHEET_HIGHLIGHTS, type SheetHighlight } from "./canonical";

export interface MarkupSpan {
  text: string;
  bold: boolean;
  italic: boolean;
  highlighted: boolean;
  /**
   * La teinte du surlignage, quand il y en a un.
   *
   * Le code couleur d'une fiche n'appartient qu'à celui qui la relit : le modèle marque en
   * jaune ce qui compte, et l'étudiant recolore. La couleur s'écrit avant une barre verticale
   * - `==menthe|texte==` - parce que la barre ne se rencontre à peu près jamais dans un cours,
   * là où le deux-points est partout. Un nom inconnu n'est pas une couleur : le texte reste
   * tel quel, barre comprise.
   */
  highlight: SheetHighlight | null;
  /** Fragment mathématique. `text` porte le LaTeX brut, sans ses `$`. */
  math: boolean;
}

const BOLD = "**";
const HIGHLIGHT = "==";
const ITALIC = "*";
const MATH = "$";
const COLOR = "|";

/** Découpe un texte balisé en fragments homogènes. */
export function parseInlineMarkup(source: string): MarkupSpan[] {
  const characters = Array.from(source);
  const spans: MarkupSpan[] = [];

  let buffer = "";
  let bold = false;
  let italic = false;
  let highlight: SheetHighlight | null = null;
  let index = 0;

  const flush = () => {
    if (buffer.length === 0) return;
    spans.push({ text: buffer, bold, italic, highlighted: highlight !== null, highlight, math: false });
    buffer = "";
  };

  while (index < characters.length) {
    // Une formule est opaque : le balisage n'y entre pas, sinon `a^*` deviendrait de
    // l'italique au milieu d'une expression.
    if (characters[index] === MATH) {
      const close = nextIndex(MATH, characters, index + 1);
      if (close !== null) {
        const latex = characters.slice(index + 1, close).join("");
        if (latex.length > 0) {
          flush();
          spans.push({
            text: latex,
            bold,
            italic,
            highlighted: highlight !== null,
            highlight,
            math: true,
          });
        }
        index = close + 1;
        continue;
      }
    }

    if (matches(BOLD, characters, index)) {
      if (bold) {
        flush();
        bold = false;
        index += BOLD.length;
        continue;
      }
      if (nextIndex(BOLD, characters, index + BOLD.length) !== null) {
        flush();
        bold = true;
        index += BOLD.length;
        continue;
      }
    }

    if (matches(HIGHLIGHT, characters, index)) {
      if (highlight !== null) {
        flush();
        highlight = null;
        index += HIGHLIGHT.length;
        continue;
      }
      const close = nextIndex(HIGHLIGHT, characters, index + HIGHLIGHT.length);
      if (close !== null) {
        flush();
        const named = namedColor(characters, index + HIGHLIGHT.length, close);
        highlight = named?.color ?? DEFAULT_HIGHLIGHT;
        index = named ? named.start : index + HIGHLIGHT.length;
        continue;
      }
    }

    if (characters[index] === ITALIC) {
      if (italic) {
        flush();
        italic = false;
        index += 1;
        continue;
      }
      if (closingItalic(characters, index + 1) !== null) {
        flush();
        italic = true;
        index += 1;
        continue;
      }
    }

    buffer += characters[index];
    index += 1;
  }

  flush();
  return spans;
}

/**
 * La couleur écrite juste après l'ouverture d'un surlignage, s'il y en a une.
 *
 * Rend aussi l'endroit où le texte reprend, après la barre. Un nom inconnu ne rend rien : la
 * marque garde alors sa couleur par défaut et la barre reste dans le texte, ce qui est le seul
 * comportement acceptable pour un cours d'informatique où « a | b » veut dire quelque chose.
 */
function namedColor(
  characters: string[],
  from: number,
  close: number,
): { color: SheetHighlight; start: number } | null {
  const bar = characters.indexOf(COLOR, from);
  if (bar < 0 || bar >= close) return null;
  const name = characters.slice(from, bar).join("").trim().toLowerCase();
  const color = SHEET_HIGHLIGHTS.find((item) => item === name);
  return color ? { color, start: bar + 1 } : null;
}

/** Vrai si le texte porte au moins une marque exploitable. */
export function containsInlineMarkup(source: string): boolean {
  return parseInlineMarkup(source).some(
    (span) => span.bold || span.italic || span.highlighted || span.math,
  );
}

/**
 * Le chemin inverse : des fragments vers le texte balisé.
 *
 * C'est l'éditeur qui en a besoin. Il travaille sur des fragments - c'est ce qu'une sélection
 * dans un document produit - et la fiche se range en texte balisé, parce que c'est ce format
 * que le modèle écrit, que l'iPhone lit et que la mise à plat sait dépouiller.
 *
 * Les marques sont posées **fragment par fragment** et refermées à chaque fois. Regrouper les
 * fragments voisins qui partagent une marque donnerait un texte plus court d'un caractère ou
 * deux, au prix d'un état à tenir ; et un balisage mal refermé se lit ensuite comme du texte.
 */
export function toInlineMarkup(spans: readonly MarkupSpan[]): string {
  let out = "";
  for (const span of spans) {
    if (span.text.length === 0) continue;
    if (span.math) {
      out += `$${span.text}$`;
      continue;
    }
    let text = span.text;
    if (span.highlight) {
      text = span.highlight === DEFAULT_HIGHLIGHT
        ? `${HIGHLIGHT}${text}${HIGHLIGHT}`
        : `${HIGHLIGHT}${span.highlight}${COLOR}${text}${HIGHLIGHT}`;
    }
    if (span.italic) text = `${ITALIC}${text}${ITALIC}`;
    if (span.bold) text = `${BOLD}${text}${BOLD}`;
    out += text;
  }
  return out;
}

// MARK: - Balayage

function matches(needle: string, characters: string[], index: number): boolean {
  if (index + needle.length > characters.length) return false;
  for (let offset = 0; offset < needle.length; offset += 1) {
    if (characters[index + offset] !== needle[offset]) return false;
  }
  return true;
}

function nextIndex(needle: string, characters: string[], start: number): number | null {
  for (let index = start; index < characters.length; index += 1) {
    if (matches(needle, characters, index)) return index;
  }
  return null;
}

/** Fermeture d'une italique : une astérisque seule, jamais la moitié d'un `**`. */
function closingItalic(characters: string[], start: number): number | null {
  let index = start;
  while (index < characters.length) {
    if (characters[index] === ITALIC) {
      if (matches(BOLD, characters, index)) {
        index += BOLD.length;
        continue;
      }
      return index;
    }
    index += 1;
  }
  return null;
}
