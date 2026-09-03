"use client";

import {
  HORIZON_DAYS,
  REVIEW_DAYS,
  curveWithMicabo,
  curveWithoutReview,
} from "@micabo/core";

import { Card, CardPanel } from "@/components/ui/card";
import { useI18n } from "@/lib/i18n/client";

/**
 * La courbe de l'oubli, prise à contre-pied.
 *
 * **C'est la seule section de pédagogie du site**, et c'est déjà la règle de l'app : l'écran qui
 * reprenait ensuite les mêmes intervalles en liste disait une deuxième fois ce que le graphe
 * montre. Elle doit se lire en trois secondes - un titre qui annonce ce qu'on regarde, les
 * intervalles réels étiquetés, et deux lignes de légende. Aucun paragraphe.
 *
 * Les deux tracés **partent confondus** et se séparent à la première révision : c'est l'endroit
 * où ils divergent qu'on regarde, pas la forme de chacun.
 */

const WIDTH = 640;
const HEIGHT = 240;
const FLOOR = 200;
const CEILING = 24;

export function RetentionChart() {
  const { t } = useI18n();
  const without = curveWithoutReview();
  const withMicabo = curveWithMicabo();

  return (
    <Card render={<figure />} className="lift" data-print="keep">
    <CardPanel className="p-6 sm:p-8">
      <svg
        viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
        className="h-auto w-full"
        role="img"
        aria-label={t("demo.retentionChartAria", {
          days: HORIZON_DAYS,
          intervals: REVIEW_DAYS.join(", "),
        })}
      >
        {/* Les repères de révision, posés avant les courbes pour passer dessous. */}
        {REVIEW_DAYS.map((day) => (
          <line
            key={day}
            x1={x(day / HORIZON_DAYS)}
            y1={CEILING - 6}
            x2={x(day / HORIZON_DAYS)}
            y2={FLOOR}
            stroke="var(--color-stroke)"
            strokeWidth="1"
          />
        ))}

        <line x1="0" y1={FLOOR} x2={WIDTH} y2={FLOOR} stroke="var(--color-hairline-on-canvas)" />

        <path
          d={path(without)}
          fill="none"
          stroke="var(--color-ink-tertiary)"
          strokeWidth="2"
          strokeDasharray="5 5"
        />
        <path
          d={path(withMicabo)}
          fill="none"
          stroke="var(--color-accent)"
          strokeWidth="2.5"
          strokeLinejoin="round"
        />

        {REVIEW_DAYS.map((day) => (
          <g key={day}>
            <circle
              cx={x(day / HORIZON_DAYS)}
              cy={CEILING - 6}
              r="3.5"
              fill="var(--color-accent-vivid)"
            />
            <text
              x={x(day / HORIZON_DAYS)}
              y={CEILING - 14}
              textAnchor="middle"
              className="fill-ink-tertiary text-[11px]"
            >
              {t("demo.dayShort", { n: day })}
            </text>
          </g>
        ))}
      </svg>

      <figcaption className="mt-6 space-y-2 text-[13.5px]">
        <Legend color="var(--color-accent)" label={t("demo.legendWith")} />
        <Legend color="var(--color-ink-tertiary)" dashed label={t("demo.legendWithout")} />
      </figcaption>
    </CardPanel>
    </Card>
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

function Legend({ color, label, dashed }: { color: string; label: string; dashed?: boolean }) {
  return (
    <p className="flex items-start gap-3 text-ink-secondary">
      <span
        aria-hidden
        className="mt-2 h-0.5 w-7 shrink-0 rounded-pill"
        style={
          dashed
            ? {
                backgroundImage: `repeating-linear-gradient(to right, ${color} 0 5px, transparent 5px 10px)`,
              }
            : { backgroundColor: color }
        }
      />
      {label}
    </p>
  );
}
