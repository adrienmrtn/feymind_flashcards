"use client";

import { MeshGradient } from "@paper-design/shaders-react";

import { usePrefersReducedMotion } from "@/lib/usePrefersReducedMotion";

import { SHADER_BUDGET } from "./shader-budget";

const AURA_COLORS = ["#e8efe6", "#f6f4ed", "#16c08c", "#0b8a66"];

/**
 * La lueur du hero : un mesh sage et ivoire, masqué en ellipse.
 *
 * Le radial CSS d'avant était un disque flou. Ici les taches bougent assez
 * lentement pour qu'on sente le papier vivre, sans retomber dans le dégradé
 * violet que tout le monde pose.
 */
export function HeroAura() {
  const reduced = usePrefersReducedMotion();

  return (
    <div
      aria-hidden
      data-print="hide"
      className="pointer-events-none absolute -top-40 left-1/2 h-[560px] w-[min(980px,140%)] -translate-x-1/2 opacity-70"
      style={{
        maskImage: "radial-gradient(ellipse 68% 58% at 50% 42%, black 18%, transparent 74%)",
        WebkitMaskImage:
          "radial-gradient(ellipse 68% 58% at 50% 42%, black 18%, transparent 74%)",
      }}
    >
      <MeshGradient
        className="h-full w-full"
        colors={AURA_COLORS}
        distortion={0.52}
        swirl={0.22}
        grainMixer={0.1}
        grainOverlay={0.14}
        offsetX={0.12}
        offsetY={-0.18}
        scale={1.12}
        speed={reduced ? 0 : 0.12}
        {...SHADER_BUDGET}
      />
    </div>
  );
}
