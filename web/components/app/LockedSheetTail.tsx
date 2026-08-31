"use client";

import { entitlement, type SheetBlock } from "@micabo/core";

import { SheetBlocks } from "@/components/sheet/SheetBlocks";
import { requestPaywall } from "@/lib/paywall";

/**
 * La fin d'une fiche, pour qui n'est pas abonné.
 *
 * Les blocs restants sont composés, puis floutés : on voit qu'il y a une
 * suite, on peut la faire défiler, et on ne la lit pas. Même geste que
 * sur l'iPhone — voir ce qu'on y perd.
 */
export function LockedSheetTail({
  blocks,
  tint,
}: {
  blocks: readonly SheetBlock[];
  tint: string;
}) {
  const percent = entitlement.lockedSheetPercent();

  return (
    <div className="relative mt-8" data-print="hide">
      <button
        type="button"
        onClick={requestPaywall}
        className="relative z-10 mx-auto flex w-full max-w-[420px] flex-col items-center rounded-group bg-surface/92 px-6 py-7 text-center shadow-[0_18px_50px_-24px_rgba(25,23,20,0.45)] backdrop-blur-md"
      >
        <span
          aria-hidden
          className="flex h-12 w-12 items-center justify-center rounded-full bg-accent text-on-ink"
        >
          <svg viewBox="0 0 20 20" className="h-5 w-5" fill="currentColor">
            <path d="M10 1.5a3.5 3.5 0 0 0-3.5 3.5v2H6a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2v-6a2 2 0 0 0-2-2h-.5V5A3.5 3.5 0 0 0 10 1.5zm-2 3.5a2 2 0 1 1 4 0v2H8V5z" />
          </svg>
        </span>
        <p className="mt-3.5 text-[16.5px] font-bold text-ink">La suite de la fiche est dans Pro</p>
        <p className="mx-auto mt-1.5 max-w-[38ch] text-[13px] leading-relaxed text-ink-secondary">
          Il te reste {percent} % de ce cours à lire, et tous les suivants à importer.
        </p>
        <span className="mt-4 inline-flex items-center gap-1.5 rounded-full bg-accent px-5 py-3 text-[14.5px] font-semibold text-on-ink">
          Débloquer la fiche
          <svg aria-hidden viewBox="0 0 20 20" className="h-3 w-3" fill="none" stroke="currentColor" strokeWidth="2.2">
            <path d="M7 4l6 6-6 6" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </span>
      </button>

      <button
        type="button"
        onClick={requestPaywall}
        tabIndex={-1}
        aria-hidden
        className="mt-6 block w-full cursor-pointer select-none text-left blur-[6.5px] [user-select:none]"
      >
        <SheetBlocks blocks={[...blocks]} tint={tint} />
      </button>
    </div>
  );
}
