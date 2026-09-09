"use client";

import { type SheetBlock } from "@micabo/core";

import { readingStyle } from "@/lib/sheet/reading-size";
import { useReadingSize } from "@/lib/sheet/use-reading-size";

import { InlineMarkup } from "./InlineMarkup";
import { MathBlock } from "./Math";

/**
 * Le rendu **figé** d'une fiche : la fin verrouillée, l'impression, un cours partagé.
 *
 * La fiche qu'on lit sur son propre cours n'est plus rendue ici : elle est un document
 * modifiable (`SheetDocument`), et deux rendus du même contenu finiraient par se contredire.
 * Ce composant sert aux endroits où l'on **regarde sans écrire**, et il compose exactement les
 * mêmes quatre blocs, avec les mêmes tailles - c'est ce qui fait qu'on ne voit pas la couture
 * entre la partie lisible et la partie floutée d'une fiche verrouillée.
 *
 * Il en portait neuf, dont sept objets encartés : définitions, encadrés de ton, étapes,
 * tableaux, graphes, figures. Ils sont partis avec le format ; ce qu'ils disaient s'écrit
 * maintenant dans le texte.
 */
export function SheetBlocks({ blocks }: { blocks: readonly SheetBlock[] }) {
  // La taille de lecture est celle de l'appareil, pas celle de la fiche : une fiche
  // verrouillée, un cours partagé et le document qu'on écrit doivent grossir ensemble,
  // sinon la couture entre les deux moitiés d'une même page se voit.
  const [size] = useReadingSize();

  return (
    <div className="sheet-doc text-ink-reading" style={readingStyle(size)}>
      {blocks.map((block, index) => (
        <Block key={index} block={block} />
      ))}
    </div>
  );
}

function Block({ block }: { block: SheetBlock }) {
  switch (block.type) {
    case "heading":
      return block.level === 1 ? (
        <h1 data-print="keep">
          <InlineMarkup text={block.text} />
        </h1>
      ) : (
        <h2 data-print="keep">
          <InlineMarkup text={block.text} />
        </h2>
      );

    case "paragraph":
      return (
        <p data-print="keep">
          <InlineMarkup text={block.text} />
        </p>
      );

    case "list":
      return block.ordered ? (
        <ol data-print="keep">
          {block.items.map((item, index) => (
            <li key={index}>
              <InlineMarkup text={item} />
            </li>
          ))}
        </ol>
      ) : (
        <ul data-print="keep">
          {block.items.map((item, index) => (
            <li key={index}>
              <InlineMarkup text={item} />
            </li>
          ))}
        </ul>
      );

    case "formula":
      return (
        <div className="rounded-group bg-surface-muted px-5 py-4" data-print="keep">
          <MathBlock latex={block.latex} />
          {block.caption ? (
            <p className="mt-2 text-[13px] text-ink-tertiary">
              <InlineMarkup text={block.caption} />
            </p>
          ) : null}
        </div>
      );
  }
}
