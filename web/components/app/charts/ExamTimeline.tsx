"use client";

import Link from "next/link";

import { examCountdownLabel, examUrgency } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";

import { SrTable } from "./primitives";
import { useMeasuredWidth } from "./useMeasuredWidth";

/**
 * Les épreuves sur la période : une ligne par épreuve, une frise commune.
 *
 * L'ancienne frise posait un bâton par jour et un point par épreuve, sans nom : on y
 * cherchait quelle épreuve était quel point. Ici la question « laquelle, et quand » se lit
 * ligne par ligne, et la longueur de la barre est le temps qu'il reste. Les semaines sont
 * graduées sur l'axe du haut, une fois pour toutes les lignes.
 */
export interface TimelineExam {
  id: string;
  name: string;
  daysRemaining: number;
  /** 0 à 100, ce qui est su aujourd'hui sur le programme de l'épreuve. */
  readiness: number;
}

export function ExamTimeline({ exams, now }: { exams: TimelineExam[]; now?: Date }) {
  const { t, locale } = useI18n();
  const bcp = localeBcp47(locale as never);
  const { ref, width } = useMeasuredWidth<HTMLDivElement>(600);
  const today = now ?? new Date();
  const upcoming = [...exams]
    .filter((exam) => exam.daysRemaining >= 0)
    .sort((left, right) => left.daysRemaining - right.daysRemaining);
  if (upcoming.length === 0) return null;

  const last = upcoming[upcoming.length - 1]!.daysRemaining;
  const horizon = Math.max(14, Math.ceil((last + 3) / 7) * 7);
  const ticks: { offset: number; label: string }[] = [];
  const room = Math.max(2, Math.floor(width / 84));
  const step = [7, 14, 28, 56].find((candidate) => horizon / candidate <= room) ?? 56;
  for (let offset = 0; offset <= horizon; offset += step) {
    const date = new Date(today.getTime() + offset * 86_400_000);
    ticks.push({
      offset,
      label:
        offset === 0
          ? t("app.plan.strip.today")
          : date.toLocaleDateString(bcp, { day: "numeric", month: "short" }),
    });
  }
  const pct = (offset: number) => `${Math.min(100, (offset / horizon) * 100)}%`;

  return (
    <div>
      <div className="grid grid-cols-1 gap-x-4 sm:grid-cols-[minmax(160px,32%)_1fr]">
        <div className="hidden sm:block" />
        <div ref={ref} className="relative h-5 text-[10.5px] text-ink-tertiary">
          {ticks.map((tick, index) => (
            <span
              key={tick.offset}
              className={`numeral absolute top-0 whitespace-nowrap ${
                index === ticks.length - 1 ? "-translate-x-full" : index === 0 ? "" : "-translate-x-1/2"
              } ${tick.offset === 0 ? "font-medium text-ink" : ""}`}
              style={{ left: pct(tick.offset) }}
            >
              {tick.label}
            </span>
          ))}
        </div>

        {upcoming.map((exam) => {
          const urgency = examUrgency(exam.daysRemaining);
          const chip =
            urgency === "critical"
              ? "bg-negative-soft text-negative"
              : urgency === "soon"
                ? "bg-caution-soft text-caution"
                : "bg-surface-muted text-ink-secondary";
          return (
            <Link
              key={exam.id}
              href={`/app/plan/${exam.id}` as never}
              className="group contents"
            >
              <span className="flex min-w-0 items-center gap-2 border-t border-hairline pt-3 sm:py-3">
                <span className="min-w-0 flex-1 truncate text-[13.5px] font-medium text-ink group-hover:underline">
                  {exam.name}
                </span>
                <span className={`numeral shrink-0 rounded-full px-2 py-0.5 text-[11px] font-semibold ${chip}`}>
                  {examCountdownLabel(exam.daysRemaining)}
                </span>
              </span>
              <span className="relative flex items-center pb-3 pt-2 sm:border-t sm:border-hairline sm:py-3">
                <span className="absolute inset-y-0 left-0 w-px bg-stroke-strong" aria-hidden />
                {ticks.slice(1).map((tick) => (
                  <span
                    key={tick.offset}
                    aria-hidden
                    className="absolute inset-y-0 w-px bg-hairline"
                    style={{ left: pct(tick.offset) }}
                  />
                ))}
                <span
                  aria-hidden
                  className="relative h-2 rounded-full"
                  style={{ width: pct(exam.daysRemaining), backgroundColor: "var(--chart-work-soft)" }}
                >
                  <span
                    className="absolute inset-y-0 left-0 rounded-full"
                    style={{ width: `${exam.readiness}%`, backgroundColor: "var(--chart-work)" }}
                  />
                </span>
                <span
                  aria-hidden
                  className="absolute size-3 -translate-x-1/2 rounded-full ring-2 ring-surface"
                  style={{ left: pct(exam.daysRemaining), backgroundColor: "var(--chart-work)" }}
                />
              </span>
            </Link>
          );
        })}
      </div>
      <p className="mt-3 text-[12px] text-ink-tertiary">{t("app.chart.timeline.hint")}</p>
      <SrTable
        caption={t("app.chart.timeline.aria")}
        headers={[t("app.chart.table.exam"), t("app.chart.table.days"), t("app.chart.table.readiness")]}
        rows={upcoming.map((exam) => [exam.name, exam.daysRemaining, `${exam.readiness} %`])}
      />
    </div>
  );
}
