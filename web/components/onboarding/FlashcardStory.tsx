"use client";

import { useEffect, useState } from "react";

import { DEMO_CARDS } from "@/components/demo/demo-course";

/**
 * Une fiche qui se découpe en cartes, et les cartes se retournent.
 *
 * Trois seulement : dans la fenêtre du parcours, quatre s'écrasent. Le retournement
 * est le seul enchantement du tunnel - la vraie session, elle, ne pivote pas.
 */

const CARDS = DEMO_CARDS.slice(0, 3);

export function FlashcardStory() {
  const [beat, setBeat] = useState(0);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setBeat(CARDS.length + 1);
      return;
    }

    const timers = [
      window.setTimeout(() => setBeat(1), 180),
      window.setTimeout(() => setBeat(2), 720),
      window.setTimeout(() => setBeat(3), 1_240),
      window.setTimeout(() => setBeat(4), 2_100),
    ];
    return () => timers.forEach((timer) => window.clearTimeout(timer));
  }, []);

  return (
    <div className="mx-auto grid w-full max-w-[420px] gap-2.5">
      {CARDS.map((card, index) => {
        const shown = beat > index;
        const flipped = beat >= 4;
        return (
          <article
            key={card.front}
            className="overflow-hidden rounded-button border border-stroke bg-surface px-3.5 py-3"
            style={{
              opacity: shown ? 1 : 0,
              transform: shown ? "translateY(0)" : "translateY(18px)",
              transition:
                "opacity 420ms var(--ease-out-strong), transform 420ms var(--ease-out-strong)",
            }}
          >
            <span className="rounded-pill bg-accent-soft px-2 py-0.5 text-[9px] font-bold uppercase tracking-caps text-accent">
              {card.kindLabel}
            </span>
            <p className="mt-1.5 text-[13.5px] font-semibold leading-snug text-ink">
              {flipped ? card.back : card.front}
            </p>
            {!flipped && card.choices ? (
              <div className="mt-2 flex flex-wrap gap-1.5">
                {card.choices.map((choice) => (
                  <span
                    key={choice}
                    className="rounded-[8px] bg-surface-muted px-2 py-1 text-[10px] text-ink-secondary"
                  >
                    {choice}
                  </span>
                ))}
              </div>
            ) : null}
          </article>
        );
      })}
    </div>
  );
}
