import { Fragment } from "react";

import { MathInline } from "@/components/sheet/Math";

/**
 * **Un texte des notes** : les mots-clés (`**mot**`) en gras violet, les formules en ligne
 * (`$…$`) composées par KaTeX, sans leurs dollars. Jumeau de `KeywordText` côté Swift.
 *
 * C'est aussi le rendu de tout texte écrit par le modèle (question, proposition, « pourquoi »,
 * carte) : un texte nu y montrerait `$x^2$` tel quel. `tints` à faux garde le gras sans le
 * violet, là où la couleur du texte dit déjà autre chose (une réponse juste, une pastille
 * choisie).
 */
export function KeywordText({ text, tints = true, className }: { text: string; tints?: boolean; className?: string }) {
  const parts = text.split("**");
  const content = parts.map((part, index) => {
    if (!part) return null;
    const keyword = index % 2 === 1;
    const inner = withMath(part);
    return keyword ? (
      <strong key={index} className={tints ? "font-bold text-keyword" : "font-bold"}>
        {inner}
      </strong>
    ) : (
      <Fragment key={index}>{inner}</Fragment>
    );
  });
  return className ? <span className={className}>{content}</span> : <>{content}</>;
}

const MATH = /\$([^$\n]+)\$/g;

function withMath(text: string): React.ReactNode {
  if (!text.includes("$")) return text;
  const nodes: React.ReactNode[] = [];
  let last = 0;
  for (const match of text.matchAll(MATH)) {
    const start = match.index;
    if (start > last) nodes.push(text.slice(last, start));
    nodes.push(<MathInline key={start} latex={match[1]!} />);
    last = start + match[0].length;
  }
  if (last < text.length) nodes.push(text.slice(last));
  return nodes.length === 1 ? nodes[0] : nodes.map((node, index) => <Fragment key={index}>{node}</Fragment>);
}

/** Le même texte à plat : mots-clés sans leurs astérisques, formules sans leurs dollars. */
export function plainKeywordText(text: string): string {
  return text.replaceAll("**", "").replace(MATH, "$1");
}
