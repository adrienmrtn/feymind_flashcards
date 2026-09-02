import katex from "katex";

import { latexToUnicode } from "@micabo/core";

/**
 * La composition des écritures scientifiques, sur le web.
 *
 * Jusqu'ici Micabo n'avait pas de moteur : les fragments `$…$` étaient
 * **transposés en Unicode** (`x^2` devenait `x²`, `\frac{a}{b}` devenait
 * `a/b`). C'est lisible pour trois symboles, et ça ne l'est plus dès qu'une
 * fraction en contient une autre, qu'une intégrale porte ses bornes, ou qu'une
 * matrice apparaît. `(a + b)/(c + d)` n'est pas une fraction, c'est sa
 * description.
 *
 * KaTeX compose donc pour de vrai, et **la transposition reste le plancher**.
 * Ce n'est pas de la prudence de façade : une fiche est écrite par un modèle,
 * donc du LaTeX incomplet ou inventé arrive forcément un jour. Le choix est
 * entre une page qui casse et une formule un peu moins belle.
 *
 * ## Ce que ça coûte
 *
 * KaTeX est appelé côté serveur pour les fiches, et il part dans le paquet du
 * navigateur pour les écrans qui composent une carte pendant une session. Une
 * centaine de kilooctets compressés, sur une app dont le contenu est
 * précisément scientifique. Le rendu, lui, ne coûte rien à l'affichage : c'est
 * du HTML et du CSS, pas de mise en page au chargement, donc pas de saut.
 *
 * ## Deux garde-fous
 *
 * `trust` reste à faux, donc `\href`, `\url` et `\includegraphics` sont
 * refusés : ce texte vient d'un modèle et transite par une base, il n'a pas à
 * pouvoir écrire un lien dans la page. `strict` est à faux pour l'inverse :
 * un accent dans un `\text{}` ne doit pas faire échouer la formule entière.
 */

export type Typeset =
  /** Composé par KaTeX. `html` contient aussi le MathML que lisent les lecteurs d'écran. */
  | { kind: "typeset"; html: string }
  /** Le plancher : transposé en Unicode, à afficher comme du texte. */
  | { kind: "transposed"; text: string };

export function typesetMath(latex: string, options: { display?: boolean } = {}): Typeset {
  const source = latex.trim();
  if (source.length === 0) return { kind: "transposed", text: "" };

  try {
    return {
      kind: "typeset",
      html: katex.renderToString(source, {
        displayMode: Boolean(options.display),
        // On veut l'échec, pour pouvoir retomber sur la transposition. Sans ça
        // KaTeX écrit la source en rouge dans la page, ce qui est pire que
        // « x² » : ça a l'air d'un bug du produit.
        throwOnError: true,
        strict: false,
        trust: false,
        output: "htmlAndMathml",
      }),
    };
  } catch {
    return { kind: "transposed", text: latexToUnicode(source) };
  }
}

/**
 * Vrai si KaTeX sait composer ce fragment.
 *
 * Sert aux tests et aux décisions de mise en page, jamais au rendu : pour
 * afficher, `typesetMath` donne déjà la réponse et le résultat en une passe.
 */
export function canTypeset(latex: string): boolean {
  return typesetMath(latex).kind === "typeset";
}
