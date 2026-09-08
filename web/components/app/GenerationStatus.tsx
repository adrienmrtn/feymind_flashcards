"use client";

import { useEffect, useState } from "react";

import {
  displayGenerationPercent,
  elapsedGenerationProgress,
  knownGenerationProgress,
} from "@/lib/generation-progress";

/**
 * Ce qu'on regarde pendant que Micabo écrit : un pourcentage, pas seulement
 * un orbe. Sans chiffre, l'attente se lit comme un écran figé.
 *
 * Le pourcentage d'un modèle est une jauge de temps, pas une mesure du travail
 * réel. Celui d'un paquet Anki suit les cartes déjà versées.
 */

type Known = { done: number; total: number };

export function GenerationStatus({
  title,
  hint,
  startedAt,
  known,
  compact = false,
}: {
  title: string;
  hint?: string | null;
  startedAt?: number;
  known?: Known;
  compact?: boolean;
}) {
  const fraction = useGenerationFraction(startedAt, known);
  const pct = displayGenerationPercent(fraction, { known: Boolean(known) });
  const size = compact ? 88 : 148;
  const radius = compact ? 34 : 52;
  const view = compact ? 88 : 120;
  const center = view / 2;

  return (
    <div
      className={`flex ${compact ? "items-center gap-4" : "flex-col items-center gap-4"}`}
      role="status"
      aria-live="polite"
      aria-busy={pct < 100}
    >
      <div
        className="relative flex shrink-0 items-center justify-center"
        style={{ width: size, height: size }}
        role="progressbar"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={pct}
        aria-label={title}
      >
        <svg
          viewBox={`0 0 ${view} ${view}`}
          className="absolute inset-0 h-full w-full -rotate-90"
          aria-hidden
        >
          <circle
            cx={center}
            cy={center}
            r={radius}
            fill="none"
            stroke="var(--color-accent)"
            strokeWidth={compact ? 6 : 8}
            opacity={0.16}
          />
          <circle
            cx={center}
            cy={center}
            r={radius}
            fill="none"
            stroke="var(--color-accent)"
            strokeWidth={compact ? 6 : 8}
            strokeLinecap="round"
            pathLength={100}
            strokeDasharray={100}
            strokeDashoffset={100 - Math.max(0.8, fraction * 100)}
          />
        </svg>
        <p
          className={`numeral relative font-bold leading-none tracking-display text-ink ${
            compact ? "text-[22px]" : "text-[44px]"
          }`}
        >
          {pct}
          <span className={compact ? "text-[12px]" : "text-[22px]"}> %</span>
        </p>
      </div>
      <div className={`min-w-0 ${compact ? "text-left" : "text-center"}`}>
        <p className={`font-semibold text-ink ${compact ? "text-[15.5px]" : "text-[16px]"}`}>
          {title}
        </p>
        {hint ? (
          <p className="mt-1 truncate text-[13px] text-ink-tertiary">{hint}</p>
        ) : null}
      </div>
    </div>
  );
}

function useGenerationFraction(startedAt?: number, known?: Known): number {
  const [now, setNow] = useState(() => Date.now());
  const [fallbackStart] = useState(() => Date.now());

  useEffect(() => {
    if (known) return;
    const id = window.setInterval(() => setNow(Date.now()), 80);
    return () => window.clearInterval(id);
  }, [known]);

  if (known) return knownGenerationProgress(known.done, known.total);
  const origin = startedAt && Number.isFinite(startedAt) ? startedAt : fallbackStart;
  return elapsedGenerationProgress(Math.max(0, now - origin));
}
