import { latexCommandsToUnicode, parseInlineMarkup } from "@micabo/core";

import { MathInline } from "./Math";

/**
 * Le balisage en ligne d'une fiche, rendu.
 *
 * Quatre marques et pas une de plus, exactement comme sur l'iPhone. Le surlignage est une
 * **bande jaune** : elle l'a été, puis a laissé place à de l'encre bleue parce qu'un fond de
 * texte se battait avec l'interligne, et elle est revenue parce que du texte bleu au milieu
 * d'un paragraphe se lit comme un lien. L'épaisseur de la bande est tenue en `em` par
 * `.sheet-marker`, ce qui règle le défaut d'origine.
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
          span.highlighted ? "sheet-marker" : "",
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
