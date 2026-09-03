"use client";

import { useEffect, useState } from "react";

import { planExam, type ExamCard } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";

/**
 * Le plan d'un examen générique, calculé par `planExam`.
 *
 * Même argument que la vitrine : Micabo resserre les cartes vers le jour J.
 * Ici c'est plus court, pour tenir sous le bouton sans faire défiler la page.
 *
 * **Les barres poussent à l'ouverture**, de gauche à droite : c'est le
 * resserrement vers le jour J qu'on veut voir, et une barre déjà en place ne
 * le montre pas. Le bloc est centré dans la carte, verticalement comme
 * horizontalement.
 */

const CARD_COUNT = 28;
const DAYS_BEFORE = 14;

export function ExamPrepStory() {
  const { t } = useI18n();
  const now = new Date(2026, 4, 1, 9, 0);
  const cards: ExamCard[] = Array.from({ length: CARD_COUNT }, (_, index) => ({
    id: `c${String(index).padStart(2, "0")}`,
    state: index % 5 === 0 ? "new" : "review",
    intervalDays: index % 5 === 0 ? 0 : 2 + (index % 8) * 3,
    dueDate: new Date(now.getTime() + (index % 6) * 86_400_000),
  }));

  const plan = planExam(cards, new Date(2026, 4, 1 + DAYS_BEFORE), { now, intensity: "standard" });
  const load = plan.projection.load;
  const peak = Math.max(...load, 1);
  const grown = useGrown();

  return (
    <div className="flex h-full min-h-full items-center justify-center py-2">
    <div className="paper w-full max-w-[420px] rounded-group bg-surface p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-[15px] font-semibold text-ink">{t("demo.examTitle")}</p>
          <p className="mt-0.5 text-[12px] text-ink-tertiary">
            {t("demo.targetGrade")} <span className="numeral font-bold text-ink">16</span>
            <span>/20</span>
          </p>
        </div>
        <p className="text-[12px] text-ink-tertiary">
          {t("demo.examCountdown", { days: DAYS_BEFORE })}
        </p>
      </div>

      <div className="mt-5 flex h-[88px] items-end gap-[3px]" aria-hidden>
        {load.map((count, offset) => (
          <div key={offset} className="flex-1">
            <div
              className="origin-bottom rounded-t-[3px]"
              style={{
                height: `${Math.max(4, (count / peak) * 84)}px`,
                backgroundColor:
                  offset >= load.length - 3
                    ? "var(--color-accent)"
                    : "color-mix(in oklch, var(--color-accent) 42%, var(--color-surface-sunken))",
                transform: `scaleY(${grown ? 1 : 0.04})`,
                transition: `transform 620ms var(--ease-out-strong) ${offset * 45}ms`,
              }}
            />
          </div>
        ))}
        <div
          className="ml-1 w-[3px] self-stretch origin-bottom rounded-pill bg-negative"
          style={{
            transform: `scaleY(${grown ? 1 : 0})`,
            transition: `transform 520ms var(--ease-out-strong) ${load.length * 45}ms`,
          }}
        />
      </div>

      <div className="mt-1.5 flex items-baseline justify-between text-[11px] text-ink-tertiary">
        <span>{t("demo.axisToday")}</span>
        <span className="font-semibold text-negative">{t("demo.axisExamDay")}</span>
      </div>

      <p className="sr-only">{t("demo.examPrepHistogramAria", { days: load.length })}</p>
    </div>
    </div>
  );
}

/** Vrai à la première image qui suit le montage : c'est ce qui déclenche la pousse. */
function useGrown(): boolean {
  const [grown, setGrown] = useState(false);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setGrown(true);
      return;
    }
    const frame = window.requestAnimationFrame(() => setGrown(true));
    return () => window.cancelAnimationFrame(frame);
  }, []);

  return grown;
}
