"use client";

import { GrainGradient, MeshGradient } from "@paper-design/shaders-react";

import { WhenWebGL } from "@/components/landing/WhenWebGL";
import { SHADER_BUDGET } from "@/components/landing/shader-budget";
import { usePrefersReducedMotion } from "@/lib/usePrefersReducedMotion";

/**
 * Un peu de Paper Shaders **hors de la landing**, et pas plus.
 *
 * La vitrine a déjà son mesh et son grain. Ici ce n'est qu'une tache : assez
 * pour que le canvas ne soit plus un aplat, pas assez pour qu'on le lise
 * comme une animation. Deux formes, deux endroits, et on s'arrête.
 */

const MESH_COLORS = ["#dce8dc", "#f6f7f9", "#16c08c", "#0b8a66"];
const GRAIN_COLORS = ["#d7e6d8", "#f6f7f9", "#16c08c"];

const SOFT_BUDGET = {
  ...SHADER_BUDGET,
  maxPixelCount: 960 * 540,
};

/** Tache mesh derrière une page de porte (connexion, compte). */
export function SoftMesh() {
  const reduced = usePrefersReducedMotion();

  return (
    <div
      aria-hidden
      data-print="hide"
      className="pointer-events-none absolute -top-28 left-1/2 h-[420px] w-[min(720px,130%)] -translate-x-1/2"
      style={{
        maskImage: "radial-gradient(ellipse 70% 60% at 50% 40%, black 14%, transparent 76%)",
        WebkitMaskImage:
          "radial-gradient(ellipse 70% 60% at 50% 40%, black 14%, transparent 76%)",
      }}
    >
      <div
        className="absolute inset-0 opacity-25"
        style={{
          background: "radial-gradient(circle, var(--color-accent-vivid), transparent 68%)",
        }}
      />
      <WhenWebGL>
        <MeshGradient
          className="absolute inset-0 opacity-50"
          width="100%"
          height="100%"
          colors={MESH_COLORS}
          distortion={0.42}
          swirl={0.16}
          grainMixer={0.08}
          grainOverlay={0.1}
          offsetX={0.08}
          offsetY={-0.12}
          scale={1.08}
          speed={reduced ? 0 : 0.1}
          {...SOFT_BUDGET}
        />
      </WhenWebGL>
    </div>
  );
}

/** Grain posé en haut de l'app, assez pâle pour rester du papier. */
export function SoftGrain() {
  const reduced = usePrefersReducedMotion();

  return (
    <div
      aria-hidden
      data-print="hide"
      className="pointer-events-none absolute inset-x-0 top-0 h-[280px]"
      style={{
        maskImage: "linear-gradient(to bottom, black 20%, transparent 100%)",
        WebkitMaskImage: "linear-gradient(to bottom, black 20%, transparent 100%)",
      }}
    >
      <WhenWebGL>
        <GrainGradient
          className="absolute inset-0 opacity-40"
          width="100%"
          height="100%"
          colorBack="#f6f7f9"
          colors={GRAIN_COLORS}
          shape="wave"
          softness={0.86}
          intensity={0.16}
          noise={0.22}
          scale={1.2}
          speed={reduced ? 0 : 0.08}
          {...SOFT_BUDGET}
        />
      </WhenWebGL>
    </div>
  );
}
