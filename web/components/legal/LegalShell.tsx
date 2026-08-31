import Link from "next/link";

import { BrandLockup } from "@/components/BrandMark";
import { Footer } from "@/components/landing/Footer";
import { LEGAL_UPDATED } from "@/lib/legal";

/**
 * Une page de droit, sur le même papier que le reste.
 *
 * Pas la barre marketing : on vient lire, pas commencer. Le pied de page
 * reste, pour passer de l'une à l'autre sans revenir à la vitrine.
 */
export function LegalShell({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <>
      <a
        href="#contenu"
        className="sr-only focus-visible:not-sr-only focus-visible:absolute focus-visible:left-screen focus-visible:top-3 focus-visible:z-30 focus-visible:rounded-button focus-visible:bg-ink focus-visible:px-3 focus-visible:py-2 focus-visible:text-[13px] focus-visible:font-medium focus-visible:text-on-ink"
      >
        Aller au contenu
      </a>
      <header className="border-b border-hairline-on-canvas">
        <div className="mx-auto flex h-14 max-w-page items-center justify-between px-screen">
          <BrandLockup
            href="/"
            size={28}
            className="text-ink"
            wordClassName="text-[15px] font-bold tracking-tight text-ink"
          />
          <Link href="/" className="underline-draw text-[13.5px] text-ink-secondary">
            Retour à l&apos;accueil
          </Link>
        </div>
      </header>

      <main id="contenu" className="mx-auto w-full max-w-reading px-screen py-12 sm:py-16">
        <p className="eyebrow text-ink-tertiary">Micabo · iPhone et site</p>
        <h1 className="mt-3 text-[32px] font-bold leading-[1.08] tracking-tight-title text-ink sm:text-[40px]">
          {title}
        </h1>
        <p className="mt-3 text-[13.5px] text-ink-tertiary">Dernière mise à jour : {LEGAL_UPDATED}.</p>
        <div className="legal-prose mt-10">{children}</div>
      </main>

      <Footer />
    </>
  );
}

export function LegalSection({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="mt-9">
      <h2 className="text-[18px] font-semibold tracking-tight text-ink">{title}</h2>
      <div className="mt-3 space-y-3 text-[15px] leading-relaxed text-ink-secondary">{children}</div>
    </section>
  );
}
