import { latexCommandsToUnicode, parseInlineMarkup } from "@micabo/core";

import { MathInline } from "./Math";

/**
 * Le balisage en ligne d'une fiche, rendu.
 *
 * Cinq marques et pas une de plus, exactement comme sur l'iPhone. Le surlignage est une
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
          // Le barré est porté par une classe et non par `<s>` : il se cumule avec le gras,
          // l'italique et le surlignage, et un élément par marque ferait un arbre différent
          // selon l'ordre d'écriture.
          span.strike ? "line-through decoration-[1.5px] text-ink-tertiary" : "",
        ]
          .filter(Boolean)
          .join(" ");

        // La taille est portée par `data-size`, comme dans le document modifiable : les deux
        // rendus doivent produire le même arbre, sinon la couture se voit entre une fiche lue
        // et la même fiche ouverte à l'écriture.
        const size = span.size ?? undefined;

        // Le surlignage est un `<mark>` et non une classe : c'est l'élément que le document
        // modifiable pose et relit, pour la même raison.
        if (span.highlight) {
          return (
            <mark key={index} data-hl={span.highlight} data-size={size} className={className || undefined}>
              {rendered}
            </mark>
          );
        }

        if (!className && !size) return <span key={index}>{rendered}</span>;

        return (
          <span key={index} data-size={size} className={className || undefined}>
            {rendered}
          </span>
        );
      })}
    </>
  );
}
