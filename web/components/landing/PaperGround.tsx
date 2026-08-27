"use client";

import { PaperTexture } from "@paper-design/shaders-react";

import { SHADER_BUDGET } from "./shader-budget";
import { WhenWebGL } from "./WhenWebGL";

/**
 * Le grain du papier, derrière toute la vitrine.
 *
 * Figé (`speed={0}`). Assez de fibre pour que l'ivoire cesse d'être un aplat,
 * pas assez pour qu'on le prenne pour un filtre. Sans WebGL, le fond CSS
 * `--color-canvas` reste tout seul — même crème.
 */
export function PaperGround() {
  return (
    <div
      aria-hidden
      data-print="hide"
      className="pointer-events-none fixed inset-0 z-0 overflow-hidden"
    >
      <WhenWebGL>
        <PaperTexture
          className="h-full w-full"
          width="100%"
          height="100%"
          colorBack="#f6f4ed"
          colorFront="#cfc8b6"
          contrast={0.4}
          roughness={0.5}
          fiber={0.55}
          fiberSize={0.18}
          crumples={0.16}
          crumpleSize={0.26}
          folds={0.1}
          foldCount={4}
          fade={0.08}
          drops={0}
          scale={1}
          speed={0}
          {...SHADER_BUDGET}
        />
      </WhenWebGL>
    </div>
  );
}
