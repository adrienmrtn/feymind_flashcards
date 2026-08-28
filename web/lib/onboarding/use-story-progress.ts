"use client";

import { useEffect, useState } from "react";

/** Avance de 0 à 1, une seule fois. Sans mouvement, on pose la fin tout de suite. */
export function useStoryProgress(durationMs: number): number {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setProgress(1);
      return;
    }

    const started = Date.now();
    let frame = 0;

    function tick() {
      const next = Math.min(1, (Date.now() - started) / durationMs);
      setProgress(next);
      if (next < 1) frame = window.requestAnimationFrame(tick);
    }

    frame = window.requestAnimationFrame(tick);
    return () => window.cancelAnimationFrame(frame);
  }, [durationMs]);

  return progress;
}

export function clamp01(value: number) {
  return Math.min(1, Math.max(0, value));
}
