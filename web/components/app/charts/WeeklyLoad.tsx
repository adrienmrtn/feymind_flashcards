"use client";

import type { LoadBar } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";

import { Legend, SrTable, niceMax } from "./primitives";

/**
 * La charge, semaine par semaine, contre le temps disponible.
 *
 * Le plan calcule jour par jour, mais un jour ne se lit pas : on décide de son temps à la
 * semaine. Chaque colonne montre les minutes prévues (bleu) devant les minutes disponibles
 * (gris clair) ; ce qui déborde passe en rouge, parce que c'est précisément la semaine qu'il
 * faut voir venir.
 */
interface Week {
  start: Date;
  minutes: number;
  capacity: number;
  examNames: string[];
}

export function WeeklyLoad({ bars, examNames }: { bars: LoadBar[]; examNames: Map<string, string> }) {
  const { t, locale } = useI18n();
  const bcp = localeBcp47(locale as never);
  if (bars.length === 0) return null;

  const weeks: Week[] = [];
  for (const bar of bars) {
    const index = Math.floor(bar.offset / 7);
    if (!weeks[index]) {
      weeks[index] = { start: bar.date, minutes: 0, capacity: 0, examNames: [] };
    }
    const week = weeks[index]!;
    week.minutes += bar.minutes;
    week.capacity += bar.isClosed ? 0 : bar.capacityMinutes;
    for (const id of bar.examIds) {
      const name = examNames.get(id);
      if (name) week.examNames.push(name);
    }
  }
  const shown = weeks.slice(0, 12);
  const max = niceMax(Math.max(...shown.map((week) => Math.max(week.minutes, week.capacity))));
  const hasOver = shown.some((week) => week.minutes > week.capacity);

  return (
    <div>
      <div className="flex items-stretch gap-2">
        <div className="numeral flex w-8 shrink-0 flex-col justify-between pb-6 text-right text-[10px] text-ink-tertiary">
          <span>{Math.round(max)}</span>
          <span>{Math.round(max / 2)}</span>
          <span>0</span>
        </div>
        <ul className="flex min-w-0 flex-1 items-end justify-around gap-1.5 sm:gap-3">
          {shown.map((week, index) => {
            const over = Math.max(0, week.minutes - week.capacity);
            const planned = Math.min(week.minutes, week.capacity);
            const label =
              index === 0
                ? t("app.chart.load.thisWeek")
                : week.start.toLocaleDateString(bcp, { day: "numeric", month: "short" });
            const title = `${t("app.chart.load.week", { day: week.start.toLocaleDateString(bcp, { day: "numeric", month: "long" }) })} · ${t("app.chart.load.tooltip", { minutes: week.minutes, capacity: week.capacity })}`;
            return (
              <li key={index} className="flex min-w-0 max-w-[72px] flex-1 flex-col items-center" title={title}>
                <div className="relative flex h-[120px] w-full max-w-9 items-end justify-center rounded-t-[4px]">
                  <span
                    aria-hidden
                    className="absolute inset-x-0 bottom-0 rounded-t-[4px]"
                    style={{
                      height: `${(week.capacity / max) * 100}%`,
                      backgroundColor: "var(--color-surface-sunken)",
                    }}
                  />
                  <span
                    aria-hidden
                    className="absolute inset-x-[2px] bottom-0 rounded-t-[3px]"
                    style={{
                      height: `${(planned / max) * 100}%`,
                      backgroundColor: "var(--chart-work)",
                    }}
                  />
                  {over > 0 ? (
                    <span
                      aria-hidden
                      className="absolute inset-x-[2px] rounded-t-[3px]"
                      style={{
                        bottom: `calc(${(planned / max) * 100}% + 2px)`,
                        height: `${(over / max) * 100}%`,
                        backgroundColor: "var(--chart-over)",
                      }}
                    />
                  ) : null}
                </div>
                <span className="mt-1.5 h-1.5">
                  {week.examNames.length > 0 ? (
                    <span
                      aria-hidden
                      className="block size-1.5 rounded-full"
                      style={{ backgroundColor: "var(--chart-fragile)" }}
                    />
                  ) : null}
                </span>
                <span className="numeral mt-1 max-w-full truncate text-[10px] text-ink-tertiary">
                  {label}
                </span>
              </li>
            );
          })}
        </ul>
      </div>
      <Legend
        className="mt-3"
        items={[
          { tone: "work", label: t("app.chart.load.planned") },
          { tone: "untouched", label: t("app.chart.load.capacity") },
          ...(hasOver ? [{ tone: "over" as const, label: t("app.chart.load.over") }] : []),
          { tone: "fragile", label: t("app.chart.load.exam") },
        ]}
      />
      <SrTable
        caption={t("app.chart.load.aria")}
        headers={[t("app.chart.load.week", { day: "" }), t("app.chart.load.planned"), t("app.chart.load.capacity")]}
        rows={shown.map((week) => [week.start.toLocaleDateString(bcp), week.minutes, week.capacity])}
      />
    </div>
  );
}
