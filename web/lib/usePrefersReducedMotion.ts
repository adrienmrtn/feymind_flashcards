"use client";

import { useEffect, useState } from "react";

/**
 * Le visiteur a demandé moins de mouvement. Les shaders s'arrêtent (`speed={0}`)
 * plutôt que de continuer à peindre soixante images par seconde pour rien.
 */
export function usePrefersReducedMotion() {
  const [reduced, setReduced] = useState(() =>
    typeof window !== "undefined"
      ? window.matchMedia("(prefers-reduced-motion: reduce)").matches
      : false,
  );

  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setReduced(media.matches);
    update();
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, []);

  return reduced;
}
