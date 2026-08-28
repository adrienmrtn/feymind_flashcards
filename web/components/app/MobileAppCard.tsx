import { Card, CardHeader, CardPanel, CardTitle } from "@/components/ui/card";

/**
 * L'app dans la poche : une carte CRM, pas une pub noire.
 */
export function MobileAppCard() {
  return (
    <Card className="h-full">
      <CardHeader className="pb-2">
        <CardTitle className="text-[15px] font-semibold text-ink">Sur le téléphone</CardTitle>
      </CardHeader>
      <CardPanel className="flex min-h-[180px] items-end justify-between gap-4 pt-0">
        <div className="min-w-0 flex-1 pb-1">
          <p className="max-w-[22ch] text-[15px] font-medium leading-snug text-ink">
            Micabo aussi disponible sur mobile
          </p>
          <p className="mt-2 max-w-[36ch] text-[13.5px] leading-relaxed text-ink-secondary">
            L&apos;app iOS arrive. Tes cours, tes cartes et tes séries t&apos;y suivront.
          </p>
        </div>

        <div aria-hidden className="phone-stage shrink-0">
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
      </CardPanel>
    </Card>
  );
}
