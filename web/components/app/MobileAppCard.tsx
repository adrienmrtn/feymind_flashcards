/**
 * L'app dans la poche : un téléphone qui sort, et la promesse qu'il porte.
 */
export function MobileAppCard() {
  return (
    <section className="hover-tile relative min-h-[232px] overflow-hidden rounded-group bg-ink px-6 pb-6 pt-5 pr-28 text-on-ink sm:pr-32">
      <p className="eyebrow text-on-ink-muted">📱 Sur ton téléphone</p>
      <p className="mt-2 max-w-[22ch] text-[18px] font-semibold leading-snug">
        Micabo aussi disponible sur mobile
      </p>
      <p className="mt-2 max-w-[36ch] text-[13.5px] leading-relaxed text-on-ink-muted">
        L&apos;app iOS arrive. Tes cours, tes cartes et tes séries t&apos;y suivront.
      </p>

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
