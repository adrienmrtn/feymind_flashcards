"use client";

import { PaperTexture } from "@paper-design/shaders-react";

import { SHADER_BUDGET } from "./shader-budget";

/**
 * Le grain du papier, derrière toute la vitrine.
 *
 * Ce n'est pas un fond animé : `speed={0}` arrête la boucle. On voit la fibre
 * et un peu de froissement, assez pour que l'ivoire plat cesse de ressembler à
 * un aplats CSS, pas assez pour qu'on le prenne pour un filtre Instagram.
 */
export function PaperGround() {
  return (
    <div
      aria-hidden
      data-print="hide"
      className="pointer-events-none fixed inset-0 z-0 overflow-hidden"
    >
      <PaperTexture
        className="h-full w-full"
        colorBack="#f6f4ed"
        colorFront="#e4dfd2"
        contrast={0.2}
        roughness={0.28}
        fiber={0.32}
        fiberSize={0.16}
        crumples={0.08}
        crumpleSize={0.22}
        folds={0.04}
        foldCount={3}
        fade={0.15}
        drops={0}
        speed={0}
        {...SHADER_BUDGET}
      />
    </div>
  );
}
