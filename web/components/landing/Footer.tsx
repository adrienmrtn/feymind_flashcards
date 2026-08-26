import Link from "next/link";

/**
 * Le pied de page de la vitrine.
 *
 * L'app iOS n'est pas publiée : pas de badge App Store. Les pages légales n'existent pas
 * encore : on ne pose pas de liens morts. Le parcours s'ouvre par **Commencer**, le même
 * libellé que partout ailleurs.
 */
export function Footer() {
  return (
    <footer className="mt-24 border-t border-hairline-on-canvas" data-print="hide">
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
                <li>
                  <Link href="/commencer/compte" className="underline-draw" data-print="bare">
                    Commencer
                  </Link>
                </li>
              </ul>
            </div>

            <div>
              <p className="eyebrow mb-3 text-ink-tertiary">Sur ton téléphone</p>
              <p className="text-ink-secondary">
                L&apos;app iOS arrive.
                <br />
                <span className="text-ink-tertiary">Le site et le téléphone partageront tes cours.</span>
              </p>
            </div>
          </div>
        </div>

        <p className="mt-12 text-[12px] text-ink-tertiary">© {new Date().getFullYear()} Micabo</p>
      </div>
    </footer>
  );
}
