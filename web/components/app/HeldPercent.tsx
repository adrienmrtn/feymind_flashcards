"use client";

import { useEffect, useState } from "react";

import { heldPercentAt } from "@/lib/held-percent";

/** Lecture d'un fichier ou des sous-titres. */
export const READING_HOLD_MS = 8_000;
/** Écriture d'une fiche. */
export const WRITING_HOLD_MS = 48_000;
/** Écriture de cartes. */
export const CARDS_HOLD_MS = 36_000;
/** Explication d'un passage. */
export const EXPLAIN_HOLD_MS = 10_000;

export function useHeldPercent(active: boolean, durationMs: number): number {
  const [percent, setPercent] = useState(0);

  useEffect(() => {
    if (!active) {
      setPercent(0);
      return;
    }

    const started = performance.now();
    let frame = 0;
    const tick = (now: number) => {
      setPercent(heldPercentAt(now - started, durationMs));
      if (now - started < durationMs) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [active, durationMs]);

  return percent;
}

/** Le chiffre seul, en tertiaire, à côté de l'attente déjà là. */
export function HeldPercent({
  active,
  durationMs,
  label,
}: {
  active: boolean;
  durationMs: number;
  label: string;
}) {
  const percent = useHeldPercent(active, durationMs);
  if (!active || percent <= 0) return null;

  return (
    <p
      className="numeral text-[13px] text-ink-tertiary"
      role="progressbar"
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={percent}
      aria-label={label}
    >
      {percent} %
    </p>
  );
}
