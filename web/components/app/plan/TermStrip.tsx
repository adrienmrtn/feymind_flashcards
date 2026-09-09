"use client";

import { useMemo } from "react";

import type { LoadBar } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";

/**
 * La frise de la période : **tout ce qui reste, en un regard.**
 *
 * Un cran par jour, du jour même à la dernière épreuve. La hauteur dit la charge, le creux dit
 * un jour indisponible, le drapeau dit une épreuve. C'est la seule vue du produit où l'on voit
 * qu'une semaine est un mur avant de s'y cogner - un calendrier mensuel ne le montre pas,
 * puisqu'il donne à toutes les cases la même taille.
 *
 * La barre est **relative à la capacité du jour**, pas à un maximum global : quarante minutes
 * sur un jour à quarante minutes est un jour plein, et doit se lire comme tel même si le
 * samedi voisin en accepte cent vingt. Un jour en dépassement se teinte, parce que c'est
 * exactement ce que l'étudiant doit voir avant de le vivre.
 */

export interface StripExam {
  id: string;
  name: string;
  offset: number;
}

export function TermStrip({
  bars,
  exams,
  onPickDay,
  selected,
}: {
  bars: LoadBar[];
  exams: StripExam[];
  onPickDay?: (offset: number) => void;
  selected?: number | null;
}) {
  const { t, locale } = useI18n();
  const names = useMemo(
    () => new Map(exams.map((exam) => [exam.id, exam.name])),
    [exams],
  );

  if (bars.length === 0) return null;

  const monthMarks = monthBoundaries(bars, locale);

  return (
    <div className="min-w-0">
      <div className="flex items-end gap-px overflow-x-auto pb-1" role="list">
        {bars.map((bar) => {
          const isToday = bar.offset === 0;
          const isSelected = selected != null && selected === bar.offset;
          const label = dayLabel(bar.date, locale);
          const title = bar.isClosed
            ? t("app.plan.strip.closed", { day: label })
            : t("app.plan.strip.day", {
                day: label,
                minutes: bar.minutes,
                capacity: bar.capacityMinutes,
              });

          return (
            <button
              key={bar.offset}
              type="button"
              role="listitem"
              title={title}
              aria-label={title}
              onClick={onPickDay ? () => onPickDay(bar.offset) : undefined}
              disabled={!onPickDay}
              className={`group relative flex h-24 min-w-[7px] flex-1 shrink-0 flex-col justify-end rounded-[3px] ${
                onPickDay ? "cursor-pointer" : "cursor-default"
              } ${isSelected ? "bg-surface-muted" : "hover:bg-surface-muted/70"}`}
            >
              {bar.examIds.length > 0 ? (
                <span
                  aria-hidden
                  className="absolute inset-x-0 top-0 mx-auto h-2 w-2 rounded-full bg-caution"
                />
              ) : null}

              <span
                aria-hidden
                className={`w-full rounded-t-[2px] transition-all duration-menu ${
                  bar.isClosed
                    ? "bg-stroke-strong/40"
                    : bar.isOver
                      ? "bg-negative"
                      : bar.minutes === 0
                        ? "bg-stroke"
                        : "bg-accent"
                }`}
                style={{
                  height: bar.isClosed
                    ? "3px"
                    : `${Math.max(3, Math.round(bar.fill * 72))}px`,
                }}
              />
              <span
                aria-hidden
                className={`mt-1 h-[3px] w-full rounded-full ${
                  isToday ? "bg-ink" : "bg-transparent"
                }`}
              />
            </button>
          );
        })}
      </div>

      <div className="mt-1.5 flex items-center justify-between text-[11.5px] text-ink-tertiary">
        <span>{t("app.plan.strip.today")}</span>
        <span className="flex items-center gap-3">
          {monthMarks.map((mark) => (
            <span key={mark}>{mark}</span>
          ))}
        </span>
        <span>
          {t("app.plan.strip.lastDay", {
            day: dayLabel(bars[bars.length - 1]!.date, locale),
          })}
        </span>
      </div>

      {exams.length > 0 ? (
        <ul className="mt-3 flex flex-wrap gap-x-4 gap-y-1.5 text-[12px] text-ink-secondary">
          {exams.map((exam) => (
            <li key={exam.id} className="flex items-center gap-1.5">
              <span aria-hidden className="h-1.5 w-1.5 rounded-full bg-caution" />
              <span className="truncate">{names.get(exam.id) ?? exam.name}</span>
              <span className="numeral text-ink-tertiary">
                {t("app.plan.strip.inDays", { count: Math.max(0, exam.offset) })}
              </span>
            </li>
          ))}
        </ul>
      ) : null}

      <span className="sr-only">
        {t("app.plan.strip.summary", {
          days: bars.length,
          closed: bars.filter((bar) => bar.isClosed).length,
        })}
      </span>
    </div>
  );
}

/** Les mois traversés par la frise, pour se repérer sans étiqueter chaque cran. */
function monthBoundaries(bars: LoadBar[], locale: string): string[] {
  const seen = new Set<number>();
  const marks: string[] = [];
  for (const bar of bars) {
    const month = bar.date.getMonth();
    if (seen.has(month)) continue;
    seen.add(month);
    marks.push(bar.date.toLocaleDateString(localeBcp47(locale as never), { month: "short" }));
  }
  return marks.slice(0, 4);
}

function dayLabel(date: Date, locale: string): string {
  return date.toLocaleDateString(localeBcp47(locale as never), {
    weekday: "short",
    day: "numeric",
    month: "short",
  });
}
