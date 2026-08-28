import Link from "next/link";

import { Separator } from "@/components/ui/separator";
import { PRIVACY_PATH, TERMS_PATH } from "@/lib/legal";

/**
 * Le pied de page de la vitrine.
 *
 * Pas de badge App Store tant que le lien n'est pas public : un badge mort se voit.
 * Confidentialité et conditions sont les adresses que l'iPhone ouvre déjà. Le parcours
 * s'ouvre par **Commencer**. Une session déjà ouverte remplace ça par Dashboard.
 */
export function Footer({ signedIn = false }: { signedIn?: boolean }) {
  return (
    <footer className="mt-24" data-print="hide">
      <Separator />
      <div className="mx-auto max-w-page px-screen py-14">
        <div className="flex flex-col gap-10 sm:flex-row sm:items-start sm:justify-between">
          <div className="max-w-[34ch]">
            <p className="text-[15px] font-bold text-ink">Micabo</p>
            <p className="mt-2.5 text-[13.5px] leading-relaxed text-ink-secondary">
              Tes cours deviennent une fiche qu&apos;on relit, et des cartes qui reviennent au bon
              moment.
            </p>
          </div>

          <div className="flex flex-wrap gap-x-14 gap-y-8 text-[13.5px]">
            <div>
              <p className="eyebrow mb-3 text-ink-tertiary">Le site</p>
              <ul className="space-y-1.5 text-ink-secondary">
                {signedIn ? (
                  <li>
                    <Link href="/app" className="underline-draw" data-print="bare">
                      Dashboard
                    </Link>
                  </li>
                ) : (
                  <>
                    <li>
                      <Link href="/commencer/pays" className="underline-draw" data-print="bare">
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
