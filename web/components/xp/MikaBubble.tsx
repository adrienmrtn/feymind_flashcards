import type { ReactNode } from "react";

import { Mika } from "@/components/mika/Mika";
import type { MikaMood } from "@/components/mika/moods";

/**
 * **Mika qui parle** : la mascotte à gauche, sa phrase dans une bulle dont la pointe va vers
 * elle. La bulle prend la couleur de la surface, et suit le thème jour ou nuit.
 */
export function MikaBubble({ mood = "wave", size = 64, children }: { mood?: MikaMood; size?: number; children: ReactNode }) {
  return (
    <div className="flex items-end gap-2.5">
      <Mika mood={mood} size={size} label="" className="shrink-0" />
      <div className="relative mb-2 min-w-0 flex-1 rounded-[18px] rounded-es-[6px] bg-surface px-3.5 py-2.5 text-[15px] font-semibold leading-snug text-ink shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">
        {children}
      </div>
    </div>
  );
}
