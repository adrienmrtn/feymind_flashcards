"use client";

import type { DailyReview } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";

import { SrTable, niceMax } from "./primitives";
import { useMeasuredWidth } from "./useMeasuredWidth";

/**
 * L'activité : un trait par jour, sur les six dernières semaines.
 *
 * Une seule série, une seule couleur, et un axe qui dit combien : le graphe d'avant n'avait
 * ni repère ni date, on y voyait des barres monter sans savoir jusqu'où. Aujourd'hui est
 * marqué, les lundis portent leur date, et le survol donne le détail du jour.
 */
const WEEKS = 6;
const H = 96;
const PAD_TOP = 8;
const PAD_BOTTOM = 22;
const PAD_LEFT = 26;

export function ActivityChart({ daily, now }: { daily: DailyReview[]; now?: Date }) {
  const { t, locale } = useI18n();
  const bcp = localeBcp47(locale as never);
  const today = startOfDay(now ?? new Date());
  const days: { date: Date; passes: number; again: number }[] = [];
  const byKey = new Map(daily.map((point) => [dayKey(point.day), point]));
  for (let offset = WEEKS * 7 - 1; offset >= 0; offset -= 1) {
    const date = new Date(today.getTime() - offset * 86_400_000);
    const point = byKey.get(dayKey(date));
    days.push({ date, passes: point?.passes ?? 0, again: point?.againCount ?? 0 });
  }

  const max = niceMax(Math.max(...days.map((day) => day.passes)));
  const { ref, width } = useMeasuredWidth<HTMLDivElement>(600);
  const todayIndex = days.length - 1;
  const plotWidth = width - PAD_LEFT;
  const slot = plotWidth / days.length;
  const bar = Math.min(10, slot * 0.62);
  const plotHeight = H - PAD_TOP - PAD_BOTTOM;
  const y = (value: number) => PAD_TOP + plotHeight - (value / max) * plotHeight;
  const ticks = [0, max / 2, max];

  return (
    <div ref={ref}>
      <svg
        viewBox={`0 0 ${width} ${H}`}
        width={width}
        height={H}
        className="block h-auto max-w-full"
        role="img"
        aria-label={t("app.home.stats.chartAria")}
      >
        {ticks.map((tick) => (
          <g key={tick}>
            <line
              x1={PAD_LEFT}
              x2={width}
              y1={y(tick)}
              y2={y(tick)}
              stroke="var(--chart-grid)"
              strokeWidth="1"
            />
            <text
              x={PAD_LEFT - 6}
              y={y(tick) + 3.5}
              textAnchor="end"
              fontSize="10"
              fill="var(--chart-axis)"
              className="numeral"
            >
              {Math.round(tick)}
            </text>
          </g>
        ))}
        {days.map((day, index) => {
          const isToday = index === days.length - 1;
          const x = PAD_LEFT + index * slot + (slot - bar) / 2;
          const labelX = PAD_LEFT + index * slot + slot / 2;
          const top = day.passes > 0 ? y(day.passes) : y(0) - 2;
          const height = y(0) - top;
          const isMonday = day.date.getDay() === 1 && todayIndex - index > 3;
          const title = `${day.date.toLocaleDateString(bcp, { weekday: "long", day: "numeric", month: "long" })} · ${t("app.home.stats.chartDay", { passes: day.passes, again: day.again })}`;
          return (
            <g key={dayKey(day.date)}>
              <rect
                x={PAD_LEFT + index * slot}
                y={PAD_TOP}
                width={slot}
                height={plotHeight}
                fill="transparent"
                className="hover:fill-[var(--color-surface-muted)]"
              >
                <title>{title}</title>
              </rect>
              <rect
                x={x}
                y={top}
                width={bar}
                height={Math.max(2, height)}
                rx={Math.min(3, bar / 2)}
                fill={day.passes > 0 ? "var(--chart-work)" : "var(--chart-untouched)"}
                opacity={isToday || day.passes === 0 ? 1 : 0.78}
                pointerEvents="none"
              />
              {isMonday ? (
                <text
                  x={PAD_LEFT + index * slot + slot / 2}
                  y={H - 6}
                  textAnchor="middle"
                  fontSize="10"
                  fill="var(--chart-axis)"
                  className="numeral"
                >
                  {day.date.toLocaleDateString(bcp, { day: "numeric", month: "short" })}
                </text>
              ) : null}
              {isToday ? (
                <text
                  x={Math.min(labelX, width - 4)}
                  y={H - 6}
                  textAnchor="end"
                  fontSize="10"
                  fontWeight="600"
                  fill="var(--color-ink)"
                >
                  {t("app.plan.strip.today")}
                </text>
              ) : null}
            </g>
          );
        })}
      </svg>
      <SrTable
        caption={t("app.home.stats.chartAria")}
        headers={[t("app.chart.table.day"), t("app.chart.table.passes"), t("app.chart.table.again")]}
        rows={days
          .filter((day) => day.passes > 0)
          .map((day) => [day.date.toLocaleDateString(bcp), day.passes, day.again])}
      />
    </div>
  );
}

function dayKey(date: Date): string {
  return `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
}

function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12);
}
