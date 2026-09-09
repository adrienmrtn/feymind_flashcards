"use client";

import { useEffect, useRef, useState } from "react";

/**
 * La largeur réelle du conteneur, pour qu'un SVG dessine en pixels.
 *
 * Un `viewBox` fixe étire le texte avec le graphe : une étiquette de dix points devient
 * dix-sept points sur un grand écran, quatre sur un téléphone. Ici la boîte de vue suit la
 * largeur mesurée, donc une unité vaut un pixel et le texte garde sa taille.
 */
export function useMeasuredWidth<T extends HTMLElement>(fallback: number) {
  const ref = useRef<T | null>(null);
  const [width, setWidth] = useState(fallback);

  useEffect(() => {
    const node = ref.current;
    if (!node) return;
    const update = () => {
      const measured = Math.round(node.getBoundingClientRect().width);
      if (measured > 0) setWidth(measured);
    };
    update();
    const observer = new ResizeObserver(update);
    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  return { ref, width };
}
