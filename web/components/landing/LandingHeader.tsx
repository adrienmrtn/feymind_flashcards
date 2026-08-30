import Link from "next/link";

import { LANDING_NAV } from "@/lib/landing-sections";

import { StartButton } from "./StartButton";

/**
 * La barre de la vitrine. Pas celle du parcours.
 *
 * Le parcours a sa propre jauge ; ici on n'emprunte rien de ça, pour que la
 * landing ne se lise pas comme un tunnel.
 *
 * Les quatre ancres ne sont pas là pour la décoration : une page sans structure
 * nommée ne donne à un moteur aucun intitulé à proposer sous le résultat, et un
 * lecteur qui arrive de la recherche n'a aucun moyen de sauter à ce qu'il
 * cherchait.
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
      <div className="mx-auto flex h-14 max-w-page items-center justify-between gap-6 px-screen">
        <Link href="/" className="shrink-0 text-[15px] font-bold tracking-tight text-foreground">
          Micabo
        </Link>

        {/* Les sections, nommées. Elles sont masquées sur mobile — quatre liens en
            plus d'un bouton ne tiennent pas sur 360 px, et le pied de page les
            reprend. Un menu déroulant pour quatre ancres coûterait plus qu'il
            n'apporte. */}
        <nav aria-label="Sections" className="hidden items-center gap-7 md:flex">
          {LANDING_NAV.map((item) => (
            <a
              key={item.href}
              href={item.href}
              className="underline-draw text-[13.5px] font-medium text-ink-secondary"
            >
              {item.label}
            </a>
          ))}
        </nav>

        <StartButton signedIn={signedIn} size="compact" />
      </div>
    </header>
  );
}
