"use client";

import { PulsingBorder } from "@paper-design/shaders-react";

import { usePrefersReducedMotion } from "@/lib/usePrefersReducedMotion";

import { SHADER_BUDGET } from "./shader-budget";
import { StartButton } from "./StartButton";
import { WhenWebGL } from "./WhenWebGL";

const GLOW_COLORS = ["#0b8a66", "#16c08c", "#dff4ec"];

/**
 * Le grand **Commencer** du hero, avec un filet lumineux très bas.
 *
 * Une ombre verte tient lieu de repli. Le bouton compact du header n'en a
 * pas : un halo à chaque page se fatiguerait.
 */
export function StartGlow() {
  const reduced = usePrefersReducedMotion();

  return (
    <div className="relative inline-flex items-center justify-center rounded-button shadow-[0_0_28px_rgba(22,192,140,0.28)]">
      <WhenWebGL>
        <PulsingBorder
          aria-hidden
          data-print="hide"
          className="pointer-events-none absolute -inset-8"
          width="100%"
          height="100%"
          colorBack="#00000000"
          colors={GLOW_COLORS}
          roundness={0.4}
          thickness={0.1}
          softness={0.65}
          intensity={0.36}
          bloom={0.62}
          spots={4}
          spotSize={0.16}
          pulse={reduced ? 0 : 0.3}
          smoke={0.22}
          smokeSize={0.5}
          speed={reduced ? 0 : 0.6}
          {...SHADER_BUDGET}
        />
      </WhenWebGL>
      <StartButton className="relative" />
    </div>
  );
}
