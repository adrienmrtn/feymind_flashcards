import Link from "next/link";

import { StartButton } from "./StartButton";

/**
 * La barre de la vitrine. Pas celle du parcours.
 *
 * Un mot, un bouton. Le parcours a sa propre jauge ; ici on n'emprunte rien
 * de ça, pour que la landing ne se lise pas comme un tunnel.
 */
export function LandingHeader() {
  return (
    <header className="sticky top-0 z-20 border-b border-hairline-on-canvas/80 bg-canvas/85 backdrop-blur-md">
      <div className="mx-auto flex h-14 max-w-page items-center justify-between px-screen">
        <Link href="/" className="text-[15px] font-bold tracking-tight text-ink">
          Micabo
        </Link>
        <StartButton size="compact" />
      </div>
    </header>
  );
}
