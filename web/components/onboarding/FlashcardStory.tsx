"use client";

import { useEffect, useState, type ReactNode } from "react";

import { DEMO_CARDS } from "@/components/demo/demo-course";

/**
 * Une fiche se découpe. Les cartes se retournent, une par une.
 *
 * Trois seulement : dans la fenêtre du parcours, quatre s'écrasent. Le
 * retournement est le seul enchantement du tunnel — la vraie session, elle,
 * ne pivote pas.
 */

const CARDS = DEMO_CARDS.slice(0, 3);

export function FlashcardStory() {
  const [beat, setBeat] = useState(0);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setBeat(7);
      return;
    }

    const timers = [
      window.setTimeout(() => setBeat(1), 160),
      window.setTimeout(() => setBeat(2), 520),
      window.setTimeout(() => setBeat(3), 880),
      window.setTimeout(() => setBeat(4), 1_720),
      window.setTimeout(() => setBeat(5), 2_280),
      window.setTimeout(() => setBeat(6), 2_840),
    ];
    return () => timers.forEach((timer) => window.clearTimeout(timer));
  }, []);

  return (
    <div className="mx-auto grid w-full max-w-[400px] gap-2.5" style={{ perspective: "1100px" }}>
      {CARDS.map((card, index) => {
        const shown = beat > index;
        const flipped = beat >= 4 + index;
        return (
          <div
            key={card.front}
            className="relative h-[112px]"
            style={{
              opacity: shown ? 1 : 0,
              transform: shown ? "translateY(0)" : "translateY(16px)",
              transition:
                "opacity 420ms var(--ease-out-strong), transform 420ms var(--ease-out-strong)",
            }}
          >
            <div
              className="absolute inset-0"
              style={{
                transformStyle: "preserve-3d",
                transform: flipped ? "rotateY(180deg)" : "rotateY(0deg)",
                transition: "transform 560ms var(--ease-out-strong)",
              }}
            >
              <Face>
                <span className="rounded-pill bg-accent-soft px-2 py-0.5 text-[9px] font-bold uppercase tracking-caps text-accent">
                  {card.kindLabel}
                </span>
                <p className="mt-2 text-[15px] font-semibold leading-snug text-ink">{card.front}</p>
                {card.choices ? (
                  <div className="mt-2 flex flex-wrap gap-1.5">
                    {card.choices.map((choice, choiceIndex) => (
                      <span
                        key={choice}
                        className="rounded-[8px] bg-surface-muted px-2 py-1 text-[10px] text-ink-secondary"
                      >
                        {choiceIndex === card.answerIndex ? (
                          <span className="font-medium text-ink">{choice}</span>
                        ) : (
                          choice
                        )}
                      </span>
                    ))}
                  </div>
                ) : null}
              </Face>
              <Face back>
                <span className="rounded-pill bg-accent-soft px-2 py-0.5 text-[9px] font-bold uppercase tracking-caps text-accent">
                  Réponse
                </span>
                <p className="mt-2 text-[15px] font-semibold leading-snug text-ink">{card.back}</p>
                {card.note ? (
                  <p className="mt-1.5 text-[12px] leading-snug text-ink-secondary">{card.note}</p>
                ) : null}
              </Face>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function Face({ children, back = false }: { children: ReactNode; back?: boolean }) {
  return (
    <article
      className="paper absolute inset-0 overflow-hidden rounded-[16px] bg-surface px-4 py-3"
      style={{
        backfaceVisibility: "hidden",
        WebkitBackfaceVisibility: "hidden",
        transform: back ? "rotateY(180deg)" : "none",
      }}
    >
      {children}
    </article>
  );
}
