"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";

/**
 * Chaque écran de l'app se pose en arrivant.
 *
 * La clé est le chemin : sans elle, le layout garderait le même nœud et
 * l'animation ne jouerait qu'une fois. Le contenu reste celui du serveur.
 *
 * **La classe part dès que l'animation est finie.** `page-enter` pose un
 * `translate` et un `filter`, et un ancêtre transformé fait de `position:
 * fixed` un `absolute` - le bouton « Réviser ce cours » restait collé au
 * bas de la page au lieu de flotter.
 */
export function PageEnter({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  return <Inner key={pathname}>{children}</Inner>;
}

function Inner({ children }: { children: React.ReactNode }) {
  const [live, setLive] = useState(true);

  useEffect(() => {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const timer = window.setTimeout(() => setLive(false), reduce ? 80 : 420);
    return () => window.clearTimeout(timer);
  }, []);

  return <div className={live ? "page-enter" : undefined}>{children}</div>;
}
