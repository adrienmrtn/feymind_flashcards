import type { Route } from "next";
import Link from "next/link";

import { BrandLockup } from "@/components/BrandMark";
import { Separator } from "@/components/ui/separator";
import { LANDING_NAV } from "@/lib/landing-sections";
import { PRIVACY_PATH, TERMS_PATH } from "@/lib/legal";
import { SITE_PAGES } from "@/lib/site-pages";

/**
 * Le pied de page de la vitrine.
 *
 * Pas de badge App Store tant que le lien n'est pas public : un badge mort se voit.
 * Confidentialité et conditions sont les adresses que l'iPhone ouvre déjà. Le parcours
 * s'ouvre par **Commencer**. Une session déjà ouverte remplace ça par Ouvrir l'app.
 */
export function Footer({ signedIn = false }: { signedIn?: boolean }) {
  return (
    <footer className="mt-24" data-print="hide">
      <Separator />
      <div className="mx-auto max-w-page px-screen py-14">
        <div className="flex flex-col gap-10 sm:flex-row sm:items-start sm:justify-between">
          <div className="max-w-[34ch]">
            <BrandLockup
              href="/"
              size={32}
              className="text-ink"
              wordClassName="text-[15px] font-bold text-ink"
            />
            <p className="mt-2.5 text-[13.5px] leading-relaxed text-ink-secondary">
              Tes cours deviennent une fiche qu&apos;on relit, et des cartes qui reviennent au bon
              moment.
            </p>
          </div>

          <div className="flex flex-wrap gap-x-14 gap-y-8 text-[13.5px]">
            {/* La même structure qu'en haut, en clair. C'est le pied de page qui porte les
                sections sur mobile, où la barre n'a pas la place de les montrer. */}
            <div>
              <p className="eyebrow mb-3 text-ink-tertiary">Le produit</p>
              <ul className="space-y-1.5 text-ink-secondary">
                {LANDING_NAV.map((item) => (
                  <li key={item.href}>
                    <Link href={item.href as Route} className="underline-draw" data-print="bare">
                      {item.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>

            <div>
              <p className="eyebrow mb-3 text-ink-tertiary">Le site</p>
              <ul className="space-y-1.5 text-ink-secondary">
                {signedIn ? (
                  <li>
                    <Link href="/app" className="underline-draw" data-print="bare">
                      Ouvrir l&apos;app
                    </Link>
                  </li>
                ) : (
                  <>
                    <li>
                      <Link href="/commencer" className="underline-draw" data-print="bare">
                        Commencer
                      </Link>
                    </li>
                    <li>
                      <Link
                        href="/commencer/compte?suite=%2Fapp"
                        className="underline-draw"
                        data-print="bare"
                      >
                        Se connecter
                      </Link>
                    </li>
                  </>
                )}
              </ul>
            </div>

            {/* Les pages de fond, liées depuis **chaque** page du site. C'est ce qui les rend
                explorables sans dépendre d'un lien dans un paragraphe, et ce qui donne à
                Google des pages à proposer sous le résultat de la marque. */}
            <div>
              <p className="eyebrow mb-3 text-ink-tertiary">À lire</p>
              <ul className="space-y-1.5 text-ink-secondary">
                {SITE_PAGES.map((page) => (
                  <li key={page.path}>
                    <Link href={page.path} className="underline-draw" data-print="bare">
                      {page.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>

            <div>
              <p className="eyebrow mb-3 text-ink-tertiary">Sur ton téléphone</p>
              <p className="text-ink-secondary">
                Aussi sur iPhone.
                <br />
                <span className="text-ink-tertiary">Le site et l&apos;app partagent tes cours.</span>
              </p>
            </div>

            <div>
              <p className="eyebrow mb-3 text-ink-tertiary">Le cadre</p>
              <ul className="space-y-1.5 text-ink-secondary">
                <li>
                  <Link href={PRIVACY_PATH} className="underline-draw" data-print="bare">
                    Confidentialité
                  </Link>
                </li>
                <li>
                  <Link href={TERMS_PATH} className="underline-draw" data-print="bare">
                    Conditions
                  </Link>
                </li>
              </ul>
            </div>
          </div>
        </div>

        <p className="mt-12 text-[12px] text-ink-tertiary">
          © {new Date().getFullYear()} Micabo
          <span aria-hidden> · </span>
          <Link href={PRIVACY_PATH} className="underline-draw">
            Confidentialité
          </Link>
          <span aria-hidden> · </span>
          <Link href={TERMS_PATH} className="underline-draw">
            Conditions
          </Link>
        </p>
      </div>
    </footer>
  );
}
