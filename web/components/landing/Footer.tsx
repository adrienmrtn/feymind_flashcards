/**
 * Le pied de page.
 *
 * Il porte **ce qui manque encore**, plutôt que de faire comme si de rien n'était : l'app iOS
 * n'est pas publiée, donc il n'y a pas de badge App Store — un badge qui ne mène nulle part est
 * un mensonge, et un badge grisé est un aveu mieux formulé qu'une absence.
 *
 * Les liens légaux ne sont pas décoratifs : Apple et Google les exigent tous les deux pour un
 * écran de connexion, et ils devront exister avant l'étape 3. Ils sont donc listés ici en clair
 * comme ce qu'ils sont — à écrire.
 */
export function Footer() {
  return (
    <footer className="mt-32 border-t border-hairline-on-canvas" data-print="hide">
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
              <p className="eyebrow mb-3 text-ink-tertiary">Sur ton téléphone</p>
              <p className="text-ink-secondary">
                L&apos;app iOS arrive.
                <br />
                <span className="text-ink-tertiary">Le site et le téléphone partageront tes cours.</span>
              </p>
            </div>

            <div>
              <p className="eyebrow mb-3 text-ink-tertiary">Le site</p>
              <ul className="space-y-1.5 text-ink-secondary">
                <li>
                  <a href="/fondations" className="underline-draw" data-print="bare">
                    Les fondations
                  </a>
                </li>
              </ul>
            </div>

            <div>
              <p className="eyebrow mb-3 text-ink-tertiary">Mentions</p>
              <ul className="space-y-1.5 text-ink-tertiary">
                <li>Conditions d&apos;utilisation — à venir</li>
                <li>Confidentialité — à venir</li>
              </ul>
            </div>
          </div>
        </div>

        <p className="mt-12 text-[12px] text-ink-tertiary">
          © {new Date().getFullYear()} Micabo. Le site n&apos;est pas encore ouvert : ce que tu vois
          est construit, pas maquetté.
        </p>
      </div>
    </footer>
  );
}
