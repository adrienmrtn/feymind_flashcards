import { BrandMark } from "@/components/BrandMark";

/**
 * Le téléphone, entre la mémoire et l'examen.
 *
 * Pas de badge App Store : un lien mort se voit. Le bloc dit que l'iPhone existe,
 * que le compte est le même, et montre l'écran qu'on ouvre dans le métro.
 */
export function IosAlso() {
  return (
    <section className="relative flex min-h-[268px] overflow-hidden rounded-group bg-ink p-6 text-on-ink sm:min-h-[320px] sm:p-8">
      <div className="flex min-w-0 flex-1 flex-col justify-between pr-3 sm:pr-10">
        <div>
          <p className="eyebrow text-on-ink-muted">📱 Sur iPhone</p>
          <h2 className="mt-3 max-w-[18ch] text-[26px] font-bold leading-[1.08] tracking-tight-title sm:text-[32px]">
            Disponible sur iOS aussi.
          </h2>
          <p className="mt-3 max-w-[36ch] text-[14.5px] leading-relaxed text-on-ink-muted sm:text-[15.5px]">
            Le même compte, les mêmes cours, le même plan d&apos;examen. Tu révises dans le
            métro comme à ton bureau.
          </p>
        </div>

        <ul className="mt-6 space-y-1.5 text-[13px] text-on-ink-muted sm:mt-8">
          <li>Tes fiches te suivent.</li>
          <li>Les cartes dues aussi.</li>
          <li>Le jour J, le plan est le même.</li>
        </ul>
      </div>

      <div aria-hidden className="phone-stage ios-also-stage">
        <div className="phone-shell">
          <div className="phone-notch" />
          <div className="phone-screen">
            <p className="flex items-center gap-1 text-[8px] font-bold tracking-tight text-ink">
              <BrandMark size={10} />
              Micabo
            </p>
            <div className="mt-2 flex items-baseline justify-between gap-2">
              <p className="text-[9px] font-semibold text-ink">Devoir de SVT</p>
              <p className="rounded-pill bg-negative-soft px-1 py-px text-[7px] font-bold text-negative">
                J-3
              </p>
            </div>
            <p className="mt-2 text-[18px] font-bold leading-none text-ink">6</p>
            <p className="mt-0.5 text-[7px] text-ink-tertiary">cartes dues</p>
            <div className="mt-2 h-1.5 overflow-hidden rounded-pill bg-surface-muted">
              <div className="h-full w-[78%] rounded-pill bg-accent" />
            </div>
            <p className="mt-1 text-[7px] text-ink-tertiary">Cours appris à 78%</p>
            <div className="mt-2 space-y-1">
              <div className="rounded-md bg-caution-soft px-1.5 py-1 text-[7px] font-medium text-caution">
                Condensation
              </div>
              <div className="h-5 rounded-md bg-surface-sunken" />
              <div className="h-5 rounded-md bg-surface-muted" />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
