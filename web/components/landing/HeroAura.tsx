"use client";

import { MeshGradient } from "@paper-design/shaders-react";

import { useAppearance } from "@/components/appearance/AppearanceProvider";
import { APPEARANCE_SHADER } from "@/lib/appearance";
import { usePrefersReducedMotion } from "@/lib/usePrefersReducedMotion";

import { SHADER_BUDGET } from "./shader-budget";
import { WhenWebGL } from "./WhenWebGL";

/**
 * La lueur du hero : un mesh bleu et gris, masqué en ellipse.
 *
 * Un radial CSS reste dessous : si WebGL manque, on retrouve une lueur.
 * Avec WebGL, le mesh la remplace - taches lentes, pas le dégradé violet
 * que tout le monde pose.
 */
export function HeroAura() {
  const reduced = usePrefersReducedMotion();
  const { appearance } = useAppearance();
  const colors = APPEARANCE_SHADER[appearance].mesh;

  return (
    <div
      aria-hidden
      data-print="hide"
      className="pointer-events-none absolute -top-40 left-1/2 h-[560px] w-[min(980px,140%)] -translate-x-1/2"
      style={{
        maskImage: "radial-gradient(ellipse 68% 58% at 50% 42%, black 18%, transparent 74%)",
        WebkitMaskImage:
          "radial-gradient(ellipse 68% 58% at 50% 42%, black 18%, transparent 74%)",
      }}
    >
      <div
        className="absolute inset-0 opacity-40"
        style={{ background: "radial-gradient(circle, var(--color-accent-vivid), transparent 65%)" }}
      />
      <WhenWebGL>
        <MeshGradient
          className="absolute inset-0 opacity-90"
          width="100%"
          height="100%"
          colors={colors}
          distortion={0.62}
          swirl={0.28}
          grainMixer={0.12}
          grainOverlay={0.16}
          offsetX={0.12}
          offsetY={-0.18}
          scale={1.12}
          speed={reduced ? 0 : 0.16}
          {...SHADER_BUDGET}
        />
      </WhenWebGL>
    </div>
  );
}
