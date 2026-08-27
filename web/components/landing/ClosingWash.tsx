"use client";

import { GrainGradient } from "@paper-design/shaders-react";

import { usePrefersReducedMotion } from "@/lib/usePrefersReducedMotion";

import { Reveal } from "./Reveal";
import { SHADER_BUDGET } from "./shader-budget";
import { StartButton } from "./StartButton";
import { WhenWebGL } from "./WhenWebGL";

const WASH_COLORS = ["#d7e6d8", "#f6f4ed", "#16c08c"];

/**
 * Le dernier appel : un lavage grainé, en tache, derrière le titre.
 *
 * Un radial CSS reste dessous.
 */
export function ClosingWash({ signedIn = false }: { signedIn?: boolean }) {
  const reduced = usePrefersReducedMotion();

  return (
    <section className="relative mx-auto mt-28 max-w-page overflow-hidden px-screen pb-12 text-center">
      <div
        aria-hidden
        data-print="hide"
        className="pointer-events-none absolute inset-x-[-12%] -top-20 bottom-0"
        style={{
          maskImage: "radial-gradient(ellipse 78% 68% at 50% 62%, black 12%, transparent 76%)",
          WebkitMaskImage:
            "radial-gradient(ellipse 78% 68% at 50% 62%, black 12%, transparent 76%)",
        }}
      >
        <div
          className="absolute inset-0 opacity-35"
          style={{
            background:
              "radial-gradient(ellipse at 50% 60%, color-mix(in oklch, var(--color-accent-vivid) 45%, var(--color-canvas)), transparent 70%)",
          }}
        />
        <WhenWebGL>
          <GrainGradient
            className="absolute inset-0 opacity-90"
            width="100%"
            height="100%"
            colorBack="#f6f4ed"
            colors={WASH_COLORS}
            shape="blob"
            softness={0.78}
            intensity={0.3}
            noise={0.36}
            scale={1.15}
            speed={reduced ? 0 : 0.18}
            {...SHADER_BUDGET}
          />
        </WhenWebGL>
      </div>

      <Reveal as="div" className="relative">
        <h2 className="mx-auto max-w-[22ch] text-[34px] font-bold leading-[1.06] tracking-display text-ink sm:text-[46px]">
          Ton prochain contrôle commence maintenant.
        </h2>
        <div className="mt-9">
          <StartButton signedIn={signedIn} />
        </div>
      </Reveal>
    </section>
  );
}
