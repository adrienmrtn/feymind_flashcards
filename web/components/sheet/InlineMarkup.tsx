import { parseInlineMarkup } from "@micabo/core";

/**
 * Le balisage en ligne d'une fiche, rendu.
 *
 * Quatre marques et pas une de plus, exactement comme sur l'iPhone. Le point qui compte est ce
 * que **le surlignage ne fait pas** : ce n'est pas un fond, c'est l'encre qui change. Un fond
 * posé derrière le texte débordait sous les jambages, changeait d'épaisseur d'une ligne à
 * l'autre, et se battait avec l'interligne au lieu de servir la lecture.
 *
 * Une formule garde son LaTeX brut. Ici elle est composée en famille monospace, faute de
 * mieux : le vrai rendu mathématique arrive avec la fiche complète, à l'étape 4. Écrire
 * « bientôt » dans la page serait pire que de montrer l'expression telle qu'elle est.
 */
export function InlineMarkup({ text }: { text: string }) {
  return (
    <>
      {parseInlineMarkup(text).map((span, index) => {
        if (span.math) {
          return (
            <span key={index} className="font-mono text-[0.95em] text-ink">
              {span.text}
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

        if (!className) return <span key={index}>{span.text}</span>;

        return (
          <span key={index} className={className}>
            {span.text}
          </span>
        );
      })}
    </>
  );
}
