"use client";

import { ChevronLeft, X } from "lucide-react";

import type { LessonTone } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";

/**
 * **L'en-tête d'une étape ouverte** : la croix pour sortir sans cocher, la barre fine qui dit
 * où on en est, et le compte « 2 / 5 ». Jumeau de `CircleTopBar`.
 */
export function CircleTopBar({
  progress,
  tone,
  label,
  onClose,
  onBack,
  segments,
}: {
  /** Entre 0 et 1 ; absent, la barre ne se dessine pas. */
  progress?: number | null;
  tone: LessonTone;
  label?: string | null;
  onClose: () => void;
  /** « Écran précédent » : seulement les notes, quand il y a une page avant. */
  onBack?: (() => void) | null;
  /** Les segments des notes : un par écran, `filled` pour ceux qu'on a passés. */
  segments?: { count: number; page: number } | null;
}) {
  const { t } = useI18n();
  const vivid = `var(--color-tone-${tone}-vivid)`;
  return (
    <div className="flex items-center gap-3 px-1 pb-2 pt-2" data-print="hide">
      <button
        type="button"
        onClick={onClose}
        aria-label={t("lesson.circle.close")}
        className="pressable flex size-10 shrink-0 items-center justify-center rounded-full text-ink-secondary hover:bg-surface-muted"
      >
        <X aria-hidden="true" className="size-5" strokeWidth={2.6} />
      </button>

      {segments ? (
        <div className="flex h-2 flex-1 items-center gap-1.5" role="progressbar" aria-valuemin={1} aria-valuemax={segments.count} aria-valuenow={segments.page + 1}>
          {Array.from({ length: Math.max(1, segments.count) }, (_, index) => (
            <span key={index} className="relative h-2 flex-1 overflow-hidden rounded-pill bg-track">
              <span className="notes-segment-fill absolute inset-y-0 start-0 rounded-pill" style={{ width: index <= segments.page ? "100%" : "0%", background: vivid }} />
            </span>
          ))}
        </div>
      ) : typeof progress === "number" ? (
        <div className="relative h-2.5 flex-1 overflow-hidden rounded-pill bg-track" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(progress * 100)}>
          <div className="absolute inset-y-0 start-0 rounded-pill transition-[width] duration-300 ease-out" style={{ width: `max(8px, ${Math.min(100, Math.max(0, progress * 100))}%)`, background: vivid }} />
        </div>
      ) : (
        <span className="flex-1" />
      )}

      {label ? <span className="numeral shrink-0 text-[15px] font-extrabold text-ink-secondary">{label}</span> : null}

      {onBack ? (
        <button
          type="button"
          onClick={onBack}
          aria-label={t("lesson.notes.back")}
          className="pressable flex size-9 shrink-0 items-center justify-center rounded-full text-ink-secondary hover:bg-surface-muted"
        >
          <ChevronLeft aria-hidden="true" className="size-5" strokeWidth={2.6} />
        </button>
      ) : null}
    </div>
  );
}
