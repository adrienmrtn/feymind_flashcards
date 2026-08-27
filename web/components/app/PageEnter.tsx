"use client";

import { usePathname } from "next/navigation";

/**
 * Chaque écran de l'app se pose en arrivant.
 *
 * La clé est le chemin : sans elle, le layout garderait le même nœud et
 * l'animation ne jouerait qu'une fois. Le contenu reste celui du serveur.
 */
export function PageEnter({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  return (
    <div key={pathname} className="page-enter">
      {children}
    </div>
  );
}
