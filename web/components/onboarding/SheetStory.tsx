"use client";

import { SheetBlocks } from "@/components/sheet/SheetBlocks";
import { SHOWCASE_SHEETS } from "@/components/onboarding/onboarding-sheets";

/**
 * Trois fiches écrites par Micabo, posées les unes après les autres.
 *
 * Elles ne sont pas animées : ce sont des documents, et on les lit. Le seul
 * mouvement est leur arrivée, échelonnée, pour qu'on comprenne qu'il y en a
 * plusieurs et qu'on peut faire défiler.
 */
export function SheetStory() {
  return (
    <div className="mx-auto w-full max-w-[460px] space-y-4">
      {SHOWCASE_SHEETS.map((sheet, index) => (
        <article
          key={sheet.title}
          className="paper overflow-hidden rounded-group bg-surface p-4"
          style={{
            animation: `micabo-rise 420ms var(--ease-out-strong) ${index * 110}ms both`,
          }}
        >
          <header className="flex items-center gap-3">
            <span
              aria-hidden
              className="flex h-9 w-9 shrink-0 items-center justify-center rounded-tile text-[18px]"
              style={{ backgroundColor: `${sheet.tint}1f` }}
            >
              {sheet.emoji}
            </span>
            <div className="min-w-0">
              <p className="truncate text-[14.5px] font-semibold text-ink">{sheet.title}</p>
              <p className="mt-0.5 text-[11.5px] text-ink-tertiary">{sheet.subject}</p>
            </div>
          </header>

          <div className="mt-3.5 border-t border-hairline pt-3.5">
            <SheetBlocks blocks={sheet.blocks} tint={sheet.tint} />
          </div>
        </article>
      ))}
    </div>
  );
}
