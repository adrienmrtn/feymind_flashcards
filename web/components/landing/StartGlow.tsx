"use client";

import { PulsingBorder } from "@paper-design/shaders-react";

import { usePrefersReducedMotion } from "@/lib/usePrefersReducedMotion";

import { SHADER_BUDGET } from "./shader-budget";
import { StartButton } from "./StartButton";

const GLOW_COLORS = ["#0b8a66", "#16c08c", "#dff4ec"];

/**
 * Le grand **Commencer** du hero, avec un filet lumineux très bas.
 *
 * Le bouton compact du header n'en a pas : un halo qui pulse à chaque page
 * de l'app se fatiguerait. Ici on le voit une fois, autour de l'entrée.
 */
export function StartGlow() {
  const reduced = usePrefersReducedMotion();

  return (
    <div className="relative inline-flex items-center justify-center">
      <PulsingBorder
        aria-hidden
        data-print="hide"
        className="pointer-events-none absolute -inset-7"
        colorBack="#00000000"
        colors={GLOW_COLORS}
        roundness={0.38}
        thickness={0.06}
        softness={0.7}
        intensity={0.22}
        bloom={0.45}
        spots={3}
        spotSize={0.14}
        pulse={reduced ? 0 : 0.22}
        smoke={0.18}
        smokeSize={0.45}
        speed={reduced ? 0 : 0.55}
        {...SHADER_BUDGET}
      />
      <StartButton className="relative" />
    </div>
  );
}
