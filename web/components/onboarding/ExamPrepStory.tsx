"use client";

import { planExam, type ExamCard } from "@micabo/core";

import { useStoryProgress } from "@/lib/onboarding/use-story-progress";

/**
 * Le plan d'un examen générique, calculé par `planExam`.
 *
 * Même argument que la vitrine : Micabo resserre les cartes vers le jour J.
 * Ici c'est plus court, pour tenir sous le bouton sans faire défiler la page.
 */

const CARD_COUNT = 28;
const DAYS_BEFORE = 14;

const WEAK = [
  { kind: "QCM", prompt: "Où se forme la condensation ?" },
  { kind: "Trou", prompt: "Ruissellement ou infiltration" },
] as const;

export function ExamPrepStory() {
  const progress = useStoryProgress(1_200);
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

  return (
    <article className="paper mx-auto w-full max-w-[400px] rounded-group bg-surface px-5 py-5">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-[17px] font-semibold leading-tight text-ink">Devoir de SVT</p>
          <p className="mt-1 text-[13px] text-ink-tertiary">
            Note visée{" "}
            <span className="numeral text-[22px] font-bold text-ink">16</span>
            <span className="text-ink-tertiary">/20</span>
          </p>
        </div>
        <span className="rounded-pill bg-info-soft px-2 py-0.5 text-[11.5px] font-bold tracking-caps text-info">
          J−{DAYS_BEFORE}
        </span>
      </div>

      <p className="mt-4 text-[13px] font-medium text-ink">
        Cours appris à <span className="numeral font-bold text-accent">78%</span>
      </p>
      <div className="mt-1.5 h-1.5 overflow-hidden rounded-pill bg-progress-track">
        <div
          className="h-full rounded-pill bg-progress"
          style={{
            width: `${78 * progress}%`,
            transition: "width 700ms var(--ease-out-strong)",
          }}
        />
      </div>

      <div className="mt-5 flex h-[96px] items-end gap-[3px]" aria-hidden>
        {load.map((count, offset) => {
          const examDay = offset === load.length - 1;
          const near = offset >= load.length - 3;
          const height = examDay ? 4 : Math.max(6, (count / peak) * 88 * progress);
          return (
            <div key={offset} className="flex flex-1 flex-col justify-end">
              <div
                className="rounded-t-[3px]"
                style={{
                  height: `${height}px`,
                  backgroundColor: examDay
                    ? "var(--color-negative)"
                    : near
                      ? "var(--color-accent)"
                      : "color-mix(in oklch, var(--color-accent) 40%, var(--color-surface-sunken))",
                }}
              />
            </div>
          );
        })}
      </div>

      <div className="mt-1.5 flex items-baseline justify-between text-[11px] text-ink-tertiary">
        <span>aujourd&apos;hui</span>
        <span className="font-semibold text-negative">jour J</span>
      </div>

      <p className="mt-4 text-[10px] font-bold uppercase tracking-caps text-ink-tertiary">
        Tes points faibles
      </p>
      <ul className="mt-2 divide-y divide-hairline">
        {WEAK.map((card) => (
          <li key={card.prompt} className="flex items-center gap-2 py-2 first:pt-0 last:pb-0">
            <span className="shrink-0 rounded-pill bg-caution-soft px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-caps text-caution">
              {card.kind}
            </span>
            <span className="min-w-0 flex-1 truncate text-[13px] font-medium text-ink">
              {card.prompt}
            </span>
          </li>
        ))}
      </ul>

      <p className="sr-only">
        Histogramme de {load.length} jours : les flashcards se resserrent avant le devoir de SVT,
        note visée 16 sur 20.
      </p>
    </article>
  );
}
