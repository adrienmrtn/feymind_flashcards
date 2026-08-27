import { latexCommandsToUnicode } from "@micabo/core";

import { OcclusionFigure } from "@/components/app/OcclusionFigure";
import { InlineMarkup } from "@/components/sheet/InlineMarkup";
import type { SharedCard } from "@/lib/data/social";

/**
 * Les cartes d'un cours partagé, en lecture.
 *
 * On les voit telles qu'elles sont écrites, sans l'état de répétition de l'auteur.
 * Les reprendre les copie neuves dans son propre paquet.
 */
export function SharedCardsPreview({ cards }: { cards: SharedCard[] }) {
  if (cards.length === 0) {
    return (
      <p className="rounded-group bg-surface-muted px-5 py-4 text-[14px] text-ink-secondary">
        Ce cours n&apos;a pas encore de cartes.
      </p>
    );
  }

  return (
    <section>
      <p className="eyebrow text-ink-tertiary">🃏 {cards.length} carte{cards.length > 1 ? "s" : ""}</p>
      <div className="paper mt-3 overflow-hidden rounded-group bg-surface">
        {cards.map((card, index) => {
          const occlusion =
            card.kind === "occlusion" && Boolean(card.image_path) && card.mask_width > 0;
          return (
            <div
              key={card.id}
              className={`px-5 py-4 ${index > 0 ? "border-t border-hairline" : ""}`}
            >
              {occlusion && card.image_path ? (
                <div className="mb-3">
                  <OcclusionFigure
                    image={card.image_path}
                    mask={{
                      x: card.mask_x,
                      y: card.mask_y,
                      width: card.mask_width,
                      height: card.mask_height,
                    }}
                    revealed
                  />
                </div>
              ) : null}
              <p className="text-[15px] font-medium leading-snug text-ink">
                <InlineMarkup text={occlusion ? card.back : card.front} />
              </p>
              {occlusion ? (
                <p className="mt-1.5 text-[12.5px] text-ink-tertiary">Schéma</p>
              ) : (
                <p className="mt-1 text-[14px] leading-snug text-ink-secondary">
                  <InlineMarkup text={card.back} />
                </p>
              )}
              {card.choices.length > 0 ? (
                <p className="mt-1.5 text-[12.5px] text-ink-tertiary">
                  {card.choices.map((choice) => latexCommandsToUnicode(choice)).join(" · ")}
                </p>
              ) : null}
            </div>
          );
        })}
      </div>
    </section>
  );
}
