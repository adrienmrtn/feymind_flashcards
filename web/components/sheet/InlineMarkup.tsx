import { latexCommandsToUnicode, parseInlineMarkup } from "@micabo/core";

import { MathInline } from "./Math";

/**
 * Le balisage en ligne d'une fiche, rendu.
 *
 * Quatre marques et pas une de plus, exactement comme sur l'iPhone. Le point qui compte est ce
 * que **le surlignage ne fait pas** : ce n'est pas un fond, c'est l'encre qui change. Un fond
 * posé derrière le texte débordait sous les jambages, changeait d'épaisseur d'une ligne à
 * l'autre, et se battait avec l'interligne au lieu de servir la lecture.
 *
 * Un fragment `$…$` est **composé** par KaTeX (voir `lib/math/typeset`), et retombe sur la
 * transposition Unicode d'avant si le LaTeX est incomplet. Le texte hors `$…$` ne convertit
 * que les commandes, pour ne pas transformer un `_` de phrase en indice.
 */
export function InlineMarkup({ text }: { text: string }) {
  return (
    <>
      {parseInlineMarkup(text).map((span, index) => {
        if (span.math) return <MathInline key={index} latex={span.text} />;

        const rendered = latexCommandsToUnicode(span.text);

        const className = [
          span.bold ? "font-semibold text-ink" : "",
          span.italic ? "italic" : "",
          span.highlighted ? "font-medium text-sheet-emphasis" : "",
        ]
          .filter(Boolean)
          .join(" ");

        if (!className) return <span key={index}>{rendered}</span>;

        return (
          <span key={index} className={className}>
            {rendered}
          </span>
        );
      })}
    </>
  );
}
