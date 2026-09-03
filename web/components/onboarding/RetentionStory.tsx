"use client";

import { useEffect, useState } from "react";

import {
  HORIZON_DAYS,
  REVIEW_DAYS,
  curveWithMicabo,
  curveWithoutReview,
} from "@micabo/core";

import { BrandMark } from "@/components/BrandMark";
import { useI18n } from "@/lib/i18n/client";

/**
 * **Deux courbes qui se tracent.** Sans méthode, on oublie ; avec Micabo, non.
 *
 * C'est la seule page de pédagogie du parcours, et elle se lit en trois
 * secondes : les deux tracés partent confondus, et c'est l'endroit où ils
 * divergent qu'on regarde. Les courbes sont celles du noyau, les mêmes que
 * la vitrine — donc les mêmes intervalles que l'app applique vraiment.
 *
 * Le tracé se fait au `stroke-dashoffset` : une ligne qui apparaît d'un coup
 * ne montre pas une dégradation dans le temps.
 */

const WIDTH = 420;
const HEIGHT = 208;
const FLOOR = 168;
const CEILING = 26;
const DRAW_MS = 1_700;

export function RetentionStory() {
  const { t } = useI18n();
  const drawn = useDrawn();
  const without = curveWithoutReview();
  const withMicabo = curveWithMicabo();

  return (
    <div className="mx-auto flex h-full w-full max-w-[440px] flex-col items-center justify-center">
      <div className="paper w-full rounded-group bg-surface p-4">
        <div className="flex items-center justify-between gap-3">
          <p className="text-[14.5px] font-semibold text-ink">{t("onboarding.retentionChart")}</p>
          <span aria-hidden className="flex h-7 shrink-0 items-center gap-1.5">
            <BrandMark size={20} />
            <span className="text-[11px] font-bold tracking-tight text-ink">Micabo</span>
          </span>
        </div>

        <svg
          viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
          className="mt-3 h-auto w-full"
          role="img"
          aria-label={t("demo.retentionChartAria", {
            days: HORIZON_DAYS,
            intervals: REVIEW_DAYS.join(", "),
          })}
        >
          {REVIEW_DAYS.map((day) => (
            <line
              key={day}
              x1={x(day / HORIZON_DAYS)}
              y1={CEILING - 8}
              x2={x(day / HORIZON_DAYS)}
              y2={FLOOR}
              stroke="var(--color-stroke)"
              strokeWidth="1"
            />
          ))}

          <line
            x1="0"
            y1={FLOOR}
            x2={WIDTH}
            y2={FLOOR}
            stroke="var(--color-hairline-on-canvas)"
          />

          <Trace
            d={path(without)}
            drawn={drawn}
            stroke="var(--color-ink-tertiary)"
            width={2}
            dashed
          />
          <Trace d={path(withMicabo)} drawn={drawn} stroke="var(--color-accent)" width={2.5} />

          {REVIEW_DAYS.map((day, index) => (
            <circle
              key={day}
              cx={x(day / HORIZON_DAYS)}
              cy={CEILING - 8}
              r="3.5"
              fill="var(--color-accent-vivid)"
              style={{
                opacity: drawn ? 1 : 0,
                transition: `opacity 320ms var(--ease-out-strong) ${520 + index * 260}ms`,
              }}
            />
          ))}
        </svg>

        <div className="mt-3 space-y-1.5 border-t border-hairline pt-3 text-[12.5px]">
          <Legend color="var(--color-accent)" label={t("demo.legendWith")} />
          <Legend color="var(--color-ink-tertiary)" dashed label={t("demo.legendWithout")} />
        </div>
      </div>
    </div>
  );
}

/**
 * Une courbe qui se dessine.
 *
 * Le pointillé et le tracé progressif se disputent `stroke-dasharray` : la
 * courbe sans méthode se dessine donc en opacité, et garde son pointillé.
 */
function Trace({
  d,
  drawn,
  stroke,
  width,
  dashed = false,
}: {
  d: string;
  drawn: boolean;
  stroke: string;
  width: number;
  dashed?: boolean;
}) {
  if (dashed) {
    return (
      <path
        d={d}
        fill="none"
        stroke={stroke}
        strokeWidth={width}
        strokeDasharray="5 5"
        style={{
          opacity: drawn ? 1 : 0,
          transition: `opacity ${DRAW_MS}ms linear`,
        }}
      />
    );
  }

  return (
    <path
      d={d}
      fill="none"
      stroke={stroke}
      strokeWidth={width}
      strokeLinejoin="round"
      pathLength={1}
      strokeDasharray={1}
      style={{
        strokeDashoffset: drawn ? 0 : 1,
        transition: `stroke-dashoffset ${DRAW_MS}ms var(--ease-out-strong)`,
      }}
    />
  );
}

function Legend({ color, label, dashed }: { color: string; label: string; dashed?: boolean }) {
  return (
    <p className="flex items-start gap-2.5 text-ink-secondary">
      <span
        aria-hidden
        className="mt-[7px] h-0.5 w-6 shrink-0 rounded-pill"
        style={
          dashed
            ? {
                backgroundImage: `repeating-linear-gradient(to right, ${color} 0 4px, transparent 4px 8px)`,
              }
            : { backgroundColor: color }
        }
      />
      {label}
    </p>
  );
}

function x(ratio: number): number {
  return ratio * WIDTH;
}

function path(points: { x: number; y: number }[]): string {
  return points
    .map(
      (point, index) =>
        `${index === 0 ? "M" : "L"}${x(point.x).toFixed(2)} ${(
          FLOOR -
          point.y * (FLOOR - CEILING)
        ).toFixed(2)}`,
    )
    .join(" ");
}

function useDrawn(): boolean {
  const [drawn, setDrawn] = useState(false);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setDrawn(true);
      return;
    }
    const frame = window.requestAnimationFrame(() => setDrawn(true));
    return () => window.cancelAnimationFrame(frame);
  }, []);

  return drawn;
}
