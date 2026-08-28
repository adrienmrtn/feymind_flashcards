import Link from "next/link";

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
      <header className="border-b border-hairline-on-canvas">
        <div className="mx-auto flex h-14 max-w-page items-center justify-between px-screen">
          <Link href="/" className="text-[15px] font-bold tracking-tight text-ink">
            Micabo
          </Link>
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
