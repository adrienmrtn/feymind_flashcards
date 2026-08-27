import { latexToUnicode, type SheetBlock } from "@micabo/core";

import { InlineMarkup } from "./InlineMarkup";

/**
 * Le rendu d'une fiche, porté depuis `Micabo/Features/Course/SheetBlockView.swift`.
 *
 * La règle de composition tient en une phrase : **le texte est posé à même le papier, les
 * objets sont dans des blocs.** Un paragraphe et un titre reposent sur l'ivoire, comme sur une
 * page ; une définition, un encadré, une suite d'étapes, un tableau, un graphe et une formule
 * sont des objets et prennent une surface. C'est ce qui donne le rythme d'une fiche écrite à la
 * main plutôt qu'une pile de cartes.
 *
 * Et **l'espace qui précède un titre est ce qui donne le plan** — pas un filet, pas une
 * couleur. Un titre de sous-partie a la taille du corps ; c'est l'air au-dessus de lui qui dit
 * qu'une sous-partie commence.
 */

const TONE_LABELS: Record<string, string> = {
  essentiel: "À retenir",
  attention: "Attention",
  exemple: "Exemple",
  astuce: "Astuce",
};

/**
 * Un encadré porte les couleurs de retour d'information, volontairement désaturées, et quatre
 * teintes qui se distinguent : le menthe de ce que la fiche met en avant, l'ambre de ce qui
 * coûte des points, le gris d'un exemple, le bleu d'un moyen de retenir.
 */
const TONE_STYLES: Record<string, { surface: string; label: string }> = {
  essentiel: { surface: "bg-accent-soft", label: "text-ink" },
  attention: { surface: "bg-caution-soft", label: "text-caution" },
  exemple: { surface: "bg-surface-muted", label: "text-ink-secondary" },
  astuce: { surface: "bg-info-soft", label: "text-info" },
};

function toneOf(raw: string) {
  return TONE_STYLES[raw] ? raw : "essentiel";
}

/** L'air au-dessus d'un bloc. C'est lui qui fait lire un plan. */
function spacingBefore(block: SheetBlock, isFirst: boolean): string {
  if (isFirst) return "";
  if (block.type === "heading") return block.level === 1 ? "mt-9" : "mt-7";
  return "mt-[11px]";
}

export function SheetBlocks({
  blocks,
  tint = "var(--color-accent)",
}: {
  blocks: SheetBlock[];
  /** Teinte du cours : elle ne sert qu'aux filets et aux accents de la fiche. */
  tint?: string;
}) {
  return (
    <div className="text-ink-reading">
      {blocks.map((block, index) => (
        <div key={index} className={spacingBefore(block, index === 0)} data-print="keep">
          <Block block={block} tint={tint} />
        </div>
      ))}
    </div>
  );
}

function Block({ block, tint }: { block: SheetBlock; tint: string }) {
  switch (block.type) {
    case "heading":
      return block.level === 1 ? (
        <div>
          <span
            aria-hidden
            className="mb-[7px] block h-[3px] w-[26px] rounded-pill"
            style={{ backgroundColor: tint }}
          />
          <h3 className="text-[19.8px] font-bold leading-snug text-ink">
            <InlineMarkup text={block.text} />
          </h3>
        </div>
      ) : (
        <h4 className="text-[14.85px] font-semibold leading-snug text-ink">
          <InlineMarkup text={block.text} />
        </h4>
      );

    case "paragraph":
      return (
        <p className="text-[14.85px] leading-[1.72]">
          <InlineMarkup text={block.text} />
        </p>
      );

    case "definition":
      return (
        <div className="paper flex gap-[13px] rounded-[18px] bg-surface p-[13px]">
          {/* Le filet court sur toute la hauteur du bloc : c'est ce qui distingue une
              définition d'un paragraphe indenté. */}
          <span
            aria-hidden
            className="w-[3px] shrink-0 rounded-pill"
            style={{ backgroundColor: tint, opacity: 0.55 }}
          />
          <div>
            <p className="text-[14.5px] font-semibold" style={{ color: tint }}>
              <InlineMarkup text={block.term} />
            </p>
            <p className="mt-1 text-[14px] leading-[1.6]">
              <InlineMarkup text={block.text} />
            </p>
          </div>
        </div>
      );

    case "callout": {
      const tone = toneOf(block.tone);
      const style = TONE_STYLES[tone]!;
      return (
        <div className={`rounded-[18px] p-[13px] ${style.surface}`}>
          <p className={`eyebrow ${style.label}`}>{TONE_LABELS[tone]}</p>
          <p className="mt-1.5 text-[14px] leading-[1.6]">
            <InlineMarkup text={block.text} />
          </p>
        </div>
      );
    }

    case "steps":
      return (
        <div className="paper rounded-[18px] bg-surface p-[13px]">
          {block.title ? (
            <p className="mb-2.5 text-[14.5px] font-semibold text-ink">
              <InlineMarkup text={block.title} />
            </p>
          ) : null}
          <ol className="space-y-2">
            {block.items.map((item, index) => (
              <li key={index} className="flex gap-2.5">
                <span
                  aria-hidden
                  className="numeral mt-px flex h-[19px] w-[19px] shrink-0 items-center justify-center rounded-full text-[11px] font-bold"
                  style={{ backgroundColor: `${tint}1f`, color: tint }}
                >
                  {index + 1}
                </span>
                <span className="text-[14px] leading-[1.6]">
                  <InlineMarkup text={item} />
                </span>
              </li>
            ))}
          </ol>
        </div>
      );

    case "table":
      return (
        <div>
          {block.title ? (
            <p className="mb-1.5 text-[14.5px] font-semibold text-ink">
              <InlineMarkup text={block.title} />
            </p>
          ) : null}
          <div className="paper overflow-hidden rounded-[18px] bg-surface">
            <table className="w-full table-fixed text-left text-[12px]">
              <thead>
                <tr style={{ backgroundColor: `${tint}14` }}>
                  {block.headers.map((header, index) => (
                    <th key={index} className="px-[11px] py-2 font-semibold text-ink">
                      <InlineMarkup text={header} />
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {block.rows.map((row, rowIndex) => (
                  <tr key={rowIndex} className="border-t border-hairline">
                    {row.map((cell, cellIndex) => (
                      <td
                        key={cellIndex}
                        className={`px-[11px] py-[9px] align-top ${
                          cellIndex === 0 ? "font-medium text-ink" : ""
                        }`}
                      >
                        <InlineMarkup text={cell} />
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {block.caption ? (
            <p className="mt-1.5 px-0.5 text-[11.5px] text-ink-tertiary">
              <InlineMarkup text={block.caption} />
            </p>
          ) : null}
        </div>
      );

    case "chart": {
      // Une échelle, des valeurs écrites en clair, et rien d'autre : pas d'axes, pas de grille,
      // pas de légende séparée. Un graphe de fiche sert à voir un ordre de grandeur.
      const maximum = Math.max(...block.bars.map((bar) => bar.value), 0.0001);
      return (
        <div className="paper rounded-[18px] bg-surface p-[13px]">
          {block.title ? (
            <p className="mb-2.5 text-[14.5px] font-semibold text-ink">
              <InlineMarkup text={block.title} />
            </p>
          ) : null}
          <div className="space-y-[9px]">
            {block.bars.map((bar, index) => (
              <div key={index}>
                <div className="flex items-baseline gap-2">
                  <span className="text-[12px] font-medium text-ink">
                    <InlineMarkup text={bar.label} />
                  </span>
                  <span className="numeral text-[12px] font-semibold text-ink-secondary">
                    {formatBarValue(bar.value, block.unit)}
                  </span>
                </div>
                <div className="mt-1 h-[7px] overflow-hidden rounded-pill bg-surface-sunken/55">
                  <div
                    className="h-full rounded-pill"
                    style={{
                      width: `${Math.max(3, (bar.value / maximum) * 100)}%`,
                      backgroundColor: tint,
                      opacity: 0.85,
                    }}
                  />
                </div>
              </div>
            ))}
          </div>
          {block.caption ? (
            <p className="mt-2.5 text-[11.5px] text-ink-tertiary">
              <InlineMarkup text={block.caption} />
            </p>
          ) : null}
        </div>
      );
    }

    case "formula":
      return (
        <div className="rounded-[18px] bg-surface-muted px-[13px] py-4 text-center">
          <p className="font-serif text-[18px] italic text-ink">{latexToUnicode(block.latex)}</p>
          {block.caption ? (
            <p className="mt-1.5 text-[11.5px] text-ink-tertiary">
              <InlineMarkup text={block.caption} />
            </p>
          ) : null}
        </div>
      );
  }
}

/** Un entier reste un entier, et le pourcentage reste collé à son nombre. */
function formatBarValue(value: number, unit?: string): string {
  const number = Number.isInteger(value) ? String(value) : value.toFixed(1).replace(".", ",");
  if (!unit) return number;
  return unit === "%" ? `${number}${unit}` : `${number} ${unit}`;
}
