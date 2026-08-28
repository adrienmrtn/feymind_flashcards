import Link from "next/link";

import { StartButton } from "./StartButton";

/**
 * La barre de la vitrine. Pas celle du parcours.
 *
 * Un mot, un bouton. Le parcours a sa propre jauge ; ici on n'emprunte rien
 * de ça, pour que la landing ne se lise pas comme un tunnel.
 */
export function LandingHeader({ signedIn = false }: { signedIn?: boolean }) {
  return (
    <header className="sticky top-0 z-20 border-b border-border/80 bg-background/70 backdrop-blur-md">
      <a
        href="#contenu"
        className="sr-only focus:not-sr-only focus:absolute focus:left-screen focus:top-3 focus:z-30 focus:rounded-button focus:bg-ink focus:px-3 focus:py-2 focus:text-[13px] focus:font-medium focus:text-on-ink"
      >
        Aller au contenu
      </a>
      <div className="mx-auto flex h-14 max-w-page items-center justify-between px-screen">
        <Link href="/" className="text-[15px] font-bold tracking-tight text-foreground">
          Micabo
        </Link>
        <StartButton signedIn={signedIn} size="compact" />
      </div>
    </header>
  );
}
