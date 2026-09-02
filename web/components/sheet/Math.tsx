import "katex/dist/katex.min.css";

import { typesetMath } from "@/lib/math/typeset";

/**
 * Une formule dans une phrase.
 *
 * Composée par KaTeX quand c'est possible, transposée en Unicode sinon. Le
 * repli garde l'italique à empattements d'avant, parce qu'une formule doit se
 * distinguer de la phrase qui l'entoure même quand le moteur a renoncé.
 *
 * Le `dangerouslySetInnerHTML` n'est pas une entorse : KaTeX échappe ce qu'il
 * reçoit et, avec `trust: false`, n'émet ni lien ni balise arbitraire. Ce
 * qu'il rend est un arbre de `span` et un bloc MathML, et c'est ce MathML que
 * lisent les lecteurs d'écran, donc la formule est aussi dite qu'affichée.
 */
export function MathInline({ latex }: { latex: string }) {
  const out = typesetMath(latex);

  if (out.kind === "transposed") {
    return <span className="font-serif text-[0.95em] italic text-ink">{out.text}</span>;
  }

  return <span className="math-inline" dangerouslySetInnerHTML={{ __html: out.html }} />;
}

/**
 * Une formule posée seule, centrée, c'est-à-dire le bloc `formula` d'une fiche.
 *
 * En mode display : les bornes d'une somme passent au-dessus et en dessous du
 * signe, une fraction prend sa vraie hauteur. C'est là que la composition
 * change tout, et c'est pour ça que ce bloc existe séparément dans les fiches.
 */
export function MathBlock({ latex }: { latex: string }) {
  const out = typesetMath(latex, { display: true });

  if (out.kind === "transposed") {
    return <p className="font-serif text-[18px] italic text-ink">{out.text}</p>;
  }

  return <div className="math-block" dangerouslySetInnerHTML={{ __html: out.html }} />;
}
