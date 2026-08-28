/**
 * L'app dans la poche : un téléphone qui sort, et la promesse qu'il porte.
 *
 * La carte remplit sa colonne. Le téléphone grandit avec elle, il n'est plus
 * collé en bas à droite à une taille fixe.
 */
export function MobileAppCard() {
  return (
    <section className="relative flex h-full min-h-[232px] overflow-hidden rounded-group bg-ink p-5 text-on-ink">
      <div className="flex min-w-0 flex-1 flex-col justify-between pr-3 sm:pr-4">
        <div>
          <p className="eyebrow text-on-ink-muted">📱 Sur ton téléphone</p>
          <p className="mt-2 max-w-[22ch] text-[18px] font-semibold leading-snug">
            Micabo aussi disponible sur mobile
          </p>
          <p className="mt-2 max-w-[36ch] text-[13.5px] leading-relaxed text-on-ink-muted">
            L&apos;app iOS arrive. Tes cours, tes cartes et tes séries t&apos;y suivront.
          </p>
        </div>
      </div>

      <div aria-hidden className="phone-stage">
        <div className="phone-shell">
          <div className="phone-notch" />
          <div className="phone-screen">
            <p className="text-[8px] font-bold tracking-tight text-ink">Micabo</p>
            <p className="mt-2 text-[16px] font-bold leading-none text-ink">8</p>
            <p className="mt-0.5 text-[7px] text-ink-tertiary">cartes dues</p>
            <div className="mt-2 h-1.5 overflow-hidden rounded-pill bg-surface-muted">
              <div className="h-full w-2/3 rounded-pill bg-ink" />
            </div>
            <div className="mt-2 space-y-1">
              <div className="h-5 rounded-md bg-surface-sunken" />
              <div className="h-5 rounded-md bg-surface-muted" />
              <div className="h-5 rounded-md bg-surface-muted" />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
