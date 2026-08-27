import { latexCommandsToUnicode, latexToUnicode, parseInlineMarkup } from "@micabo/core";

/**
 * Le balisage en ligne d'une fiche, rendu.
 *
 * Quatre marques et pas une de plus, exactement comme sur l'iPhone. Le point qui compte est ce
 * que **le surlignage ne fait pas** : ce n'est pas un fond, c'est l'encre qui change. Un fond
 * posé derrière le texte débordait sous les jambages, changeait d'épaisseur d'une ligne à
 * l'autre, et se battait avec l'interligne au lieu de servir la lecture.
 *
 * Une formule est transposée en Unicode, comme sur l'iPhone : pas de moteur LaTeX,
 * mais `\rightarrow` ne reste plus écrit en clair. Le texte hors `$…$` ne convertit
 * que les commandes, pour ne pas transformer un `_` de phrase en indice.
 */
export function InlineMarkup({ text }: { text: string }) {
  return (
    <>
      {parseInlineMarkup(text).map((span, index) => {
        const rendered = span.math ? latexToUnicode(span.text) : latexCommandsToUnicode(span.text);

        if (span.math) {
          return (
            <span key={index} className="font-serif text-[0.95em] italic text-ink">
              {rendered}
            </span>
          );
        }

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
