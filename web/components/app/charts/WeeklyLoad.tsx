"use client";

import { useState } from "react";

import type { LoadBar, LoadMock, LoadShare } from "@micabo/core";

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
 * prendre.** La semaine la plus haute est la semaine à anticiper.
 *
 * Le pas est la semaine et non le jour, parce qu'un jour ne se lit pas et ne se décide pas :
 * on déplace du travail d'un mardi à un mercredi sans y penser, on ne déplace pas une semaine.
 *
 * **Deux choses ont changé sous la barre.** Les épreuves étaient signalées par une pastille
 * ronde de six pixels, exactement comme les examens blancs auraient dû l'être : deux
 * événements de nature opposée, un que l'on subit et un que l'on choisit, rendus par le même
 * point. Ils ont maintenant chacun leur forme - un fanion pour l'épreuve, un carré horodaté
 * pour le blanc - et surtout **le survol ouvre le détail** : ce que la semaine contient, pour
 * quelles épreuves, et quel blanc y est posé. Une hauteur sans contenu ne se décide pas.
 */
interface Week {
  index: number;
  start: Date;
  minutes: number;
  cards: number;
  examNames: string[];
  mocks: LoadMock[];
  byExam: LoadShare[];
}

export function WeeklyLoad({ bars, examNames }: { bars: LoadBar[]; examNames: Map<string, string> }) {
  const { t, locale } = useI18n();
  const bcp = localeBcp47(locale as never);
  const [open, setOpen] = useState<number | null>(null);
  if (bars.length === 0) return null;

  const weeks: Week[] = [];
  for (const bar of bars) {
    const index = Math.floor(bar.offset / 7);
    if (!weeks[index]) {
      weeks[index] = {
        index,
        start: bar.date,
        minutes: 0,
        cards: 0,
        examNames: [],
        mocks: [],
        byExam: [],
      };
    }
    const week = weeks[index]!;
    week.minutes += bar.minutes;
    week.cards += bar.cardCount;
    week.mocks.push(...bar.mocks);
    for (const id of bar.examIds) {
      const name = examNames.get(id);
      if (name) week.examNames.push(name);
    }
    for (const share of bar.byExam) {
      const existing = week.byExam.find((item) => item.examId === share.examId);
      if (existing) {
        existing.cardCount += share.cardCount;
        existing.minutes += share.minutes;
      } else {
        week.byExam.push({ ...share });
      }
    }
  }

  const shown = weeks.slice(0, 12);
  for (const week of shown) {
    week.byExam.sort((left, right) => right.cardCount - left.cardCount);
  }
  const max = niceMax(Math.max(...shown.map((week) => week.minutes)));
  const peak = shown.reduce(
    (best, week, index) => (week.minutes > (shown[best]?.minutes ?? 0) ? index : best),
    0,
  );
  const hasExam = shown.some((week) => week.examNames.length > 0);
  const hasMock = shown.some((week) => week.mocks.length > 0);

  return (
    <div>
      <div className="flex items-stretch gap-2">
        <div className="numeral flex w-9 shrink-0 flex-col justify-between pb-10 text-right text-[10px] text-ink-tertiary">
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
            return (
              <li
                key={index}
                className="relative flex min-w-0 max-w-[72px] flex-1 flex-col items-center"
                onMouseEnter={() => setOpen(index)}
                onMouseLeave={() => setOpen((current) => (current === index ? null : current))}
              >
                <button
                  type="button"
                  className="flex w-full flex-col items-center outline-none"
                  onFocus={() => setOpen(index)}
                  onBlur={() => setOpen((current) => (current === index ? null : current))}
                  onClick={() => setOpen((current) => (current === index ? null : index))}
                  aria-expanded={open === index}
                >
                  <span className="relative flex h-[120px] w-full max-w-9 items-end justify-center">
                    <span
                      aria-hidden
                      className="w-full rounded-t-[4px] transition-[background-color] duration-hover"
                      style={{
                        height: `${Math.max(week.minutes > 0 ? 3 : 0, (week.minutes / max) * 100)}%`,
                        backgroundColor:
                          open === index || (index === peak && week.minutes > 0)
                            ? "var(--chart-work)"
                            : "var(--chart-work-soft)",
                      }}
                    />
                  </span>

                  {/* Les repères de la semaine : un fanion pour l'épreuve, un carré pour le
                      blanc. Deux formes distinctes, parce que ce sont deux choses distinctes. */}
                  <span className="mt-1.5 flex h-4 items-center gap-1">
                    {week.mocks.length > 0 ? (
                      <span
                        aria-hidden
                        className="flex h-3.5 w-3.5 items-center justify-center rounded-[3px]"
                        style={{ backgroundColor: "var(--chart-work)" }}
                      >
                        <svg viewBox="0 0 12 12" className="h-2.5 w-2.5 text-on-ink">
                          <circle cx="6" cy="6" r="4.2" fill="none" stroke="currentColor" strokeWidth="1.4" />
                          <path d="M6 3.8V6l1.6 1" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
                        </svg>
                      </span>
                    ) : null}
                    {week.examNames.length > 0 ? (
                      <svg aria-hidden viewBox="0 0 12 14" className="h-3.5 w-3">
                        <path d="M2.4 1v12" stroke="var(--chart-fragile)" strokeWidth="1.4" strokeLinecap="round" />
                        <path d="M3.1 1.4h6.6L7.6 4l2.1 2.6H3.1z" fill="var(--chart-fragile)" />
                      </svg>
                    ) : null}
                  </span>

                  <span className="numeral mt-1 max-w-full truncate text-[10px] text-ink-tertiary">
                    {label}
                  </span>
                </button>

                {open === index ? (
                  <WeekDetail week={week} bcp={bcp} last={index >= shown.length - 2} />
                ) : null}
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
          ...(hasMock ? [{ tone: "work" as const, label: t("app.chart.load.mock") }] : []),
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

/**
 * Ce que contient la semaine survolée.
 *
 * Le graphe donnait une hauteur et rien d'autre : on voyait que la semaine du 12 était la
 * plus chargée sans pouvoir savoir de quoi. Le détail répond aux trois questions qu'on se
 * pose alors, et à aucune autre : combien de cartes, pour quelles épreuves, et est-ce qu'un
 * blanc tombe là.
 */
function WeekDetail({ week, bcp, last }: { week: Week; bcp: string; last: boolean }) {
  const { t } = useI18n();

  return (
    <div
      role="tooltip"
      /* Sous la barre, et non au-dessus : les barres n'ont pas la même hauteur, donc un
         panneau posé sur leur sommet sautait d'une semaine à l'autre et sortait de la carte
         sur les hautes. En dessous, il part toujours du même endroit. */
      className={`paper absolute top-full z-20 mt-2 w-[228px] rounded-[12px] bg-surface px-3.5 py-3 text-left ${
        last ? "right-0" : "left-1/2 -translate-x-1/2"
      }`}
    >
      <p className="text-[12px] font-semibold text-ink">
        {t("app.chart.load.week", {
          day: week.start.toLocaleDateString(bcp, { day: "numeric", month: "long" }),
        })}
      </p>
      <p className="numeral mt-0.5 text-[12px] text-ink-secondary">
        {t("app.chart.load.tooltip", { minutes: week.minutes, cards: week.cards })}
      </p>

      {week.byExam.length > 0 ? (
        <ul className="mt-2.5 space-y-1 border-t border-hairline pt-2.5">
          {week.byExam.map((share) => (
            <li key={share.examId} className="flex items-baseline justify-between gap-2">
              <span className="min-w-0 truncate text-[12px] text-ink">{share.examName}</span>
              <span className="numeral shrink-0 text-[11.5px] text-ink-tertiary">
                {t("app.chart.load.forExam", { cards: share.cardCount })}
              </span>
            </li>
          ))}
        </ul>
      ) : null}

      {week.mocks.length > 0 ? (
        <ul className="mt-2.5 space-y-1 border-t border-hairline pt-2.5">
          {week.mocks.map((mock, index) => (
            <li key={`${mock.examId}:${index}`} className="text-[11.5px] leading-snug text-accent">
              {t("app.chart.load.mockLine", {
                exam: mock.examName,
                questions: mock.questionCount,
                minutes: mock.minutes,
              })}
            </li>
          ))}
        </ul>
      ) : null}

      {week.examNames.length > 0 ? (
        <p className="mt-2.5 border-t border-hairline pt-2.5 text-[11.5px] leading-snug text-caution">
          {t("app.chart.load.examLine", { exam: [...new Set(week.examNames)].join(", ") })}
        </p>
      ) : null}
    </div>
  );
}
