"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Ce qui apparaît quand ça arrive à l'écran.
 *
 * `IntersectionObserver` et pas un calcul de défilement : le navigateur sait déjà répondre à
 * « est-ce visible », et le lui redemander soixante fois par seconde coûte une mise en page à
 * chaque image. L'observation s'arrête au premier passage - une section qui rejoue son entrée
 * chaque fois qu'on remonte donne une page qui clignote.
 */
export function Reveal({
  children,
  className = "",
  delay = 0,
  soft = false,
  as: Tag = "div",
}: {
  children: React.ReactNode;
  className?: string;
  /** Le cran de la cascade, pas une durée. */
  delay?: number;
  /**
   * L'entrée longue, pour ce qui occupe la moitié de l'écran.
   *
   * Une grande carte qui monte à la même vitesse qu'un titre se voit arriver ; elle part donc
   * de plus loin et se pose plus lentement, et ses deux moitiés entrent l'une après l'autre.
   */
  soft?: boolean;
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
      // pile au moment où elle touche l'écran se lit comme un retard. Une entrée douce dure
      // plus longtemps, donc elle part plus tôt, sans quoi elle finirait au milieu de l'écran.
      soft
        ? { rootMargin: "0px 0px -4% 0px", threshold: 0.01 }
        : { rootMargin: "0px 0px -12% 0px", threshold: 0.08 },
    );

    observer.observe(element);
    return () => observer.disconnect();
  }, [soft]);

  return (
    <Tag
      ref={node as never}
      className={`reveal stagger ${soft ? "reveal-soft" : ""} ${className}`}
      data-shown={shown ? "true" : undefined}
      style={{ ["--index" as string]: delay }}
    >
      {children}
    </Tag>
  );
}
