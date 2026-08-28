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
        className="sr-only focus-visible:not-sr-only focus-visible:absolute focus-visible:left-screen focus-visible:top-3 focus-visible:z-30 focus-visible:rounded-button focus-visible:bg-ink focus-visible:px-3 focus-visible:py-2 focus-visible:text-[13px] focus-visible:font-medium focus-visible:text-on-ink"
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
