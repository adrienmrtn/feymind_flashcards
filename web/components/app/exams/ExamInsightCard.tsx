import Link from "next/link";
import type { Route } from "next";

import {
  examCountdownLabel,
  examUrgency,
  type ExamInsight,
} from "@micabo/core";

/**
 * La carte d'un examen : note visée, avancée, charge, courbes, points faibles.
 *
 * C'est la même lecture que sur la vitrine, mais avec les vraies cartes.
 */
export function ExamInsightCard({
  insight,
  href,
  onClick,
}: {
  insight: ExamInsight;
  href?: Route;
  onClick?: () => void;
}) {
  const inner = <InsightBody insight={insight} />;
  const label = `${insight.name}, ${examCountdownLabel(insight.daysRemaining)}`;

  if (href) {
    return (
      <Link
        href={href}
        aria-label={label}
        className="block rounded-2xl border border-border bg-card p-5 text-left shadow-xs/5"
      >
        {inner}
      </Link>
    );
  }

  if (onClick) {
    return (
      <button
        type="button"
        onClick={onClick}
        aria-label={label}
        className="w-full rounded-2xl border border-border bg-card p-5 text-left shadow-xs/5"
      >
        {inner}
      </button>
    );
  }

  return <article className="rounded-2xl border border-border bg-card p-5 shadow-xs/5">{inner}</article>;
}

function InsightBody({ insight }: { insight: ExamInsight }) {
  const urgency = examUrgency(insight.daysRemaining);
  const tone =
    urgency === "critical"
      ? "bg-negative-soft text-negative"
      : urgency === "soon"
        ? "bg-caution-soft text-caution"
        : urgency === "upcoming"
          ? "bg-info-soft text-info"
          : "bg-surface-muted text-ink-secondary";

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="truncate text-[17px] font-semibold leading-tight text-ink sm:text-[18px]">
            {insight.name}
          </p>
          <p className="mt-1 text-[13px] text-ink-tertiary">
            Note visée{" "}
            <span className="numeral font-bold text-ink">{insight.gradeLabel}</span>
          </p>
        </div>
        <span className={`shrink-0 rounded-pill px-2 py-0.5 text-[11.5px] font-bold tracking-caps ${tone}`}>
          {examCountdownLabel(insight.daysRemaining)}
        </span>
      </div>

      <p className="mt-4 text-[13px] font-medium text-ink">
        Cours appris à{" "}
        <span className="numeral font-bold text-accent">{insight.learnedPct}%</span>
      </p>
      <div className="mt-1.5 h-1.5 overflow-hidden rounded-pill bg-progress-track">
        <div
          className="h-full rounded-pill bg-progress"
          style={{ width: `${insight.learnedPct}%` }}
        />
      </div>

      <ExamReadinessChart chart={insight.chart} />

      <p className="mt-4 text-[10px] font-bold uppercase tracking-caps text-ink-tertiary">
        Tes points faibles
      </p>
      {insight.weak.length === 0 ? (
        <p className="mt-2 text-[13px] leading-relaxed text-ink-secondary">
          {insight.cardCount === 0
            ? "Relie un cours pour voir tes points faibles."
            : "Rien à signaler pour l'instant."}
        </p>
      ) : (
        <ul className="mt-2 divide-y divide-hairline">
          {insight.weak.map((card) => (
            <li key={card.id} className="flex items-center gap-2 py-2 first:pt-0 last:pb-0">
              <span className="shrink-0 rounded-pill bg-caution-soft px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-caps text-caution">
                {card.kindLabel}
              </span>
              <span className="min-w-0 flex-1 truncate text-[13px] font-medium text-ink">
                {card.prompt}
              </span>
              <span className="shrink-0 text-[11.5px] text-ink-tertiary">{card.note}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function ExamReadinessChart({ chart }: { chart: ExamInsight["chart"] }) {
  const width = 280;
  const height = 86;
  const pad = { top: 6, right: 4, bottom: 16, left: 4 };
  const innerW = width - pad.left - pad.right;
  const innerH = height - pad.top - pad.bottom;
  const gap = 2;
  const barW = (innerW - gap * Math.max(0, chart.reviews.length - 1)) / Math.max(1, chart.reviews.length);
  const peak = Math.max(1, ...chart.reviews);
  const xAt = (index: number) => pad.left + index * (barW + gap) + barW / 2;
  const yAt = (value: number) => pad.top + innerH * (1 - value / 100);

  const line = (values: readonly number[]) =>
    values
      .map((value, index) => `${index === 0 ? "M" : "L"}${xAt(index)} ${yAt(value)}`)
      .join(" ");

  const startOffset = chart.offsets[0] ?? -12;
  const pastLabel = startOffset < 0 ? `il y a ${-startOffset} j` : "début";

  return (
    <figure className="mt-4 min-h-0">
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="h-[88px] w-full"
        role="img"
        aria-label="Charge de révision et rétention jusqu'à l'examen."
      >
        {chart.todayIndex >= 0 ? (
          <line
            x1={xAt(chart.todayIndex)}
            y1={pad.top}
            x2={xAt(chart.todayIndex)}
            y2={pad.top + innerH}
            stroke="var(--color-stroke-strong)"
            strokeDasharray="2 3"
            strokeWidth="1"
          />
        ) : null}
        {chart.examIndex >= 0 ? (
          <line
            x1={xAt(chart.examIndex)}
            y1={pad.top}
            x2={xAt(chart.examIndex)}
            y2={pad.top + innerH}
            stroke="var(--color-negative)"
            strokeWidth="1.4"
          />
        ) : null}
        {chart.reviews.map((count, index) => (
          <rect
            key={chart.offsets[index] ?? index}
            x={pad.left + index * (barW + gap)}
            y={pad.top + innerH - (count / peak) * innerH * 0.72}
            width={barW}
            height={(count / peak) * innerH * 0.72}
            rx="1.4"
            fill={
              (chart.offsets[index] ?? 0) >= 0
                ? "var(--color-accent)"
                : "color-mix(in oklch, var(--color-accent) 38%, var(--color-surface-sunken))"
            }
            opacity={(chart.offsets[index] ?? 0) === (chart.offsets[chart.examIndex] ?? -1) && count === 0 ? 0 : 0.9}
          />
        ))}
        <path
          d={line(chart.without)}
          fill="none"
          stroke="var(--color-ink-tertiary)"
          strokeWidth="1.3"
          strokeDasharray="3 3"
          strokeLinecap="round"
        />
        <path
          d={line(chart.withMicabo)}
          fill="none"
          stroke="var(--color-accent)"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <circle
          cx={xAt(chart.examIndex)}
          cy={yAt(chart.withMicabo[chart.examIndex] ?? 0)}
          r="2.4"
          fill="var(--color-accent)"
        />
        <text
          x={xAt(0)}
          y={height - 1}
          textAnchor="start"
          fill="var(--color-ink-tertiary)"
          fontSize="8"
        >
          {pastLabel}
        </text>
        {chart.todayIndex > 0 ? (
          <text
            x={xAt(chart.todayIndex)}
            y={height - 1}
            textAnchor="middle"
            fill="var(--color-ink-secondary)"
            fontSize="8"
          >
            aujourd&apos;hui
          </text>
        ) : null}
        <text
          x={xAt(chart.examIndex)}
          y={height - 1}
          textAnchor="end"
          fill="var(--color-negative)"
          fontSize="8"
          fontWeight="700"
        >
          examen
        </text>
      </svg>
    </figure>
  );
}
