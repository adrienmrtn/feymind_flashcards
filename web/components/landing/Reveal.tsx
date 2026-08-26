"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Ce qui apparaît quand ça arrive à l'écran.
 *
 * `IntersectionObserver` et pas un calcul de défilement : le navigateur sait déjà répondre à
 * « est-ce visible », et le lui redemander soixante fois par seconde coûte une mise en page à
 * chaque image. L'observation s'arrête au premier passage — une section qui rejoue son entrée
 * chaque fois qu'on remonte donne une page qui clignote.
 */
export function Reveal({
  children,
  className = "",
  delay = 0,
  as: Tag = "div",
}: {
  children: React.ReactNode;
  className?: string;
  /** Le cran de la cascade, pas une durée. */
  delay?: number;
  as?: "div" | "section" | "li" | "figure";
}) {
  const node = useRef<HTMLElement>(null);
  const [shown, setShown] = useState(false);

  useEffect(() => {
    const element = node.current;
    if (!element) return;

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          setShown(true);
          observer.disconnect();
        }
      },
      // Le déclenchement se fait un peu avant le bord : une section qui commence son entrée
      // pile au moment où elle touche l'écran se lit comme un retard.
      { rootMargin: "0px 0px -12% 0px", threshold: 0.08 },
    );

    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  return (
    <Tag
      ref={node as never}
      className={`reveal stagger ${className}`}
      data-shown={shown ? "true" : undefined}
      style={{ ["--index" as string]: delay }}
    >
      {children}
    </Tag>
  );
}
