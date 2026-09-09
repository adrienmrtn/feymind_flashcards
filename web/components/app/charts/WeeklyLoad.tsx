"use client";

import type { LoadBar } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";

import { Legend, SrTable, niceMax } from "./primitives";

/**
 * Ce que la période demande, semaine par semaine.
 *
 * Ce graphe comparait avant le travail prévu à un budget de minutes déclaré au réglage, et
 * peignait en rouge ce qui dépassait. Le budget n'existe plus : personne ne sait à l'avance
 * combien de minutes il donnera, et un dépassement contre un chiffre inventé n'apprend rien.
 * Il ne reste donc qu'une chose, mais elle est vraie : **voilà le temps que chaque semaine va
 * prendre.** La semaine la plus haute est la semaine à anticiper, et c'est tout ce qu'il faut
 * savoir pour décider quand s'y mettre.
 *
 * Le pas est la semaine et non le jour, parce qu'un jour ne se lit pas et ne se décide pas :
 * on déplace du travail d'un mardi à un mercredi sans y penser, on ne déplace pas une semaine.
 */
interface Week {
  start: Date;
  minutes: number;
  cards: number;
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
      weeks[index] = { start: bar.date, minutes: 0, cards: 0, examNames: [] };
    }
    const week = weeks[index]!;
    week.minutes += bar.minutes;
    week.cards += bar.cardCount;
    for (const id of bar.examIds) {
      const name = examNames.get(id);
      if (name) week.examNames.push(name);
    }
  }

  const shown = weeks.slice(0, 12);
  const max = niceMax(Math.max(...shown.map((week) => week.minutes)));
  const peak = shown.reduce(
    (best, week, index) => (week.minutes > (shown[best]?.minutes ?? 0) ? index : best),
    0,
  );
  const hasExam = shown.some((week) => week.examNames.length > 0);

  return (
    <div>
      <div className="flex items-stretch gap-2">
        <div className="numeral flex w-9 shrink-0 flex-col justify-between pb-6 text-right text-[10px] text-ink-tertiary">
          <span>{Math.round(max)}</span>
          <span>{Math.round(max / 2)}</span>
          <span>0</span>
        </div>
        <ul className="flex min-w-0 flex-1 items-end justify-around gap-1.5 sm:gap-3">
          {shown.map((week, index) => {
            const label =
              index === 0
                ? t("app.chart.load.thisWeek")
                : week.start.toLocaleDateString(bcp, { day: "numeric", month: "short" });
            const title = `${t("app.chart.load.week", {
              day: week.start.toLocaleDateString(bcp, { day: "numeric", month: "long" }),
            })} · ${t("app.chart.load.tooltip", { minutes: week.minutes, cards: week.cards })}`;
            return (
              <li
                key={index}
                className="flex min-w-0 max-w-[72px] flex-1 flex-col items-center"
                title={title}
              >
                <div className="relative flex h-[120px] w-full max-w-9 items-end justify-center">
                  <span
                    aria-hidden
                    className="w-full rounded-t-[4px]"
                    style={{
                      height: `${Math.max(week.minutes > 0 ? 3 : 0, (week.minutes / max) * 100)}%`,
                      backgroundColor:
                        index === peak && week.minutes > 0
                          ? "var(--chart-work)"
                          : "var(--chart-work-soft)",
                    }}
                  />
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
          { tone: "work", label: t("app.chart.load.peak") },
          { tone: "work", shape: "soft", label: t("app.chart.load.planned") },
          ...(hasExam ? [{ tone: "fragile" as const, label: t("app.chart.load.exam") }] : []),
        ]}
      />

      <SrTable
        caption={t("app.chart.load.aria")}
        headers={[
          t("app.chart.table.week"),
          t("app.chart.load.planned"),
          t("app.chart.table.cards"),
        ]}
        rows={shown.map((week) => [
          week.start.toLocaleDateString(bcp),
          week.minutes,
          week.cards,
        ])}
      />
    </div>
  );
}
