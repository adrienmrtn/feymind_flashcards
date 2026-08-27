"use client";

import { GrainGradient } from "@paper-design/shaders-react";

import { usePrefersReducedMotion } from "@/lib/usePrefersReducedMotion";

import { Reveal } from "./Reveal";
import { SHADER_BUDGET } from "./shader-budget";
import { StartButton } from "./StartButton";

const WASH_COLORS = ["#e8efe6", "#f6f4ed", "#16c08c"];

/**
 * Le dernier appel : un lavage grainé, en tache, derrière le titre.
 *
 * Pas de second PulsingBorder ici — une toile WebGL de trop, et le hero a
 * déjà le halo. Le bouton reste le même **Commencer**, sans ornement.
 */
export function ClosingWash() {
  const reduced = usePrefersReducedMotion();

  return (
    <section className="relative mx-auto mt-28 max-w-page overflow-hidden px-screen pb-12 text-center">
      <div
        aria-hidden
        data-print="hide"
        className="pointer-events-none absolute inset-x-[-12%] -top-20 bottom-0 opacity-80"
        style={{
          maskImage: "radial-gradient(ellipse 78% 68% at 50% 62%, black 12%, transparent 76%)",
          WebkitMaskImage:
            "radial-gradient(ellipse 78% 68% at 50% 62%, black 12%, transparent 76%)",
        }}
      >
        <GrainGradient
          className="h-full w-full"
          colorBack="#f6f4ed"
          colors={WASH_COLORS}
          shape="blob"
          softness={0.82}
          intensity={0.2}
          noise={0.3}
          scale={1.15}
          speed={reduced ? 0 : 0.16}
          {...SHADER_BUDGET}
        />
      </div>

      <Reveal as="div" className="relative">
        <h2 className="mx-auto max-w-[22ch] text-[34px] font-bold leading-[1.06] tracking-display text-ink sm:text-[46px]">
          Ton prochain contrôle commence maintenant.
        </h2>
        <div className="mt-9">
          <StartButton />
        </div>
      </Reveal>
    </section>
  );
}
