import { Card, CardPanel } from "@/components/ui/card";

/**
 * L'app dans la poche : une ligne, pas une pub.
 */
export function MobileAppCard() {
  return (
    <Card>
      <CardPanel className="flex items-center justify-between gap-4 py-4">
        <div className="min-w-0">
          <p className="text-[15px] font-medium text-ink">Aussi sur iPhone</p>
          <p className="mt-0.5 text-[13px] text-ink-tertiary">Tes cours t&apos;y suivront.</p>
        </div>
        <span
          aria-hidden
          className="flex size-9 shrink-0 items-center justify-center rounded-[22%] bg-ink text-[15px] font-semibold text-on-ink"
        >
          m
        </span>
      </CardPanel>
    </Card>
  );
}
