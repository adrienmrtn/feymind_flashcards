import Link from "next/link";

import { StartButton } from "./StartButton";

/**
 * La barre de la vitrine. Pas celle du parcours.
 *
 * Un mot, un bouton. Le parcours a sa propre jauge, à partir du troisième écran ;
 * ici on n'emprunte rien de ça, pour que la landing ne se lise pas comme un tunnel.
 */
export function LandingHeader() {
  return (
    <header className="mx-auto flex max-w-page items-center justify-between px-screen pt-5 sm:pt-6">
      <Link href="/" className="text-[15px] font-bold text-ink">
        Micabo
      </Link>
      <StartButton size="compact" />
    </header>
  );
}
