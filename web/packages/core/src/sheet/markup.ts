/**
 * Le balisage en ligne d'une fiche, porté depuis `Micabo/Services/SheetMarkup.swift`.
 *
 * Quatre marques, pas une de plus, et chacune a une raison d'exister sur une fiche :
 *
 * | Écriture | Rendu | À quoi ça sert |
 * | --- | --- | --- |
 * | `**terme**` | gras | le mot que l'examen attend |
 * | `*nuance*` | italique | une réserve, un mot étranger, un titre d'œuvre |
 * | `==l'essentiel==` | surligné | ce qu'on relit la veille, et rien d'autre |
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

export interface MarkupSpan {
  text: string;
  bold: boolean;
  italic: boolean;
  highlighted: boolean;
  /** Fragment mathématique. `text` porte le LaTeX brut, sans ses `$`. */
  math: boolean;
}

const BOLD = "**";
const HIGHLIGHT = "==";
const ITALIC = "*";
const MATH = "$";

/** Découpe un texte balisé en fragments homogènes. */
export function parseInlineMarkup(source: string): MarkupSpan[] {
  const characters = Array.from(source);
  const spans: MarkupSpan[] = [];

  let buffer = "";
  let bold = false;
  let italic = false;
  let highlighted = false;
  let index = 0;

  const flush = () => {
    if (buffer.length === 0) return;
    spans.push({ text: buffer, bold, italic, highlighted, math: false });
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
          spans.push({ text: latex, bold, italic, highlighted, math: true });
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
      if (highlighted) {
        flush();
        highlighted = false;
        index += HIGHLIGHT.length;
        continue;
      }
      if (nextIndex(HIGHLIGHT, characters, index + HIGHLIGHT.length) !== null) {
        flush();
        highlighted = true;
        index += HIGHLIGHT.length;
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

/** Vrai si le texte porte au moins une marque exploitable. */
export function containsInlineMarkup(source: string): boolean {
  return parseInlineMarkup(source).some(
    (span) => span.bold || span.italic || span.highlighted || span.math,
  );
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
